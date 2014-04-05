require 'chef_metal/transport'
require 'docker'
require 'archive/tar/minitar'

module ChefMetalDocker
  class DockerTransport < ChefMetal::Transport
    def initialize(image_name, container_name, credentials, connection)
      @image_name = image_name
      @container_name = container_name
      @image = Docker::Image.get(image_name)
      @credentials = credentials
      @connection = connection
      @forwarded_ports = []
    end

    attr_reader :container_name
    attr_reader :image_name
    attr_reader :image
    attr_reader :credentials
    attr_reader :connection
    attr_reader :forwarded_ports

    def execute(command)
      container = Docker::Container.create({
        'name' => container_name,
        'Image' => image_name,
        'Cmd' => (command.is_a?(String) ? command.split(/\s+/) : command)
        'ExposedPorts' => @forwarded_ports.inject({}) do |result, remote_port, local_port|
          result["#{remote_port}/tcp"] = {}
          result
        end,
        'AttachStdout' => true,
        'AttachStderr' => true,
        'TTY' => false
      }, connection)
      container.start({
        'PortBindings' => @forwarded_ports.inject({}) do |result, remote_port, local_port|
          result["#{remote_port}/tcp"] = [{
            'HostIp': '127.0.0.1',
            'HostPort': local_port
          }]
          result
        end
      })
      stdout, stderr = container.attach
      exit_status = container.wait
      @image = container.commit('repo' => image_name)
      DockerResult.new(stdout.join(''), stderr.join(''), exit_status)
    end

    def read_file(path)
      container = Docker::Container.create({ 'Image' => image_name }, connection)
      tarfile = ''
      # NOTE: this would be more efficient if we made it a stream and passed that to Minitar
      container.copy(path) do |block|
        tarfile << block
      end

      Archive::Tar::Minitar::Input.open(StringIO.new(tarfile)) do |inp|
        inp.each do |entry|
          output = ''
          while next_output = entry.read
            output << next_output
          end
          entry.close
        end
      end
    end

    def write_file(path, content)
      # TODO hate tempfiles.  Find an in memory way.
      Tempfile.new do |file|
        file.write(content)
        file.close
        @image = @image.insert_local('localPath' => file.path, 'outputPath' => path, 't' => image_name)
      end
    end

    def download_file(path, local_path)
      container = Docker::Container.create({ 'Image' => @image.id }, connection)
      tarfile = ''
      # NOTE: this would be more efficient if we made it a stream and passed that to Minitar
      container.copy(path) do |block|
        tarfile << block
      end

      Archive::Tar::Minitar.unpack(StringIO.new(tarfile), local_path)
    end

    def upload_file(local_path, path)
      @image = @image.insert_local('localPath' => local_path, 'outputPath' => path, 't' => image_name)
    end

    # Forward requests to a port on the guest to a server on the host
    def forward_remote_port_to_local(remote_port, local_port)
      @forwarded_ports << [ remote_port, local_port ]
    end

    def disconnect
    end

    def available?
    end

    class DockerResult
      def initialize(stdout, stderr, exitstatus)
        @stdout = stdout
        @stderr = stderr
        @exitstatus = exitstatus
      end

      attr_reader :stdout
      attr_reader :stderr
      attr_reader :exitstatus

      def error!
        raise "Error: code #{exitstatus}.\nSTDOUT:#{stdout}\nSTDERR:#{stderr}" if exitstatus != 0
      end
    end
  end
end
