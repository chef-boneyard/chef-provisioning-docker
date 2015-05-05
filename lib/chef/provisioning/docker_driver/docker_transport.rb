require 'chef/provisioning/transport'
require 'docker'
require 'archive/tar/minitar'
require 'shellwords'
require 'uri'
require 'socket'
require 'mixlib/shellout'
require 'sys/proctable'
require 'chef/provisioning/docker_driver/chef_zero_http_proxy'

class Chef
module Provisioning
module DockerDriver
  class DockerTransport < Chef::Provisioning::Transport
    def initialize(container_name, base_image_name, credentials, connection, tunnel_transport = nil)
      @repository_name = 'chef'
      @container_name = container_name
      @image = Docker::Image.get(base_image_name, connection)
      @credentials = credentials
      @connection = connection
      @tunnel_transport = tunnel_transport
    end

    include Chef::Mixin::ShellOut

    attr_reader :container_name
    attr_reader :repository_name
    attr_reader :image
    attr_reader :credentials
    attr_reader :connection
    attr_reader :tunnel_transport

    # Execute the specified command inside the container, returns a Mixlib::Shellout object
    # Options contains the optional keys:
    #   :env => env vars
    #   :read_only => Do not commit this execute operation, just execute it
    #   :ports => ports to listen on (-p command-line options)
    #   :detached => true/false, execute this command in detached mode (for final program to run)
    def execute(command, options={})
      Chef::Log.debug("execute '#{command}' with options #{options}")

      begin
        connection.post("/containers/#{container_name}/stop?t=0", '')
        Chef::Log.debug("stopped /containers/#{container_name}")
      rescue Excon::Errors::NotModified
        Chef::Log.debug("Already stopped #{container_name}")
      rescue Docker::Error::NotFoundError
      end

      begin
        # Delete the container if it exists and is dormant
        connection.delete("/containers/#{container_name}?v=true&force=true")
        Chef::Log.debug("deleted /containers/#{container_name}")
      rescue Docker::Error::NotFoundError
      end

      command = Shellwords.split(command) if command.is_a?(String)

      # TODO shell_out has no way to live stream stderr???
      live_stream = nil
      live_stream = STDOUT if options[:stream]
      live_stream = options[:stream_stdout] if options[:stream_stdout]

      args = ['docker', 'run', '--name', container_name]

      if options[:env]      
	options[:env].each do |key, value| 
          args << '-e'
          args << "#{key}=#{value}"
        end
      end

      if options[:detached]
        args << '--detach'
      end

      if options[:ports]
        options[:ports].each do |portnum|
          args << '-p'
          args << "#{portnum}"
        end
      end

      if options[:volumes]
        options[:volumes].each do |volume|
          args << '-v'
          args << "#{volume}"
        end
      end

      if options[:keep_stdin_open]
        args << '-i'
      end

      args << @image.id
      args += command

      cmdstr = Shellwords.join(args)
      Chef::Log.debug("Executing #{cmdstr}")

      # Remove this when https://github.com/opscode/chef/pull/2100 gets merged and released
      # nullify live_stream because at the moment EventsOutputStream doesn't understand <<, which
      # ShellOut uses
      live_stream = nil unless live_stream.respond_to? :<<

      cmd = Mixlib::ShellOut.new(cmdstr, :live_stream => live_stream, :timeout => execute_timeout(options))

      cmd.run_command

      unless options[:read_only]
        Chef::Log.debug("Committing #{container_name} as #{repository_name}:#{container_name}")
        container = Docker::Container.get(container_name)
        @image = container.commit('repo' => repository_name, 'tag' => container_name)
      end

      Chef::Log.debug("Execute complete: status #{cmd.exitstatus}")

      cmd
    end

    def read_file(path)
      container = Docker::Container.create({
        'Image' => @image.id,
        'Cmd' => %w(echo true)
      }, connection)
      begin
        tarfile = ''
        # NOTE: this would be more efficient if we made it a stream and passed that to Minitar
        container.copy(path) do |block|
          tarfile << block
        end
      rescue Docker::Error::ServerError
        if $!.message =~ /500/ || $!.message =~ /Could not find the file/
          return nil
        else
          raise
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
        @image = @image.insert_local('localPath' => file.path, 'outputPath' => path, 't' => "#{repository_name}:#{container_name}")
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
      @image = @image.insert_local('localPath' => local_path, 'outputPath' => path, 't' => "#{repository_name}:#{container_name}")
    end

    def make_url_available_to_remote(url)
      # The host is already open to the container.  Just find out its address and return it!
      uri = URI(url)
      host = Socket.getaddrinfo(uri.host, uri.scheme, nil, :STREAM)[0][3]
      Chef::Log.debug("Making URL available: #{host}")

      if host == '127.0.0.1' || host == '::1'
        result = execute('ip route ls', :read_only => true)

        Chef::Log.debug("IP route: #{result.stdout}")

        if result.stdout =~ /default via (\S+)/

          uri.host = if using_boot2docker?
                       # Intermediate VM does NAT, so local address should be fine here
                       Chef::Log.debug("Using boot2docker!")
                       IPSocket.getaddress(Socket.gethostname)
                     else
                       $1
                     end

          if !@proxy_thread
            # Listen to docker instances only, and forward to localhost
            @proxy_thread = Thread.new do
              Chef::Log.debug("Starting proxy thread: #{uri.host}:#{uri.port} <--> #{host}:#{uri.port}")
              ChefZeroHttpProxy.new(uri.host, uri.port, host, uri.port).run
            end
          end
          Chef::Log.debug("Using Chef server URL: #{uri.to_s}")

          return uri.to_s
        else
          raise "Cannot forward port: ip route ls did not show default in expected format.\nSTDOUT: #{result.stdout}"
        end
      end
      url
    end

    def disconnect
      @proxy_thread.kill if @proxy_thread
    end

    def available?
    end

    private

    # boot2docker introduces an intermediate VM so we need to use a slightly different
    # mechanism for getting to the running chef-zero
    def using_boot2docker?
      Sys::ProcTable.ps do |proc|
        if proc.respond_to?(:cmdline)
          if proc.send(:cmdline).to_s =~ /.*--comment boot2docker.*/
            return true
          end
        end
      end
    end

    # Copy of container.attach with timeout support and pipeline
    def attach_with_timeout(container, read_timeout, options = {}, &block)
      opts = {
        :stream => true, :stdout => true, :stderr => true
      }.merge(options)
      # Creates list to store stdout and stderr messages
      msgs = Docker::Messages.new
      connection.start_request(
        :post,
        "/containers/#{container.id}/attach",
        opts,
        :response_block => attach_for(block, msgs),
        :read_timeout => read_timeout,
        :pipeline => true,
        :persistent => true
      )
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
          raise msg
        end
      end
    end
  end
end
end
end

class Docker::Connection
  def start_request(method, *args, &block)
    request = compile_request_params(method, *args, &block)
    if Docker.logger
      Docker.logger.debug(
        [request[:method], request[:path], request[:query], request[:body]]
      )
    end
    excon = resource
    [ excon, excon.request(request) ]
  rescue Excon::Errors::BadRequest => ex
    raise ClientError, ex.message
  rescue Excon::Errors::Unauthorized => ex
    raise UnauthorizedError, ex.message
  rescue Excon::Errors::NotFound => ex
    raise NotFoundError, ex.message
  rescue Excon::Errors::InternalServerError => ex
    raise ServerError, ex.message
  rescue Excon::Errors::Timeout => ex
    raise TimeoutError, ex.message
  end
end
