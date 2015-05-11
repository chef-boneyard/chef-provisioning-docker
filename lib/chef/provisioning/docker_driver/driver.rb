require 'chef/mixin/shell_out'
require 'chef/provisioning/driver'
require 'chef/provisioning/docker_driver/version'
require 'chef/provisioning/docker_driver/docker_transport'
require 'chef/provisioning/docker_driver/chef_dsl'
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

    attr_reader :credentials
    attr_reader :connection

    # URL scheme:
    # docker:<path>
    # canonical URL calls realpath on <path>
    def self.from_url(driver_url, config)
      Driver.new(driver_url, config)
    end

    def self.canonicalize_url(driver_url, config)
      scheme, url = driver_url.split(':', 2)
      if url && !url.empty?
        # Clean up the connection URL first, within reason. Examples include:
        #   docker:/var/run/docker.sock => unix:///var/run/docker.sock
        #   docker:192.168.0.1:1234 => tcp://192.168.0.1:1234
        case url
        when /^\d+\.\d+\.\d+\.\d+:\d+$/
          url = "tcp://#{url}"
        when /^\//
          url = "unix://#{url}"
        when /^(tcp|unix):/
        else
          url = "tcp://#{url}"
        end
      end
      [ "docker:#{url}", config ]
    end

    def initialize(driver_url, config)
      super
      scheme, url = driver_url.split(':', 2)

      if url
        # Export this as it's expected
        # to be set for command-line utilities
        ENV['DOCKER_HOST'] = url
        # Chef::Log.debug("Setting Docker URL to #{url}")
        # Docker.url = url
      end

      excon_options = Docker.env_options.dup
      excon_options.merge!(driver_options[:excon_options]) if driver_options[:excon_options]
      @connection = Docker::Connection.new(url, excon_options)
      @credentials = driver_options[:docker_credentials]
    end

    #
    # The steps of docker:
    # allocate: must be quick; must ensure a name we can get back to; *should* try to provision in the background.  MUST NOT converge recipes.
    #   - creates a container based on the image, with no convergence.
    # ready: Machine is expected to have an IP and anything else you need to interconnect.  MUST NOT converge recipes.  Container must not be running.
    #   - no action.
    # setup: Get machine prepped to receive Chef.  MUST NOT converge recipes.  Container must not be running.
    #   - no action.
    # converge: bulk of configure time spent here.  MUST converge recipes.  Container must be running.
    #   - converge; start or restart container after converge
    # stop:
    #   - stop container
    # start:
    #   - start container
    # destroy:
    #   - delete container

    def allocate_machine(action_handler, machine_spec, machine_options)
      container_name = machine_spec.name
      machine_spec.reference = {
          'driver_url' => driver_url,
          'driver_version' => Chef::Provisioning::DockerDriver::VERSION,
          'allocated_at' => Time.now.utc.to_s,
          'host_node' => action_handler.host_node,
          'container_name' => container_name,
          'image_id' => machine_options[:image_id]
      }
      container_name = machine_spec.name
      converge = machine_for(machine_spec, machine_options).convergence_strategy
      converge.create_container(action_handler)
    end

    def ready_machine(action_handler, machine_spec, machine_options)
    end

    def stop_machine(action_handler, machine_spec, machine_options)
      machine = machine_for(machine_spec, machine_options)
      machine.convergence_strategy.stop_container(action_handler)
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      machine = machine_for(machine_spec, machine_options)
      machine.convergence_strategy.delete_container(action_handler)
    end

    # Images:

    def allocate_image(action_handler, image_spec, image_options, machine_spec, machine_options)
      machine_for(machine_spec, machine_options).convergency_strategy.converge_image
    end

    def ready_image(action_handler, image_spec, image_options)
    end

    # Connect to machine without acquiring it
    def connect_to_machine(machine_spec, machine_options)
      machine_for(machine_spec, machine_options)
    end

    def image_named(image_name)
      Docker::Image.all({}, connection).select {
          |i| i.info['RepoTags'].include? image_name
      }.first
    end

    def find_image(repository, tag)
      Docker::Image.all({}, connection).select {
          |i| i.info['RepoTags'].include? "#{repository}:#{tag}"
      }.first
    end

    def machine_for(machine_spec, machine_options)
      transport = DockerTransport.new(machine_spec.location['container_name'],
                                      credentials,
                                      connection)

      convergence_strategy = DockerConvergenceStrategy.new(
        connection,
        machine_options[:create_options] || {},
        machine_options[:convergence_options] || {},
        config
      )

      Chef::Provisioning::Machine::UnixMachine.new(
        machine_spec,
        transport,
        convergence_strategy
      )
    end
  end
end
end
end
