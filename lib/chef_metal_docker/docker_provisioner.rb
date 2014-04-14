require 'chef_metal/provisioner'
require 'chef_metal/convergence_strategy/no_converge'
require 'chef_metal/convergence_strategy/install_cached'
require 'chef_metal_docker/helpers/container'
require 'chef_metal_docker/docker_transport'
require 'chef_metal_docker/docker_unix_machine'
require 'chef_metal/transport/ssh'
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
    #           -- create_container: hash of a container to create.  If present, no image will be created, just a container.
    #              Hash options:
    #              - command: command to run (if unspecified or nil, will spin up the container.  If false, will not run anything and will just leave the image alone.)
    #              - container_options: options for container create (see http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#create-a-container)
    #              - host_options: options for container start (see http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.10/#start-a-container)
    #              - ssh_options: hash of ssh options.  Presence of hash indicates sshd is running in the container.  Net::SSH.new(ssh_options['username'], ssh_options) will be called.  Set 'sudo' to true to sudo all commands (will be detected if username != root)
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
        'repository_name' => "#{node['name']}_image", # TODO disambiguate with chef_server_url/path!
        'container_name' => node['name'] # TODO disambiguate with chef_server_url/path!
      }

      repository_name = provisioner_output['repository_name']
      container_name = provisioner_output['container_name']
      base_image_name = provisioner_options['base_image']
      raise "base_image not specified in provisioner options!" if !base_image_name

      if provisioner_options['create_container']
        create_container(action_handler, provisioner_options, provisioner_output)
        # We don't bother waiting ... our only job is to bring it up.
      else # We are in image build mode.  Get prepped.
        # Tag the initial image.  We aren't going to actually DO anything yet.
        # We will start up after we converge!
        base_image = Docker::Image.get(base_image_name)
        begin
          repository_image = Docker::Image.get("#{repository_name}:latest")
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
          action_handler.perform_action "Tag base image #{base_image_name} as #{repository_name}" do
            base_image.tag('repo' => repository_name, 'force' => true)
          end
        end
      end

      node['normal']['provisioner_output'] = provisioner_output

      if provisioner_options['create_container'] && provisioner_options['create_container']['ssh_options']
        action_handler.perform_action "wait for node to start ssh" do
          transport = transport_for(node)
          Timeout::timeout(5*60) do
            while !transport.available?
              sleep(0.5)
            end
          end
        end
      end

      # Nothing else needs to happen until converge.  We already have the image we need!
      machine_for(node)
    end

    def connect_to_machine(node)
      machine_for(node)
    end

    def delete_machine(action_handler, node)
      if node['normal'] && node['normal']['provisioner_output']
        container_name = node['normal']['provisioner_output']['container_name']
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
        container_name = node['normal']['provisioner_output']['container_name']
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
      container_name = node['normal']['provisioner_output']['container_name']
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          action [:commit]
        end
      end
    end

    # Output Docker tar format image
    # TODO this should be metal.  Find a nice interface.
    def save_repository(action_handler, node, path)
      container_name = node['normal']['provisioner_output']['container_name']
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
      strategy = convergence_strategy_for(node)
      ChefMetalDocker::DockerUnixMachine.new(node, transport_for(node), convergence_strategy_for(node))
    end

    def convergence_strategy_for(node)
      provisioner_output = node['normal']['provisioner_output']
      provisioner_options = node['normal']['provisioner_options']
      strategy = begin
        options = {}
        provisioner_options = node['normal']['provisioner_options'] || {}
        options[:chef_client_timeout] = provisioner_options['chef_client_timeout'] if provisioner_options.has_key?('chef_client_timeout')
        ChefMetal::ConvergenceStrategy::InstallCached.new(options)
      end
    end

    def transport_for(node)
      provisioner_options = node['normal']['provisioner_options']
      provisioner_output = node['normal']['provisioner_output']
      if provisioner_options['create_container'] && provisioner_options['create_container']['ssh_options']
        container = Docker::Container.get(provisioner_output['container_name'])
        ssh_options = {
  # TODO create a user known hosts file
  #          :user_known_hosts_file => vagrant_ssh_config['UserKnownHostsFile'],
  #          :paranoid => true,
          :host_key_alias => "#{container.id}.docker"
        }.merge(provisioner_options['create_container']['ssh_options'])
        username = ssh_options.delete(:username)
        options = {}
        if ssh_options[:sudo] || (!ssh_options.has_key?(:sudo) && username != 'root')
          if ssh_options[:password]
            options[:prefix] = "echo #{ssh_options[:password]} | sudo -S -p '' "
          else
            options[:prefix] = 'sudo '
          end
        end
        ssh_options.delete(:sudo)
        ip_address = container.info['NetworkSettings']['IPAddress']
        Chef::Log.debug("Container #{provisioner_output['container_name']} address is #{ip_address}")
        ChefMetal::Transport::SSH.new(ip_address, username, ssh_options, options)
      else
        ChefMetalDocker::DockerTransport.new(
          provisioner_output['repository_name'],
          provisioner_output['container_name'],
          credentials,
          connection)
      end
    end

    def create_container(action_handler, provisioner_options, provisioner_output)
      container_name = provisioner_output['container_name']

      container_configuration = provisioner_options['create_container']['container_configuration'] || {}
      host_configuration = provisioner_options['create_container']['host_configuration'] || {}
      command = provisioner_options['create_container']['command']
      raise "Must pass create_container.command if creating a container" if !command
      command = command.split(/\s+/) if command.is_a?(String)
      container_configuration['Cmd'] = command
      need_to_create = false
      begin
        # Try to get the container; if that fails, it doesn't exist and we start it.
        container = Docker::Container.get(container_name)
        if !container.info['State']['Running']
          action_handler.perform_action "Delete old, non-running container" do
            container.delete
          end
          need_to_create = true
        end

      rescue Docker::Error::NotFoundError
        need_to_create = true
      end

      if need_to_create
        action_handler.perform_action "Create new container and run container_configuration['Cmd']" do
          container = Docker::Container.create({
            'name' => container_name,
            'Image' => provisioner_options['base_image']
          }.merge(container_configuration), connection)
          container.start!(host_configuration)
        end
      end
    end
  end
end
