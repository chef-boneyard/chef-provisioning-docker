require 'chef/provisioning/transport'
require 'docker'
require 'archive/tar/minitar'
require 'shellwords'
require 'uri'
require 'socket'
require 'mixlib/shellout'
require 'sys/proctable'
require 'chef/provisioning/docker_driver/chef_zero_http_proxy'
require 'chef/provisioning/docker_driver/docker_process'

class Chef
module Provisioning
module DockerDriver
  class DockerTransport < Chef::Provisioning::Transport
    def initialize(config, container_name, credentials, connection)
      @config = config
      @repository_name = 'chef'
      @container_name = container_name
      @credentials = credentials
      @connection = connection
      Docker.logger = Chef::Log.logger
    end

    include Chef::Mixin::ShellOut

    attr_reader :container_name
    attr_reader :repository_name
    attr_reader :image
    attr_reader :credentials
    attr_reader :connection

    # Execute the specified command inside the container, returns a Mixlib::Shellout object
    # Options contains the optional keys:
    #   :detached => true/false - execute this command in detached mode (returns the DockerProcess object early, use wait() to join with it)
    #   :tty => true/false - set up a TTY for this command
    #   :stdin => IO - IO object to use for stdin
    #   :stream => true|false|IO - turn on stdout+stderr streaming
    #   :stream_stdout => true|false|IO - the IO to stream stdout to, or true for STDOUT
    #   :stream_stderr => true|false|IO - the IO to stream stderr to, or true for STDERR
    #
    def execute(command, options={})
      Chef::Log.debug("execute '#{command}' with options #{options}")
      DockerProcess.run(self, command, options)
    end

    def read_file(path)
      container = Docker::Container.new(connection, { 'id' => container_name })
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
      execute("cat > #{path}", stdin: StringIO.new(content))
    end

    def make_url_available_to_remote(url)
      # The host is already open to the container.  Just find out its address and return it!
      uri = URI(url)
      host = Socket.getaddrinfo(uri.host, uri.scheme, nil, :STREAM)[0][3]
      Chef::Log.debug("Making URL available: #{host}")

      if host == '127.0.0.1' || host == '::1'
        result = execute('ip route ls', :read_only => true)

        Chef::Log.debug("IP route: #{result.stdout}\n")

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
          raise "Cannot forward port: ip route ls did not show default in expected format.\nSTDOUT: #{result.stdout}\nSTDERR: #{result.stderr}"
        end
      end
      url
    end

    def disconnect
      @proxy_thread.kill if @proxy_thread
    end

    def available?
      container = Docker::Container.get(connection, { 'id' => container_name })
      container && container.running?
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

# Remove this when https://github.com/opscode/chef/pull/2100 gets merged and released
# nullify live_stream because at the moment EventsOutputStream doesn't understand <<, which
# ShellOut uses

class Chef::EventDispatch::EventsOutputStream
  def <<(str)
    print(str)
  end
end
