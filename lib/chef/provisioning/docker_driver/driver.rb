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

    def initialize(driver_url, config)
      super
      url = Driver.connection_url(driver_url)

      if url
        # Export this as it's expected
        # to be set for command-line utilities
        ENV['DOCKER_HOST'] = url
        Chef::Log.debug("Setting Docker URL to #{url}")
        Docker.url = url
      end

      @connection = Docker.connection
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
        'docker_options' => docker_options,
        'container_id' => container_id
      }
      build_container(machine_spec, docker_options)
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      start_machine(action_handler, machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    def build_container(machine_spec, docker_options)
      container = container_for(machine_spec)
      return container unless container.nil?

      image = find_image(machine_spec) ||
        build_image(machine_spec, docker_options)

      args = [
        'docker',
        'run',
        '--name',
        machine_spec.reference['container_name'],
        '--detach'
      ]

      if docker_options[:keep_stdin_open]
        args << '-i'
      end

      if docker_options[:env]      
        docker_options[:env].each do |key, value|
          args << '-e'
          args << "#{key}=#{value}"
        end
      end

      if docker_options[:ports]
        docker_options[:ports].each do |portnum|
          args << '-p'
          args << "#{portnum}"
        end
      end

      if docker_options[:volumes]
        docker_options[:volumes].each do |volume|
          args << '-v'
          args << "#{volume}"
        end
      end

      args << image.id
      args += Shellwords.split("/bin/sh -c 'while true;do sleep 1; done'")

      cmdstr = Shellwords.join(args)
      Chef::Log.debug("Executing #{cmdstr}")

      cmd = Mixlib::ShellOut.new(cmdstr)
      cmd.run_command

      container = Docker::Container.get(machine_spec.reference['container_name'])

      Chef::Log.debug("Container id: #{container.id}")
      machine_spec.reference['container_id'] = container.id
      container
    end

    def build_image(machine_spec, docker_options)
      base_image = docker_options[:base_image] || base_image_for(machine_spec)
      source_name = base_image[:name]
      source_repository = base_image[:repository]
      source_tag = base_image[:tag]

      target_tag = machine_spec.reference['container_name']

      image = Docker::Image.create(
        'fromImage' => source_name,
        'repo' => source_repository,
        'tag' => source_tag
      )
      
      Chef::Log.debug("Allocated #{image}")
      image.tag('repo' => 'chef', 'tag' => target_tag)
      Chef::Log.debug("Tagged image #{image}")

      machine_spec.reference['image_id'] = image.id
      image
    end

    def allocate_image(action_handler, image_spec, image_options, machine_spec, machine_options)
      # Set machine options on the image to match our newly created image
      image_spec.reference = {
        'driver_url' => driver_url,
        'driver_version' => Chef::Provisioning::DockerDriver::VERSION,
        'allocated_at' => Time.now.to_i,
        :docker_options => {
          :base_image => {
            :name => "chef_#{image_spec.name}",
            :repository => 'chef',
            :tag => image_spec.name
          },
          :from_image => true
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
      image = Docker::Image.get("chef:#{image_spec.name}")
      image.delete unless image.nil?
    end

    # Connect to machine without acquiring it
    def connect_to_machine(machine_spec, machine_options)
      Chef::Log.debug('Connect to machine')
      machine_for(machine_spec, machine_options)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      if container
        Chef::Log.debug("Destroying container: #{container.id}")
        container.delete(:force => true)
      end

      if !machine_spec.attrs[:keep_image] && !machine_options[:keep_image]
        image = find_image(machine_spec)
        Chef::Log.debug("Destroying image: chef:#{image.id}")
        image.delete
      end
    end

    def stop_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      return if container.nil?

      container.stop if container.info['State']['Running']
    end

    def find_image(machine_spec)
      image = nil

      if machine_spec.reference['image_id']
        begin
          image = Docker::Image.get(machine_spec.reference['image_id'])
        rescue Docker::Error::NotFoundError
        end
      end

      if image.nil?
        image_name = "chef:#{machine_spec.reference['container_name']}"
        if machine_spec.from_image
          base_image = base_image_for(machine_spec)
          image_name = "#{base_image[:repository]}:#{base_image[:tag]}"
        end

        image = Docker::Image.all.select {
            |i| i.info['RepoTags'].include? image_name
        }.first

        if machine_spec.from_image && image.nil?
          raise "Unable to locate machine_image for #{image_name}"
        end
      end

      machine_spec.reference['image_id'] = image.id if image

      image
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

    def driver_url
      "docker:#{Docker.url}"
    end

    def start_machine(action_handler, machine_spec, machine_options)
      container = container_for(machine_spec)
      if container && !container.info['State']['Running']
        container.start
      end
    end

    def machine_for(machine_spec, machine_options)
      Chef::Log.debug('machine_for...')
      docker_options = machine_options[:docker_options] || Mash.from_hash(machine_spec.reference['docker_options'])

      container = Docker::Container.get(machine_spec.reference['container_id'], @connection)

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
        docker_options[:command]
      )
    end

    def container_for(machine_spec)
      container_id = machine_spec.reference['container_id']
      begin
        container = Docker::Container.get(container_id, @connection) if container_id
      rescue Docker::Error::NotFoundError
      end
    end

    def base_image_for(machine_spec)
      Chef::Log.debug("Looking for image #{machine_spec.from_image}")
      image_spec = machine_spec.managed_entry_store.get!(:machine_image, machine_spec.from_image)
      Mash.new(image_spec.reference)[:docker_options][:base_image]
    end
  end
end
end
end
