require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/docker_driver/docker_run_options'

class Chef
module Provisioning
module DockerDriver
  class DockerContainerMachine < Chef::Provisioning::Machine::UnixMachine

    # Expects a machine specification, a usable transport and convergence strategy
    # Options is expected to contain the optional keys
    #   :command => the final command to execute
    #   :ports => a list of port numbers to listen on
    def initialize(machine_spec, transport, convergence_strategy, connection, command = nil)
      super(machine_spec, transport, convergence_strategy)
      @command = command
      @transport = transport
      @connection = connection
    end

    def setup_convergence(action_handler)
      # Build a converge container to converge in
      transport.container = build_converge_container(action_handler)
      unless transport.container.info['State']['Running']
        action_handler.perform_action "start converge container chef-converge.#{machine_spec.name}" do
          transport.container.start!
        end
      end
      super(action_handler)
      # Commit after convergence setup (such as the install of Chef)
      # to break up the cost of the commit and avoid read timeouts
      transport.container.commit
    end

    def converge(action_handler)
      # First, grab and start the converge container if it's there ...
      transport.container = converge_container_for(machine_spec)
      if !transport.container
        raise "No converge container found! Did you run `:converge` without first running `:setup`?"
      end
      unless transport.container.info['State']['Running']
        action_handler.perform_action "start converge container chef-converge.#{machine_spec.name}" do
          transport.container.start!
        end
      end

      # Then, converge ...
      super(action_handler)

      # Save the converged image ...
      converged_image = commit_converged_image(action_handler, machine_spec, transport.container)

      # Build the new container
      transport.container = create_container(action_handler, machine_spec, converged_image)

      # Finally, start it!
      action_handler.perform_action "start container #{machine_spec.name}" do
        transport.container.start!
      end
    end

    private

    def container_config(action_handler, machine_spec)
      docker_options = machine_spec.reference['docker_options'] || {}

      # We're going to delete things to make it easier on ourselves, back it up
      docker_options = docker_options.dup

      # Bring in from_image
      if machine_spec.from_image
        docker_options['base_image'] ||= {}
        docker_options['base_image']['name'] = machine_spec.from_image
      end

      # Respect :container_config
      config = stringize_keys(docker_options.delete('container_config') || {})

      # Respect :base_image
      image = base_image(action_handler, docker_options.delete('base_image'))
      config['Image'] = image if image

      # Respect everything else
      DockerRunOptions.include_command_line_options_in_container_config(config, docker_options)
    end

    # Get the converge container for this machine
    def converge_container_for(machine_spec)
      begin
        Docker::Container.get("chef-converge.#{machine_spec.name}", {}, @connection)
      rescue Docker::Error::NotFoundError
      end
    end

    def container_for(machine_spec)
      begin
        Docker::Container.get(machine_spec.name, {}, @connection)
      rescue Docker::Error::NotFoundError
      end
    end

    # Builds a container that has the same properties as the final container,
    # but with a couple of tweaks to allow processes to run and converge the
    # container.
    def build_converge_container(action_handler)
      # If a converge container already exists, do nothing. TODO check if it's different!!!
      converge_container = converge_container_for(machine_spec)
      if converge_container
        return converge_container
      end

      # Create a chef-capable container (just like the final one, but with --net=host
      # and a command that keeps it open). Base it on the image.
      config = container_config(action_handler, machine_spec)
      config.merge!(
        'name' => "chef-converge.#{machine_spec.reference['container_name']}",
        'Cmd' => [ "/bin/sh", "-c", "while true;do sleep 1000; done" ],
      )
      # If we're using Docker Toolkit, we need to use host networking for the converge
      # so we can open up the port we need. Don't force it in other cases, though.
      if transport.is_local_machine(URI(transport.config[:chef_server_url]).host) &&
         transport.docker_toolkit_transport(@connection.url)
        config['HostConfig'] ||= {}
        config['HostConfig'].merge!('NetworkMode' => 'host')
        # These are incompatible with NetworkMode: host
        config['HostConfig'].delete('Links')
        config['HostConfig'].delete('ExtraHosts')
        config.delete('NetworkSettings')
      end
      # Don't use any resources that need to be shared (such as exposed ports)
      config.delete('ExposedPorts')

      Chef::Log.debug("Creating converge container with config #{config} ...")
      action_handler.perform_action "create container to converge #{machine_spec.name}" do
        # create deletes the name :(
        Docker::Container.create(config.dup, @connection)
        converge_container = Docker::Container.get(config['name'], {}, @connection)
        Chef::Log.debug("Created converge container #{converge_container.id}")
      end
      converge_container
    end

    # Commit the converged container to an image. Called by converge.
    def commit_converged_image(action_handler, machine_spec, converge_container)
      # Commit the converged container to an image
      converged_image = nil
      action_handler.perform_action "commit and delete converged container for #{machine_spec.name}" do
        converged_image = converge_container.commit
        converge_container.stop!
        converge_container.delete
      end
      converged_image
    end

    # Create the final container from the converged image
    def create_container(action_handler, machine_spec, converged_image)
      # Check if the container already exists.
      container = container_for(machine_spec)
      if container
        # If it's the same image, just return; don't stop and start.
        if container.info['Image'] == converged_image.id
          return container
        else
          # If the container exists but is based on an old image, destroy it.
          action_handler.perform_action "stop and delete running container for #{machine_spec.name}" do
            container.stop!
            container.delete
          end
        end
      end

      # Create the new container
      config = container_config(action_handler, machine_spec)
      config.merge!(
        'name' => machine_spec.reference['container_name'],
        'Image' => converged_image.id
      )
      action_handler.perform_action "create final container for #{machine_spec.name}" do
        container = Docker::Container.create(config, @connection)
        machine_spec.reference['container_id'] = container.id
        machine_spec.save(action_handler)
      end
      container
    end

    def stringize_keys(hash)
      hash.each_with_object({}) do |(k,v),hash|
        v = stringize_keys(v) if v.is_a?(Hash)
        hash[k.to_s] = v
      end
    end

    def base_image(action_handler, base_image_value)
      case base_image_value
      when Hash
        params = base_image_value.dup
        if !params['fromImage']
          params['fromImage'] = params.delete('name')
          params['fromImage'] = "#{params['fromImage']}:#{params.delete('tag')}" if params['tag']
        end
      when String
        params = { 'fromImage' => base_image_value }
      when nil
        return nil
      else
        raise "Unexpected type #{base_image_value.class} for docker_options[:base_image]!"
      end

      image_name = params['fromImage']
      repo, image_name = params['fromImage'].split('/', 2) if params['fromImage'].include?('/')

      begin
        image = Docker::Image.get(image_name, {}, @connection)
      rescue Docker::Error::NotFoundError
        # If it's not found, pull it.
        action_handler.perform_action "pull #{params}" do
          image = Docker::Image.create(params, @connection)
        end
      end

      image.id
    end
  end
end
end
end
