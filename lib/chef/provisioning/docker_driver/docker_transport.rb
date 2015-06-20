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
    def initialize(container, config)
      @container = container
      @config = config
    end

    attr_reader :config
    attr_accessor :container

    def execute(command, options={})
      Chef::Log.debug("execute '#{command}' with options #{options}")

      opts = {}
      if options[:keep_stdin_open]
        opts[:stdin] = true
      end

      command = Shellwords.split(command) if command.is_a?(String)
      response = container.exec(command, opts) do |stream, chunk|
        case stream
        when :stdout
          stream_chunk(options, chunk, nil)
        when :stderr
          stream_chunk(options, nil, chunk)
        end
      end

      Chef::Log.debug("Execute complete: status #{response[2]}")

      DockerResult.new(command.join(' '), options, response[0].join, response[1].join, response[2])
    end

    def read_file(path)
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
      File.open(container_path(path), 'w') { |file| file.write(content) }
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
      FileUtils.cp(local_path, container_path(path))
    end

    def make_url_available_to_remote(url)
      # The host is already open to the container.  Just find out its address and return it!
      uri = URI(url)
      uri.scheme = 'http' if 'chefzero' == uri.scheme && uri.host == 'localhost'
      host = Socket.getaddrinfo(uri.host, uri.scheme, nil, :STREAM)[0][3]
      Chef::Log.debug("Making URL available: #{host}")

      if host == '127.0.0.1' || host == '::1'
        result = execute('ip route list', :read_only => true)

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

    def container_path(path)
      File.join('proc', container.info['State']['Pid'].to_s, 'root', path)
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
