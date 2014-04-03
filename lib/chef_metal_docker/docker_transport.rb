require 'chef_metal/transport'

module ChefMetalDocker
  class DockerTransport < ChefMetal::Transport
    def execute(command)
    end

    def read_file(path)
    end

    def write_file(path, content)
    end

    def download_file(path, local_path)
    end

    def upload_file(local_path, path)
    end

    # Forward requests to a port on the guest to a server on the host
    def forward_remote_port_to_local(remote_port, local_port)
      raise "forward_remote_port_to_local not overridden on #{self.class}"
    end

    def disconnect
    end

    def available?
    end
  end
end
