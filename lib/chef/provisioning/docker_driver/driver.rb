require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/docker_driver/version'
require 'chef/provisioning/docker_driver/docker_transport'
require 'chef/provisioning/docker_driver/docker_container_machine'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/no_converge'

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

      container_name = machine_spec.name
      machine_spec.location = {
          'driver_url' => driver_url,
          'driver_version' => Chef::Provisioning::DockerDriver::VERSION,
          'allocated_at' => Time.now.utc.to_s,
          'host_node' => action_handler.host_node,
          'container_name' => container_name,
          'image_id' => machine_options[:image_id]
      }
    end

    def ready_machine(action_handler, machine_spec, machine_options)
      base_image_name = build_container(machine_spec, machine_options)
      start_machine(action_handler, machine_spec, machine_options, base_image_name)
      machine_for(machine_spec, machine_options, base_image_name)
    end

    def build_container(machine_spec, machine_options)

      docker_options = machine_options[:docker_options]

      base_image = docker_options[:base_image]
      source_name = base_image[:name]
      source_repository = base_image[:repository]
      source_tag = base_image[:tag]

      # Don't do this if we're loading from an image
      if docker_options[:from_image]
        "#{source_repository}:#{source_tag}"
      else
        target_repository = 'chef'
        target_tag = machine_spec.name

        image = find_image(target_repository, target_tag)

        # kick off image creation
        if image == nil
          Chef::Log.debug("No matching images for #{target_repository}:#{target_tag}, creating!")
          image = Docker::Image.create('fromImage' => source_name,
                                       'repo' => source_repository ,
                                       'tag' => source_tag)
          Chef::Log.debug("Allocated #{image}")
          image.tag('repo' => 'chef', 'tag' => target_tag)
          Chef::Log.debug("Tagged image #{image}")
        end

        "#{target_repository}:#{target_tag}"
      end
    end

    def allocate_image(action_handler, image_spec, image_options, machine_spec)
      # Set machine options on the image to match our newly created image
      image_spec.machine_options = {
        :docker_options => {
          :base_image => {
            :name => "chef_#{image_spec.name}",
            :repository => 'chef',
            :tag => image_spec.name
          },
          :from_image => true
        }
      }
    end

    def ready_image(action_handler, image_spec, image_options)
      Chef::Log.debug('READY IMAGE!')
    end

    # Connect to machine without acquiring it
    def connect_to_machine(machine_spec, machine_options)
      Chef::Log.debug('Connect to machine!')
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      container_name = machine_spec.location['container_name']

      Chef::Log.debug("Destroying container: #{container_name}")
      container = Docker::Container.get(container_name, @connection)

      begin
        Chef::Log.debug("Stopping #{container_name}")
        container.stop
      rescue Excon::Errors::NotModified
        # this is okay
        Chef::Log.debug('Already stopped!')
      end

      begin
      	Chef::Log.debug("Removing #{container_name}")
      	container.delete	
      rescue Docker::Error::ServerError
        # this is okay
        Chef::Log.debug('Already Removed!')
      end

      target_repository = 'chef'
      image = find_image(target_repository, container_name)
      
      if image == nil
         Chef::Log.debug("Image not found!")
      else
        Chef::Log.debug("Removing image!")
        image.delete
      end
    end

    def stop_machine(action_handler, node)
      Chef::Log.debug("Stop machine: #{node.inspect}")
    end

    def image_named(image_name)
      Docker::Image.all.select {
          |i| i.info['RepoTags'].include? image_name
      }.first
    end

    def find_image(repository, tag)
      Docker::Image.all.select {
          |i| i.info['RepoTags'].include? "#{repository}:#{tag}"
      }.first
    end

    def driver_url
      "docker:#{Docker.url}"
    end

    def start_machine(action_handler, machine_spec, machine_options, base_image_name)
      # Spin up a docker instance if needed, otherwise use the existing one
      container_name = machine_spec.location['container_name']

      begin
        Docker::Container.get(container_name, @connection)
      rescue Docker::Error::NotFoundError
        docker_options = machine_options[:docker_options]
        Chef::Log.debug("Start machine for container #{container_name} using base image #{base_image_name} with options #{docker_options.inspect}")
        image = image_named(base_image_name)
        container = Docker::Container.create('Image' => image.id, 'name' => container_name)
        Chef::Log.debug("Container id: #{container.id}")
        machine_spec.location['container_id'] = container.id
      end

    end

    def machine_for(machine_spec, machine_options, base_image_name)
      Chef::Log.debug('machine_for...')

      docker_options = machine_options[:docker_options]

      transport = DockerTransport.new(machine_spec.location['container_name'],
                                      base_image_name,
                                      nil,
                                      Docker.connection)

      convergence_strategy = if docker_options[:from_image]
                               Chef::Provisioning::ConvergenceStrategy::NoConverge.new({}, config)
                             else
                               convergence_strategy_for(machine_spec, machine_options)
                             end

        Chef::Provisioning::DockerDriver::DockerContainerMachine.new(
          machine_spec,
          transport,
          convergence_strategy,
          :command => docker_options[:command],
          :ports => [].push(docker_options[:ports]).flatten,
          :keep_stdin_open => docker_options[:keep_stdin_open]
        )
    end

    def convergence_strategy_for(machine_spec, machine_options)
      @unix_convergence_strategy ||= begin
        Chef::Provisioning::ConvergenceStrategy::InstallCached.
            new(machine_options[:convergence_options], config)
      end
    end

  end
end
end
end
