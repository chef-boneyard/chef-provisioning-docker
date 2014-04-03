
module ChefMetalDocker
  module Helpers
    module Container

      def commit
        commit_args = cli_args(
          'author' => new_resource.author,
          'message' => new_resource.message,
          'run' => new_resource.run
        )
        commit_end_args = ''

        if new_resource.repository
          commit_end_args = new_resource.repository
          commit_end_args += ":#{new_resource.tag}" if new_resource.tag
        end

        docker_cmd!("commit #{commit_args} #{current_resource.id} #{commit_end_args}")
      end

      def cp
        docker_cmd!("cp #{current_resource.id}:#{new_resource.source} #{new_resource.destination}")
      end

      def export
        docker_cmd!("export #{current_resource.id} > #{new_resource.destination}")
      end

      def kill
        if service?
          service_stop
        else
          docker_cmd!("kill #{current_resource.id}")
        end
      end

      def remove
        rm_args = cli_args(
          'force' => new_resource.force,
          'link' => new_resource.link
        )
        docker_cmd!("rm #{rm_args} #{current_resource.id}")
        service_remove if service?
      end

      def redeploy
        stop if running?
        remove if exists?
        run
      end

      def restart
        if service?
          service_restart
        else
          docker_cmd!("restart #{current_resource.id}")
        end
      end

      # rubocop:disable MethodLength
      def run
        run_args = cli_args(
          'cpu-shares' => new_resource.cpu_shares,
          'cidfile' => cidfile,
          'detach' => new_resource.detach,
          'dns' => Array(new_resource.dns),
          'dns-search' => Array(new_resource.dns_search),
          'env' => Array(new_resource.env),
          'entrypoint' => new_resource.entrypoint,
          'expose' => Array(new_resource.expose),
          'hostname' => new_resource.hostname,
          'interactive' => new_resource.stdin,
          'label' => new_resource.label,
          'link' => Array(new_resource.link),
          'lxc-conf' => Array(new_resource.lxc_conf),
          'memory' => new_resource.memory,
          'networking' => new_resource.networking,
          'name' => container_name,
          'opt' => Array(new_resource.opt),
          'publish' => Array(port),
          'publish-all' => new_resource.publish_exposed_ports,
          'privileged' => new_resource.privileged,
          'rm' => new_resource.remove_automatically,
          'tty' => new_resource.tty,
          'user' => new_resource.user,
          'volume' => Array(new_resource.volume),
          'volumes-from' => new_resource.volumes_from,
          'workdir' => new_resource.working_directory
        )
        dr = docker_cmd!("run #{run_args} #{new_resource.image} #{new_resource.command}")
        dr.error!
        new_resource.id(dr.stdout.chomp)
        service_create if service?
      end
      # rubocop:enable MethodLength

      def service_action(actions)
        if new_resource.init_type == 'runit'
          runit_service service_name do
            run_template_name 'docker-container'
            action actions
          end
        else
          service service_name do
            case new_resource.init_type
            when 'systemd'
              provider Chef::Provider::Service::Systemd
            when 'upstart'
              provider Chef::Provider::Service::Upstart
            end
            supports :status => true, :restart => true, :reload => true
            action actions
          end
        end
      end

      def service_create
        case new_resource.init_type
        when 'runit'
          service_create_runit
        when 'systemd'
          service_create_systemd
        when 'sysv'
          service_create_sysv
        when 'upstart'
          service_create_upstart
        end
      end

      def service_create_runit
        runit_service service_name do
          cookbook new_resource.cookbook
          default_logger true
          options(
            'service_name' => service_name
          )
          run_template_name service_template
        end
      end

      def service_create_systemd
        template "/usr/lib/systemd/system/#{service_name}.socket" do
          if new_resource.socket_template.nil?
            source 'docker-container.socket.erb'
          else
            source new_resource.socket_template
          end
          cookbook new_resource.cookbook
          mode '0644'
          owner 'root'
          group 'root'
          variables(
            :service_name => service_name,
            :sockets => sockets
          )
          not_if port.empty?
        end

        template "/usr/lib/systemd/system/#{service_name}.service" do
          source service_template
          cookbook new_resource.cookbook
          mode '0644'
          owner 'root'
          group 'root'
          variables(
            :cmd_timeout => new_resource.cmd_timeout,
            :service_name => service_name
          )
        end

        service_action([:start, :enable])
      end

      def service_create_sysv
        template "/etc/init.d/#{service_name}" do
          source service_template
          cookbook new_resource.cookbook
          mode '0755'
          owner 'root'
          group 'root'
          variables(
            :cmd_timeout => new_resource.cmd_timeout,
            :service_name => service_name
          )
        end

        service_action([:start, :enable])
      end

      def service_create_upstart
        # The upstart init script requires inotifywait, which is in inotify-tools
        package 'inotify-tools'

        template "/etc/init/#{service_name}.conf" do
          source service_template
          cookbook new_resource.cookbook
          mode '0600'
          owner 'root'
          group 'root'
          variables(
            :cmd_timeout => new_resource.cmd_timeout,
            :service_name => service_name
          )
        end

        service_action([:start, :enable])
      end

      def service_remove
        case new_resource.init_type
        when 'runit'
          service_remove_runit
        when 'systemd'
          service_remove_systemd
        when 'sysv'
          service_remove_sysv
        when 'upstart'
          service_remove_upstart
        end
      end

      def service_remove_runit
        runit_service service_name do
          action :disable
        end
      end

      def service_remove_systemd
        service_action([:stop, :disable])

        %w(service socket).each do |f|
          file "/usr/lib/systemd/system/#{service_name}.#{f}" do
            action :delete
          end
        end
      end

      def service_remove_sysv
        service_action([:stop, :disable])

        file "/etc/init.d/#{service_name}" do
          action :delete
        end
      end

      def service_remove_upstart
        service_action([:stop, :disable])

        file "/etc/init/#{service_name}" do
          action :delete
        end
      end

      def service_restart
        service_action([:restart])
      end

      def service_start
        service_action([:start])
      end

      def service_stop
        service_action([:stop])
      end

      def service_template
        return new_resource.init_template unless new_resource.init_template.nil?
        case new_resource.init_type
        when 'runit'
          'docker-container'
        when 'systemd'
          'docker-container.service.erb'
        when 'upstart'
          'docker-container.conf.erb'
        when 'sysv'
          'docker-container.sysv.erb'
        end
      end

      def start
        start_args = cli_args(
          'attach' => new_resource.attach,
          'interactive' => new_resource.stdin
        )
        if service?
          service_create
        else
          docker_cmd!("start #{start_args} #{current_resource.id}")
        end
      end

      def stop
        stop_args = cli_args(
          'time' => new_resource.cmd_timeout
        )
        if service?
          service_stop
        else
          docker_cmd!("stop #{stop_args} #{current_resource.id}", (new_resource.cmd_timeout + 15))
        end
      end

      def wait
        docker_cmd!("wait #{current_resource.id}")
      end

      def create_container(options)
        run_args = cli_args(options['run_options'])
        dr = docker_cmd!("run #{run_args} #{options['image_name']} #{options['seed_command']}")
        dr.error!
      end

      def cli_args(args)
        command_line = ''
        args.each_pair do |key, value|
          key = key.to_s
          key.gsub!('_', '-')
          if key.size == 1
            command_line << "-#{key}"
          else
            command_line << "--#{key}"
          end
          if value
            command_line << "=#{value}"
          end
        end
        command_line
      end

      # Helper method for `docker_containers` that looks at the position of the headers in the output of
      # `docker ps` to figure out the span of the data for each column within a row. This information is
      # stored in the `ranges` hash, which is returned at the end.
      def get_ranges(header)
        container_id_index = 0
        image_index = header.index('IMAGE')
        command_index = header.index('COMMAND')
        created_index = header.index('CREATED')
        status_index = header.index('STATUS')
        ports_index = header.index('PORTS')
        names_index = header.index('NAMES')

        ranges = {
          :id => [container_id_index, image_index],
          :image => [image_index, command_index],
          :command => [command_index, created_index],
          :created => [created_index, status_index]
        }
        if ports_index > 0
          ranges[:status] = [status_index, ports_index]
          ranges[:ports] = [ports_index, names_index]
        else
          ranges[:status] = [status_index, names_index]
        end
        ranges[:names] = [names_index]
        ranges
      end

      #
      # Get a list of all docker containers by parsing the output of `docker ps -a -notrunc`.
      #
      # Uses `get_ranges` to determine where column data is within each row. Then, for each line after
      # the header, a hash is build up with the values for each of the columns. A special 'line' entry
      # is added to the hash for the raw line of the row.
      #
      # The array of hashes is returned.
      def docker_containers
        dps = docker_cmd!('ps -a -notrunc')

        lines = dps.stdout.lines.to_a
        ranges = get_ranges(lines[0])

        lines[1, lines.length].map do |line|
          ps = { 'line' => line }
          [:id, :image, :command, :created, :status, :ports, :names].each do |name|
            if ranges.key?(name)
              start = ranges[name][0]
              if ranges[name].length == 2
                finish = ranges[name][1]
              else
                finish = line.length
              end
              ps[name.to_s] = line[start..finish - 1].strip
            end
          end
          ps
        end
      end

      def exists?(name)
        docker_containers.each do |ps|
          next unless ps['names'] == name
        end
      end
      
      # Runs a docker command. Does not raise exception on non-zero exit code.
      def docker_cmd(cmd, timeout = new_resource.cmd_timeout)
        execute_cmd('docker ' + cmd, timeout)
      end

      # Executes the given command with the specified timeout. Does not raise an
      # exception on a non-zero exit code.
      def execute_cmd(cmd, timeout = new_resource.cmd_timeout)
        Chef::Log.debug('Executing: ' + cmd)
        begin
          shell_out(cmd, :timeout => timeout)
        rescue Mixlib::ShellOut::CommandTimeout
          raise CommandTimeout, command_timeout_error_message
        end
      end

      # Executes the given docker command with the specified timeout. Raises an
      # exception if the command returns a non-zero exit code.
      def docker_cmd!(cmd, timeout = new_resource.cmd_timeout)
        execute_cmd!('docker ' + cmd, timeout)
      end

      # Executes the given command with the specified timeout. Raises an
      # exception if the command returns a non-zero exit code.
      def execute_cmd!(cmd, timeout = new_resource.cmd_timeout)
        cmd = execute_cmd(cmd, timeout)
        cmd.error!
        cmd
      end

    end
  end
end
