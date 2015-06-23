require 'chef/provisioning/convergence_strategy/precreate_chef_objects'
require 'chef/provisioning/convergence_strategy/install_cached'

# We don't want to install chef-client omnibus into container. Instead we'll 
# mount volume with exiting installation or install it on that volume if missing.
class Chef
module Provisioning
module DockerDriver
  class ConvergenceStrategy < Chef::Provisioning::ConvergenceStrategy::InstallCached

    # Initializes instance, sets volume to install chef-client to 
    # "/tmp/opt/chef:/opt/chef" by default.
    def initialize(convergence_options, config)
      super(convergence_options, config)
      # Chef obmibus installation directory on host machine.
      @chef_volume = (convergence_options[:chef_volume] || '/tmp/opt/chef') + ":/opt/chef"
    end

    # Inlike Chef::Provisioning::ConvergenceStrategy::InstallCached, will not 
    # upload package to machine, but mount it as volume instead.
    def setup_convergence(action_handler, machine)
      # We still need some basic setup from InstallCached parent class.
      PrecreateChefObjects.instance_method(:setup_convergence).bind(self).call(action_handler, machine)

      # Check for existing chef client.
      version = machine.execute_always('chef-client -v', :volumes => [@chef_volume])

      # Don't do install/upgrade if a chef client exists and
      # no chef version is defined by user configs or
      # the chef client's version already matches user config
      if version.exitstatus == 0
        version = version.stdout.strip
        if !chef_version
          return
        elsif version =~ /Chef: #{chef_version}$/
          Chef::Log.debug "Already installed chef version #{version}"
          return
        elsif version.include?(chef_version)
          Chef::Log.warn "Installed chef version #{version} contains desired version #{chef_version}.  " +
            "If you see this message on consecutive chef runs tighten your desired version constraint to prevent " +
            "multiple convergence."
        end
      end

      # Install chef client
      platform, platform_version, machine_architecture = machine.detect_os(action_handler)
      package_file = download_package_for_platform(action_handler, machine, platform, platform_version, machine_architecture)
      remote_package_file = "#{@tmp_dir}/#{File.basename(package_file)}"
      install_package(action_handler, machine, remote_package_file)
    end

    # Converge machine using volumes from machine options and chef installalation
    # from @chef_volume (default "/tmp/opt/chef:/opt/chef").
    # This implementation also allows to mount volumes during recipes execution 
    # including machine images creation.
    def converge(action_handler, machine)
      Chef::Log.debug("Converge machine using machine volumes: #{machine.volumes}")
      PrecreateChefObjects.instance_method(:converge).bind(self).call(action_handler, machine)

      action_handler.open_stream(machine.node['name']) do |stdout|
        action_handler.open_stream(machine.node['name']) do |stderr|
          command_line = "chef-client"
          command_line << " -l #{config[:log_level].to_s}" if config[:log_level]
          machine.execute(action_handler, command_line,
            :stream_stdout => stdout,
            :stream_stderr => stderr,
            :timeout => @chef_client_timeout,
	    # In case we've specified volumes in machine options, it needs 
	    # to be accessible during converge too.
            :volumes => Array(machine.volumes) << @chef_volume)
        end
      end
    end

    # Installs chef-client omnibus inside container on mounted volume 
    # (see @chef_volume), package is also mounted as ro volume.
    def install_package(action_handler, machine, remote_package_file)

      local_package_file = File.join(@package_cache_path, File.basename(remote_package_file))
      opts = {:volumes => [@chef_volume, "#{local_package_file}:#{remote_package_file}:ro"]}
      extension = File.extname(remote_package_file)
      result = case extension
      when '.rpm'
        machine.execute(action_handler, "rpm -Uvh --oldpackage --replacepkgs \"#{remote_package_file}\"", opts)
      when '.deb'
        machine.execute(action_handler, "dpkg -i \"#{remote_package_file}\"", opts)
      when '.sh'
        machine.execute(action_handler, "sh \"#{remote_package_file}\"", opts)
      else
        raise "Unknown package extension '#{extension}' for file #{remote_package_file}"
      end
    end
  end
end
end
end
