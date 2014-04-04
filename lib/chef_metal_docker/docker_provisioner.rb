require 'chef_metal/provisioner'
require 'chef_metal/machine/unix_machine'
require 'chef_metal/convergence_strategy/no_converge'
require 'chef_metal_docker/helpers/container'
require 'chef_metal_docker/docker_transport'
require 'chef/resource/docker_container'
require 'chef/provider/docker_container'

module ChefMetalDocker
  class DockerProvisioner < ChefMetal::Provisioner

    include ChefMetalDocker::Helpers::Container

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
    #           -- image_name: Image name to use, or image_name:tag_name to use a specific tagged revision of that image
    #           -- run_options: the options to run, e.g. { :cpu_shares => 2, :}
    #           -- seed_command: the seed command and its arguments, e.g. "echo true"
    #
    #        node['normal']['provisioner_output'] will be populated with information
    #        about the created machine.  For lxc, it is a hash with this
    #        format:
    #
    #           -- provisioner_url: docker:<URL of Docker API endpoint>
    #           -- docker_name: container name
    #
    def acquire_machine(action_handler, node)
      # Set up the modified node data
      provisioner_options = node['normal']['provisioner_options']
      provisioner_output = node['normal']['provisioner_output'] || {
        'provisioner_url' => "docker:", # TODO put in the Docker API endpoint
        :container_name => node['name'] # TODO disambiguate with chef_server_url/path!
      }

      container_name = provisioner_output[:container_name]
      seed_command = provisioner_options[:seed_command]
      image_name = provisioner_options[:image_name]
      run_options =  provisioner_options[:run_options]

      # Launch the container
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          command   seed_command
          image     image_name
          run_options.each do |opt, value|
            self.send(opt, value)
          end
          action [:run]
        end
      end

      machine_for(node)
    end


    def connect_to_machine(node)
      machine_for(node)
    end

    def delete_machine(action_handler, node)
      container_name = node['normal']['provisioner_output']['container_name']
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          action [:kill, :remove]
        end
      end
    end

    def stop_machine(action_handler, node)
      container_name = node['normal']['provisioner_output']['container_name']
      ChefMetal.inline_resource(action_handler) do
        docker_container container_name do
          action [:stop]
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
      ChefMetal::Machine::UnixMachine.new(node, transport_for(node), convergence_strategy_for(node))
    end

    def convergence_strategy_for(node)
      @convergence_strategy ||= begin
                                  ChefMetal::ConvergenceStrategy::NoConverge.new
                                end
    end

    def transport_for(node)
      #provisioner_output = node['normal']['provisioner_output']
      ChefMetalDocker::DockerTransport.new()
    end
  end
end
