require 'chef_metal/provisioner'
require 'chef_metal/convergence_strategy/no_converge'
require 'chef_metal/convergence_strategy/install_cached'
require 'chef_metal_docker/helpers/container'
require 'chef_metal_docker/docker_transport'
require 'chef_metal_docker/docker_convergence_strategy'
require 'chef_metal_docker/docker_unix_machine'
require 'docker'

module ChefMetalDocker
  class DockerProvisioner < ChefMetal::Provisioner

    include ChefMetalDocker::Helpers::Container

    def initialize(credentials = nil, connection = Docker.connection)
      @credentials = credentials
      @connection = connection
    end

    attr_reader :credentials
    attr_reader :connection

    # Inflate a provisioner from node information; we don't want to force the
    # driver to figure out what the provisioner really needs, since it varies
    # from provisioner to provisioner.
    #
    # ## Parameters
    # node - node to inflate the provisioner for
    #
    # returns a DockerProvisioner
    def self.inflate(node)
      self.new
    end

    #
    # Acquire a machine, generally by provisioning it.  Returns a Machine
    # object pointing at the machine, allowing useful actions like setup,
    # converge, execute, file and directory.  The Machine object will have a
    # "node" property which must be saved to the server (if it is any
    # different from the original node object).
    #
    # ## Parameters
    # action_handler - the action_handler object that plugs into the host.
    # node - node object (deserialized json) representing this machine.  If
    #        the node has a provisioner_options hash in it, these will be used
    #        instead of options provided by the provisioner.  TODO compare and
    #        fail if different?
    #        node will have node['normal']['provisioner_options'] in it with any options.
    #        It is a hash with this format:
    #
    #           -- provisioner_url: docker:<URL of Docker API endpoint>
    #           -- base_image: Base image name to use, or repository_name:tag_name to use a specific tagged revision of that image
    #           -- command: command to run (if unspecified or nil, will spin up the container.  If false, will not run anything and will just leave the image alone.)
    #           -- container_options: options for container create (see http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#create-a-container)
    #           -- host_options: options for container start (see http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#start-a-container)
    #           -- convergence_strategy: :no_converge or :install_cached (former will not converge, latter will set up chef-client and converge)
    #
    #        node['normal']['provisioner_output'] will be populated with information
    #        about the created machine.  For lxc, it is a hash with this
    #        format:
    #
    #           -- provisioner_url: docker:<URL of Docker API endpoint>
    #           -- container_name: docker container name
    #           -- repository_name: docker image repository name from which container was inflated
    #
    def acquire_machine(action_handler, node)
      # Set up the modified node data
      provisioner_options = node['normal']['provisioner_options']
      provisioner_output = node['normal']['provisioner_output'] || {
        'provisioner_url' => "docker:", # TODO put in the Docker API endpoint
        'repository_name' => node['name'], # TODO disambiguate with chef_server_url/path!
        'container_name' => node['name'] # TODO disambiguate with chef_server_url/path!
      }

      container_name = provisioner_output['container_name']
      base_image_name = provisioner_options['base_image']
      raise "base_image not specified in provisioner options!" if !base_image_name

      # Tag the initial image.  We aren't going to actually DO anything yet.
      # We will start up after we converge!
      base_image = Docker::Image.get(base_image_name)
      begin
        repository_image = Docker::Image.get("#{container_name}:latest")
        # If the current image does NOT have the base_image as an ancestor,
        # we are going to have to re-tag it and rebuild.
        if repository_image.history.any? { |entry| entry['Id'] == base_image.id }
          tag_base_image = false
        else
          tag_base_image = true
        end
      rescue Docker::Error::NotFoundError
        tag_base_image = true
      end
      if tag_base_image
        action_handler.perform_action "Tag base image #{base_image_name} as #{container_name}" do
          base_image.tag('repo' => container_name, 'force' => true)
        end
      end

      node['normal']['provisioner_output'] = provisioner_output

      # Nothing else needs to happen until converge.  We already have the image we need!
      machine_for(node)
    end

    def connect_to_machine(node)
      machine_for(node)
    end

    def delete_machine(action_handler, node)
      if node['normal'] && node['normal']['provisioner_output']
        container_name = node['normal']['provisioner_output'][:container_name]
        ChefMetal.inline_resource(action_handler) do
          docker_container container_name do
            action [:kill, :remove]
          end
        end
      end
      convergence_strategy_for(node).cleanup_convergence(action_handler, node)
    end

    def stop_machine(action_handler, node)
      if node['normal'] && node['normal']['provisioner_output']
        container_name = node['normal']['provisioner_output'][:container_name]
        ChefMetal.inline_resource(action_handler) do
          docker_container container_name do
            action [:stop]
          end
        end
      end
    end

    # This is docker-only, not Metal, at the moment.
    # TODO this should be metal.  Find a nice interface.
    def snapshot(action_handler, node, name=nil)
      container_name = node['normal']['provisioner_output'][:container_name]
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          action [:commit]
        end
      end
    end

    # Output Docker tar format image
    # TODO this should be metal.  Find a nice interface.
    def save_repository(action_handler, node, path)
      container_name = node['normal']['provisioner_output'][:container_name]
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          action [:export]
        end
      end
    end

    # Load Docker tar format image into Docker repository
    def load_repository(path)
    end

    # Push an image back to Docker
    def push_image(name)
    end

    # Pull an image from Docker
    def pull_image(name)
    end

    private

    def machine_for(node)
      ChefMetalDocker::DockerUnixMachine.new(node, transport_for(node), convergence_strategy_for(node))
    end

    def convergence_strategy_for(node)
      @convergence_strategy ||= begin
        provisioner_output = node['normal']['provisioner_output']
        provisioner_options = node['normal']['provisioner_options']
        strategy = case provisioner_options['convergence_strategy']
          when :no_converge
            ChefMetal::ConvergenceStrategy::NoConverge.new
          else
            ChefMetal::ConvergenceStrategy::InstallCached.new
          end
        container_configuration = provisioner_options['container_configuration'] || {}
        if provisioner_options['command']
          command = provisioner_options['command']
          command = command.split(/\s+/) if command.is_a?(String)
          container_configuration['Cmd'] = command
        elsif provisioner_options['command'] == false
          container_configuration = nil
        else
          # TODO how do we get things started?  runit?  cron?  wassup here.
          container_configuration['Cmd'] = %w(while 1; sleep 1000; end)
        end
        ChefMetalDocker::DockerConvergenceStrategy.new(strategy,
          provisioner_output['repository_name'],
          provisioner_output['container_name'],
          container_configuration,
          provisioner_options['host_configuration'] || {},
          credentials,
          connection)
      end
    end

    def transport_for(node)
      provisioner_output = node['normal']['provisioner_output']
      ChefMetalDocker::DockerTransport.new(provisioner_output['container_name'], provisioner_output['repository_name'], credentials, connection)
    end
  end
end
