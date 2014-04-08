require 'chef_metal/transport'
require 'docker'
require 'archive/tar/minitar'
require 'shellwords'
require 'uri'
require 'socket'

module ChefMetalDocker
  class DockerTransport < ChefMetal::Transport
    def initialize(repository_name, container_name, credentials, connection)
      @repository_name = repository_name
      @image = Docker::Image.get("#{repository_name}:latest", connection)
      @container_name = container_name
      @credentials = credentials
      @connection = connection
    end

    attr_reader :container_name
    attr_reader :repository_name
    attr_reader :image
    attr_reader :credentials
    attr_reader :connection

    def execute(command, options={})
      Chef::Log.debug("execute '#{command}' with options #{options}")
      begin
        # Delete the container if it exists and is dormant
        connection.delete("/containers/#{container_name}")
        Chef::Log.debug("deleted /containers/#{container_name}")
      rescue Docker::Error::NotFoundError
      end
      Chef::Log.debug("Creating #{container_name} from #{repository_name}:latest")
      @container = Docker::Container.create({
        'name' => container_name,
        'Image' => "#{repository_name}:latest",
        'Cmd' => (command.is_a?(String) ? Shellwords.shellsplit(command) : command),
        'AttachStdout' => true,
        'AttachStderr' => true,
        'TTY' => false
      }, connection)

      Chef::Log.debug("Starting #{container_name}")
      # Start the container
      @container.start


      Chef::Log.debug("Setting timeout to 15 minutes")
      Docker.options[:read_timeout] = (15 * 60)

      Chef::Log.debug("Attaching to #{container_name}")
      # Capture stdout / stderr
      stdout = ''
      stderr = ''
      @container.attach do |type, str|
        case type
        when :stdout
          stdout << str
          stream_chunk(options, stdout, nil)
        when :stderr
          stderr << str
          stream_chunk(options, nil, stderr)
        else
          raise "unexpected message type #{type}"
        end
      end

      Chef::Log.debug("Removing temporary read timeout")
      Docker.options.delete(:read_timeout)

      Chef::Log.debug("Grabbing exit status from #{container_name}")
      # Capture exit code
      exit_status = @container.wait

      unless options[:read_only]
        Chef::Log.debug("Committing #{container_name} as #{repository_name}")
        @image = @container.commit('repo' => repository_name)
      end

      Chef::Log.debug("Execute complete: status #{exit_status['StatusCode']}")
      DockerResult.new(command, options, stdout, stderr, exit_status['StatusCode'])
    end

    def read_file(path)
      container = Docker::Container.create({
        'Image' => "#{repository_name}:latest",
        'Cmd' => %w(echo true)
      }, connection)
      begin
        tarfile = ''
        # NOTE: this would be more efficient if we made it a stream and passed that to Minitar
        container.copy(path) do |block|
          tarfile << block
        end
      ensure
        container.delete
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
      # TODO hate tempfiles.  Find an in memory way.
      Tempfile.open('metal_docker_write_file') do |file|
        file.write(content)
        file.close
        @image = @image.insert_local('localPath' => file.path, 'outputPath' => path, 't' => "#{repository_name}:latest")
      end
    end

    def download_file(path, local_path)
      # TODO stream
      file = File.open(local_path, 'w')
      begin
        file.write(read_file(path))
        file.close
      rescue
        File.delete(file)
      end
    end

    def upload_file(local_path, path)
      @image = @image.insert_local('localPath' => local_path, 'outputPath' => path, 't' => "#{repository_name}:latest")
    end

    def make_url_available_to_remote(url)
      # The host is already open to the container.  Just find out its address and return it!
      uri = URI(url)
      host = Socket.getaddrinfo(uri.host, uri.scheme, nil, :STREAM)[0][3]
      if host == '127.0.0.1'
        result = execute('ip route ls', :read_only => true)
        if result.stdout =~ /default via (\S+)/
          uri.host = $1
          return uri.to_s
        else
          raise "Cannot forward port: ip route ls did not show default in expected format.\nSTDOUT: #{result.stdout}"
        end
      end
      url
    end

    def disconnect
    end

    def available?
    end

    private

    # Copy of container.attach with timeout support
    def attach_with_timeout(container, options = {}, read_timeout, &block)
      opts = {
        :stream => true, :stdout => true, :stderr => true
      }.merge(options)
      # Creates list to store stdout and stderr messages
      msgs = Docker::Messages.new
      connection.post(
        "/containers/#{container.id}/attach",
        opts,
        :response_block => attach_for(block, msgs),
        :read_timeout => read_timeout
      )
      [msgs.stdout_messages, msgs.stderr_messages]
    end

    # Method that takes chunks and calls the attached block for each mux'd message
    def attach_for(block, msg_stack)
      messages = Docker::Messages.new
      lambda do |c,r,t|
        messages = messages.decipher_messages(c)
        msg_stack.append(messages)

        unless block.nil?
          messages.stdout_messages.each do |msg|
            block.call(:stdout, msg)
          end
          messages.stderr_messages.each do |msg|
            block.call(:stderr, msg)
          end
        end
      end
    end

    class DockerResult
      def initialize(command, options, stdout, stderr, exitstatus)
        @command = command
        @options = options
        @stdout = stdout
        @stderr = stderr
        @exitstatus = exitstatus
      end

      attr_reader :command
      attr_reader :options
      attr_reader :stdout
      attr_reader :stderr
      attr_reader :exitstatus

      def error!
        if exitstatus != 0
          msg = "Error: command '#{command}' exited with code #{exitstatus}.\n"
          msg << "STDOUT: #{stdout}" if !options[:stream] && !options[:stream_stdout] && Chef::Config.log_level != :debug
          msg << "STDERR: #{stderr}" if !options[:stream] && !options[:stream_stderr] && Chef::Config.log_level != :debug
        end
      end
    end
  end
end
