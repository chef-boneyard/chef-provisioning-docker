class Chef
module Provisioning
module DockerDriver
  class DockerRunningTransport < DockerTransport
    def initialize(container, config)
      @container = container
      @config = config
    end

    attr_reader :config

    def execute(command, options={})
      Chef::Log.debug("execute '#{command}' with options #{options}")

      opts = {}
      if options[:keep_stdin_open]
        opts[:stdin] = true
      end

      command = command.split(' ') if command.is_a?(String)
      response = @container.exec(command, opts) do |stream, chunk|
      	case stream
      	when :stdout
      	  stream_chunk(options, chunk, nil)
      	when :stderr
      	  stream_chunk(options, nil, chunk)
      	end
      end

      Chef::Log.debug("Execute complete: status #{response[2]}")

      DockerResult.new(command.join(' '), options, response[0].join(' '), response[1].join(' '), response[2])
    end

    def read_file(path)
      begin
        tarfile = ''
        # NOTE: this would be more efficient if we made it a stream and passed that to Minitar
        @container.copy(path) do |block|
          tarfile << block
        end
      rescue Docker::Error::ServerError
        if $!.message =~ /500/ || $!.message =~ /Could not find the file/
          return nil
        else
          raise
        end
      end

      output = ''
      Archive::Tar::Minitar::Input.open(StringIO.new(tarfile)) do |inp|
        inp.each do |entry|
          while next_output = entry.read
            output << next_output
          end
          entry.close
        end
      end

      output
    end

    def write_file(path, content)
      File.open(container_path(path), 'w') { |file| file.write(content) }
    end

    def upload_file(local_path, path)
      FileUtils.cp(local_path, container_path(path))
    end

    def container_path(path)
      docker_root = File.join( %w(var lib docker aufs mnt) )
      container_root = File.join(docker_root, @container.id)
      File.join(container_root, path)
    end
  end
end
end
end
