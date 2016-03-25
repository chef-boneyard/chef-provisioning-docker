require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/docker_driver/version'
require 'chef/provisioning/docker_driver/docker_transport'
require 'chef/provisioning/docker_driver/docker_container_machine'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/mash'

require 'yaml'
require 'docker/container'
require 'docker'

class Chef
module Provisioning
module DockerDriver
  # Provisions machines using Docker
  class Driver < Chef::Provisioning::Driver

    include Chef::Mixin::ShellOut

    attr_reader :connection

    # URL scheme:
    # docker:<path>
    # canonical URL calls realpath on <path>
    def self.from_url(driver_url, config)
      Driver.new(driver_url, config)
    end

    def driver_url
      "docker:#{Docker.url}"
    end

    def initialize(driver_url, config)
      super
      url = Driver.connection_url(driver_url)

      if url
        # Export this as it's expected
        # to be set for command-line utilities
        ENV['DOCKER_HOST'] = url
        Chef::Log.debug("Setting Docker URL to #{url}")
      end

      ENV['DOCKER_HOST'] ||= url if url
      Docker.logger = Chef::Log
      options = Docker.options.dup || {}
      options.merge!(read_timeout: 600)
      options.merge!(config[:docker_connection].hash_dup) if config && config[:docker_connection]
      @connection = Docker::Connection.new(url || Docker.url, options)
    end

    def self.canonicalize_url(driver_url, config)
      url = Driver.connection_url(driver_url)
      [ "docker:#{url}", config ]
    end

    # Parse the url from a  URL, try to clean it up
    # Returns a proper URL from the driver_url string. Examples include:
    #   docker:/var/run/docker.sock => unix:///var/run/docker.sock
    #   docker:192.168.0.1:1234 => tcp://192.168.0.1:1234
    def self.connection_url(driver_url)
      scheme, url = driver_url.split(':', 2)

      if url && url.size > 0
        # Clean up the URL with the protocol if needed (within reason)
        case url
        when /^\d+\.\d+\.\d+\.\d+:\d+$/
          "tcp://#{url}"
        when /^\//
          "unix://#{url}"
        when /^(tcp|unix)/
          url
        else
          "tcp://#{url}"
        end
      end
    end

    def allocate_machine(action_handler, machine_spec, machine_options)
      machine_spec.from_image = from_image_from_action_handler(
        action_handler,
        machine_spec
      )

      # Grab options from existing machine (TODO seems wrong) and set the machine_spec to that
      docker_options = machine_options[:docker_options]
      container_id = nil
      image_id = machine_options[:image_id]
      if machine_spec.reference
        container_name = machine_spec.reference['container_name']
        container_id = machine_spec.reference['container_id']
        image_id ||= machine_spec.reference['image_id']
        docker_options ||= machine_spec.reference['docker_options']
      end
      container_name ||= machine_spec.name
      machine_spec.reference = {
        'driver_url' => driver_url,
        'driver_version' => Chef::Provisioning::DockerDriver::VERSION,
        'allocated_at' => Time.now.utc.to_s,
        'host_node' => action_handler.host_node,
        'container_name' => container_name,
        'image_id' => image_id,
        'docker_options' => stringize_keys(docker_options),
        'container_id' => container_id
      }
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    def start_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      if container && !container.info['State']['Running']
        action_handler.perform_action "start container #{machine_spec.name}" do
          container.start!
        end
      end
    end

    # Connect to machine without acquiring it
    def connect_to_machine(machine_spec, machine_options)
      Chef::Log.debug('Connect to machine')
      machine_for(machine_spec, machine_options)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      if container
        image_id = container.info['Image']
        action_handler.perform_action "stop and destroy container #{machine_spec.name}" do
          container.stop
          container.delete
        end
      end
    end

    def stop_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      if container.info['State']['Running']
        action_handler.perform_action "stop container #{machine_spec.name}" do
          container.stop!
        end
      end
    end

    #
    # Images
    #

    def allocate_image(action_handler, image_spec, image_options, machine_spec, machine_options)
      tag_container_image(action_handler, machine_spec, image_spec)

      # Set machine options on the image to match our newly created image
      image_spec.reference = {
        'driver_url' => driver_url,
        'driver_version' => Chef::Provisioning::DockerDriver::VERSION,
        'allocated_at' => Time.now.to_i,
        'docker_options' => {
          'base_image' => {
            'name' => image_spec.name
          }
        }
      }

      # Workaround for chef/chef-provisioning-docker#37
      machine_spec.attrs[:keep_image] = true
    end

    def ready_image(action_handler, image_spec, image_options)
      Chef::Log.debug('READY IMAGE!')
    end

    # workaround for https://github.com/chef/chef-provisioning/issues/358.
    def destroy_image(action_handler, image_spec, image_options, machine_options={})
      image = image_for(image_spec)
      image.delete unless image.nil?
    end

    private

    def tag_container_image(action_handler, machine_spec, image_spec)
      container = container_for(machine_spec)
      existing_image = image_for(image_spec)
      unless existing_image && existing_image.id == container.info['Image']
        image = Docker::Image.get(container.info['Image'], {}, @connection)
        action_handler.perform_action "tag image #{container.info['Image']} as chef-images/#{image_spec.name}" do
          image.tag('repo' => image_spec.name, 'force' => true)
        end
      end
    end

    def to_camel_case(name)
      name.split('_').map { |x| x.capitalize }.join("")
    end

    def to_snake_case(name)
      # ExposedPorts -> _exposed_ports
      name = name.gsub(/[A-Z]/) { |x| "_#{x.downcase}" }
      # _exposed_ports -> exposed_ports
      name = name[1..-1] if name.start_with?('_')
      name
    end

    def from_image_from_action_handler(action_handler, machine_spec)
      case action_handler
      when Chef::Provisioning::AddPrefixActionHandler
        machines = action_handler.action_handler.provider.new_resource.machines
        this_machine = machines.select { |m| m.name == machine_spec.name}.first
        this_machine.from_image
      else
        action_handler.provider.new_resource.from_image
      end
    end

    def machine_for(machine_spec, machine_options)
      Chef::Log.debug('machine_for...')
      docker_options = machine_options[:docker_options] || Mash.from_hash(machine_spec.reference['docker_options'] || {})

      container = container_for(machine_spec)

      if machine_spec.from_image
        convergence_strategy = Chef::Provisioning::ConvergenceStrategy::NoConverge.new({}, config)
      else
        convergence_strategy = Chef::Provisioning::ConvergenceStrategy::InstallCached.
          new(machine_options[:convergence_options], config)
      end

      transport = DockerTransport.new(container, config)

      Chef::Provisioning::DockerDriver::DockerContainerMachine.new(
        machine_spec,
        transport,
        convergence_strategy,
        @connection,
        docker_options[:command]
      )
    end

    def container_for(machine_spec)
      begin
        Docker::Container.get(machine_spec.name, {}, @connection)
      rescue Docker::Error::NotFoundError
      end
    end

    def image_for(image_spec)
      begin
        Docker::Image.get(image_spec.name, {}, @connection)
      rescue Docker::Error::NotFoundError
      end
    end

    def stringize_keys(hash)
      if hash
        hash.each_with_object({}) do |(k,v),hash|
          v = stringize_keys(v) if v.is_a?(Hash)
          hash[k.to_s] = v
        end
      end
    end
  end
end
end
end
