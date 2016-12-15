require 'chef/provisioning/transport'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/docker_driver/chef_zero_http_proxy'
require 'docker'
require 'archive/tar/minitar'
require 'shellwords'
require 'uri'
require 'socket'
require 'mixlib/shellout'
require 'sys/proctable'
require 'tempfile'

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

    def execute(command, timeout: nil, keep_stdin_open: nil, tty: nil, detached: nil, **options)
      opts = {}
      opts[:tty] = tty unless tty.nil?
      opts[:detached] = detached unless detached.nil?
      opts[:stdin] = keep_stdin_open unless keep_stdin_open.nil?
      opts[:wait] = timeout unless timeout.nil?

      command = Shellwords.split(command) if command.is_a?(String)
      Chef::Log.debug("execute #{command.inspect} on container #{container.id} with options #{opts}'")
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
        container.archive_out(path) do |block|
          tarfile << block
        end
      rescue Docker::Error::NotFoundError
        return nil
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
      tar = StringIO.new(Docker::Util.create_tar(path => content))
      container.archive_in_stream('/') { tar.read }
    end

    def download_file(path, local_path)
      file = File.open(local_path, 'wb')
      begin
        file.write(read_file(path))
        file.close
      rescue
        File.delete(file)
      end
    end

    def upload_file(local_path, path)
      write_file(path, IO.read(local_path, mode: "rb"))
    end

    def make_url_available_to_remote(local_url)
      uri = URI(local_url)

      if uri.scheme == "chefzero" || is_local_machine(uri.host)
        # chefzero: URLs are just http URLs with a shortcut if you are in-process.
        # The remote machine is definitely not in-process.
        uri.scheme = "http" if uri.scheme == "chefzero"

        if docker_toolkit_transport
          # Forward localhost on docker_machine -> chef-zero. The container will
          # be able to access this because it was started with --net=host.
          uri = docker_toolkit_transport.make_url_available_to_remote(uri.to_s)
          uri = URI(uri)
          @docker_toolkit_transport_thread ||= Thread.new do
            begin
              docker_toolkit_transport.send(:session).loop { true }
            rescue
              Chef::Log.error("SSH forwarding loop failed: #{$!}")
              raise
            end
            Chef::Log.debug("Session loop completed normally")
          end
        else
          # We are the host. Find the docker machine's gateway (us) and talk to that;
          # and set up a little proxy that will forward the container's requests to
          # chef-zero
          result = execute('ip route list', :read_only => true)

          Chef::Log.debug("IP route: #{result.stdout}")

          if result.stdout =~ /default via (\S+)/

            old_uri = uri.dup

            uri.host = ENV["PROXY_HOST_OVERRIDE"] ?  ENV["PROXY_HOST_OVERRIDE"] : $1

            if !@proxy_thread
              # Listen to docker instances only, and forward to localhost
              @proxy_thread = Thread.new do
                begin
                  Chef::Log.debug("Starting proxy thread: #{old_uri.host}:#{old_uri.port} <--> #{uri.host}:#{uri.port}")
                  ChefZeroHttpProxy.new(uri.host, uri.port, old_uri.host, old_uri.port).run
                rescue
                  Chef::Log.error("Proxy thread unable to start: #{$!}")
                end
              end
            end
          else
            raise "Cannot forward port: ip route ls did not show default in expected format.\nSTDOUT: #{result.stdout}"
          end

        end
      end

      uri.to_s
    end

    def disconnect
      if @docker_toolkit_transport_thread
        @docker_toolkit_transport_thread.kill
        @docker_toolkit_transport_thread = nil
      end
    end

    def available?
    end

    def is_local_machine(host)
      local_addrs = Socket.ip_address_list
      host_addrs = Addrinfo.getaddrinfo(host, nil)
      local_addrs.any? do |local_addr|
        host_addrs.any? do |host_addr|
          local_addr.ip_address == host_addr.ip_address
        end
      end
    end

    def docker_toolkit_transport(connection_url=nil)
      if !defined?(@docker_toolkit_transport)
        # Figure out which docker-machine this container is in
        begin
          docker_machines = `docker-machine ls --format "{{.Name}},{{.URL}}"`
        rescue Errno::ENOENT
          Chef::Log.debug("docker-machine ls returned ENOENT: Docker Toolkit is presumably not installed.")
          @docker_toolkit_transport = nil
          return
        end

        connection_url ||= container.connection.url

        Chef::Log.debug("Found docker machines:")
        docker_machine = nil
        docker_machines.lines.each do |line|
          machine_name, machine_url = line.chomp.split(',', 2)
          Chef::Log.debug("- #{machine_name} at URL #{machine_url.inspect}")
          if machine_url == connection_url
            Chef::Log.debug("Docker machine #{machine_name} at URL #{machine_url} matches the container's URL #{connection_url}! Will use it for port forwarding.")
            docker_machine = machine_name
          end
        end
        if !docker_machine
          Chef::Log.debug("Docker Toolkit is installed, but no Docker machine's URL matches #{connection_url.inspect}. Assuming docker must be installed as well ...")
          @docker_toolkit_transport = nil
          return
        end

        # Get the SSH information for the docker-machine
        docker_toolkit_json = `docker-machine inspect #{docker_machine}`
        machine_info = JSON.parse(docker_toolkit_json, create_additions: false)["Driver"]
        ssh_host = machine_info["IPAddress"]
        ssh_username = machine_info["SSHUser"]
        ssh_options = {
          # port: machine_info["SSHPort"], seems to be bad information (44930???)
          keys: [ machine_info["SSHKeyPath"] ],
          keys_only: true
        }

        Chef::Log.debug("Docker Toolkit is installed. Will use SSH transport with docker-machine #{docker_machine.inspect} to perform port forwarding.")
        @docker_toolkit_transport = Chef::Provisioning::Transport::SSH.new(ssh_host, ssh_username, ssh_options, {}, Chef::Config)
      end
      @docker_toolkit_transport
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
