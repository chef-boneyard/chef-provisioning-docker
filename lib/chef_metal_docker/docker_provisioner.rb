require 'chef_metal/provisioner'

module ChefMetalDocker
  class DockerProvisioner < ChefMetal::Provisioner
    def acquire_machine(provider, node)

    end

    def connect_to_machine(node)

    end

    def delete_machine(node)
    end

    def stop_machine(node)
    end

    # This is docker-only, not Metal, at the moment.
    # TODO this should be metal.  Find a nice interface.
    def snapshot(node, name=nil)
    end

    # Output Docker tar format image
    # TODO this should be metal.  Find a nice interface.
    def save_repository(node, path)
    end

    # Load Docker tar format image into Docker repository
    def load_repository(path)
    end

    def push_image()
    end
  end
end
