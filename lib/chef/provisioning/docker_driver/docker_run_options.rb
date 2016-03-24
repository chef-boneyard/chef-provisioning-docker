class Chef
module Provisioning
module DockerDriver
#
# Allows the user to specify docker options that calculate the desired container config
#
# Command line options follow later in the file (search for `cli_option :command` for the first one).
#
# The API allows these settings:
#
# (https://docs.docker.com/engine/reference/api/docker_remote_api_v1.22/#create-a-container)
#
# ArgsEscaped - bool // True if command is already escaped (Windows specific)
# AttachStderr - Boolean value, attaches to stderr.
#              - `docker run --attach STDERR`
# AttachStdin - Boolean value, attaches to stdin.
#              - `docker run --attach STDIN`
#              - `docker run --interactive`
# AttachStdout - Boolean value, attaches to stdout.
#              - `docker run --attach STDOUT`
# Cmd - Command to run specified as a string or an array of strings.
#     - `docker run <image> COMMAND`
# Cpuset - Deprecated please don’t use. Use CpusetCpus instead.
# Domainname - A string value containing the domain name to use for the container.
# Entrypoint - Set the entry point for the container as a string or an array of strings.
#            - `docker run --entrypoint "COMMAND"`
# Env - A list of environment variables in the form of ["VAR=value"[,"VAR2=value2"]]
#     - `docker --env "A=B"`
# ExposedPorts - An object mapping ports to an empty object in the form of: "ExposedPorts": { "<port>/<tcp|udp>: {}" }
#     - `docker run --expose PORT`
#     - `docker run --publish 8080:8081`
# HostConfig/AutoRemove - bool          // Automatically remove container when it exits
#     - `docker run --rm`
# HostConfig/Binds – A list of volume bindings for this container. Each volume binding is a string in one of these forms:
#   - container_path to create a new volume for the container
#   - host_path:container_path to bind-mount a host path into the container
#   - host_path:container_path:ro to make the bind-mount read-only inside the container.
#   - volume_name:container_path to bind-mount a volume managed by a volume plugin into the container.
#   - volume_name:container_path:ro to make the bind mount read-only inside the container.
#   - `docker run --volume /host/path:/container/path`
# HostConfig/BlkioBps - uint64 // Maximum Bytes per second for the container system drive
# HostConfig/BlkioDeviceReadBps - Limit read rate (bytes per second) from a device in the form of: "BlkioDeviceReadBps": [{"Path": "device_path", "Rate": rate}], for example: "BlkioDeviceReadBps": [{"Path": "/dev/sda", "Rate": "1024"}]"
#                               - `docker run --device-read-bps=/dev/sda:1mb`
# HostConfig/BlkioDeviceReadIOps - Limit read rate (IO per second) from a device in the form of: "BlkioDeviceReadIOps": [{"Path": "device_path", "Rate": rate}], for example: "BlkioDeviceReadIOps": [{"Path": "/dev/sda", "Rate": "1000"}]
#                                - `docker run --device-read-iops=/dev/sda:1000`
# HostConfig/BlkioDeviceWriteBps - Limit write rate (bytes per second) to a device in the form of: "BlkioDeviceWriteBps": [{"Path": "device_path", "Rate": rate}], for example: "BlkioDeviceWriteBps": [{"Path": "/dev/sda", "Rate": "1024"}]"
#                                 - `docker run --device-write-bps=/dev/sda:1mb`
# HostConfig/BlkioDeviceWriteIOps - Limit write rate (IO per second) to a device in the form of: "BlkioDeviceWriteIOps": [{"Path": "device_path", "Rate": rate}], for example: "BlkioDeviceWriteIOps": [{"Path": "/dev/sda", "Rate": "1000"}]
#                                 - `docker run --device-write-iops=/dev/sda:1000`
# HostConfig/BlkioIOps - uint64 // Maximum IOps for the container system drive
# HostConfig/BlkioWeight - Block IO weight (relative weight) accepts a weight value between 10 and 1000.
#                        - `docker run --blkio-weight 0`
# HostConfig/BlkioWeightDevice - Block IO weight (relative device weight) in the form of: "BlkioWeightDevice": [{"Path": "device_path", "Weight": weight}]
#                              - `docker run --blkio-weight-device path:weight`
# HostConfig/CapAdd - A list of kernel capabilities to add to the container.
#                   - `docker run --cap-add capability`
# HostConfig/CapDrop - A list of kernel capabilities to drop from the container.
#                   - `docker run --cap-drop capability`
# HostConfig/CgroupParent - Path to cgroups under which the container’s cgroup is created. If the path is not absolute, the path is considered to be relative to the cgroups path of the init process. Cgroups are created if they do not already exist.
#                   - `docker run --cgroup-parent parent`
# HostConfig/ConsoleSize - [2]int    // Initial console size
# HostConfig/ContainerIDFile - string        // File (path) where the containerId is written
#                            - `docker run --cidfile file`
# HostConfig/CpuPeriod - The length of a CPU period in microseconds.
#                      - `docker run --cpu-period 0`
# HostConfig/CpuQuota - Microseconds of CPU time that the container can get in a CPU period.
#                      - `docker run --cpu-quota 0`
# HostConfig/CpuShares - An integer value containing the container’s CPU Shares (ie. the relative weight vs other containers).
#                      - `docker run --cpu-shares 0`
# HostConfig/CpusetCpus - String value containing the cgroups CpusetCpus to use.
#                      - `docker run --cpuset-cpus 0-3`
# HostConfig/CpusetMems - Memory nodes (MEMs) in which to allow execution (0-3, 0,1). Only effective on NUMA systems.
#                      - `docker run --cpuset-mems 0-3`
# HostConfig/Devices - A list of devices to add to the container specified as a JSON object in the form { "PathOnHost": "/dev/deviceName", "PathInContainer": "/dev/deviceName", "CgroupPermissions": "mrw"}
#                    - `docker run --device path_on_host:path_in_container:cgroup_permissions`
# HostConfig/DiskQuota - int64           // Disk limit (in bytes)
# HostConfig/Dns - A list of DNS servers for the container to use.
#                - `docker run --dns ip`
# HostConfig/DnsOptions - A list of DNS options
#                       - `docker run --dns-opt a=b`
# HostConfig/DnsSearch - A list of DNS search domains
#                       - `docker run --dns-opt domain`
# HostConfig/ExtraHosts - A list of hostnames/IP mappings to add to the container’s /etc/hosts file. Specified in the form ["hostname:IP"].
#                       - `docker run --add-host host:ip`
# HostConfig/GroupAdd - A list of additional groups that the container process will run as
#                     - `docker run --group-add blah`
# HostConfig/IpcMode - IpcMode           // IPC namespace to use for the container
#                     - `docker run --ipc host`
# HostConfig/Isolation - Isolation // Isolation technology of the container (eg default, hyperv)
#                      - `docker run --isolation host`
# HostConfig/KernelMemory - Kernel memory limit in bytes.
#                         - `docker run --kernel-memory 4m`
# HostConfig/Links - A list of links for the container. Each link entry should be in the form of container_name:alias.
#                  - `docker run --link containername`
# HostConfig/LogConfig - Log configuration for the container, specified as a JSON object in the form { "Type": "<driver_name>", "Config": {"key1": "val1"}}. Available types: json-file, syslog, journald, gelf, awslogs, splunk, none. json-file logging driver.
# HostConfig/LogConfig/Type
#                           - `docker run --log-driver driver`
# HostConfig/LogConfig/Config
#                             - `docker run --log-opt a=b`
# HostConfig/Memory - Memory limit in bytes.
#                   - `docker run --memory 4G`
# HostConfig/MemoryReservation - Memory soft limit in bytes.
#                   - `docker run --memory-reservation 4G`
# HostConfig/MemorySwap - Total memory limit (memory + swap); set -1 to enable unlimited swap. You must use this with memory and make the swap value larger than memory.
#                   - `docker run --memory-swap 4G`
# HostConfig/MemorySwappiness - Tune a container’s memory swappiness behavior. Accepts an integer between 0 and 100.
#                   - `docker run --memory-swappiness 50`
# HostConfig/NetworkMode - Sets the networking mode for the container. Supported standard values are: bridge, host, none, and container:<name|id>. Any other value is taken as a custom network’s name to which this container should connect to.
#                        - `docker run --net host`
# HostConfig/OomKillDisable - Boolean value, whether to disable OOM Killer for the container or not.
#                           - `docker run --oom-kill-disable`
# HostConfig/OomScoreAdj - An integer value containing the score given to the container in order to tune OOM killer preferences.
#                        - `docker run --oom-score-adj 1`
# HostConfig/PidMode - PidMode           // PID namespace to use for the container
#                    - `docker run --pid host`
# HostConfig/PidsLimit - int64           // Setting pids limit for a container
# HostConfig/PortBindings - A map of exposed container ports and the host port they should map to. A JSON object in the form { <port>/<protocol>: [{ "HostPort": "<port>" }] } Take note that port is specified as a string and not an integer value.
#                         - `docker run --publish 8080:8081`
# HostConfig/Privileged - Gives the container full access to the host. Specified as a boolean value.
#                       - `docker run --privileged`
# HostConfig/PublishAllPorts - Allocates a random host port for all of a container’s exposed ports. Specified as a boolean value.
#                            - `docker run --publish-all`
# HostConfig/ReadonlyRootfs - Mount the container’s root filesystem as read only. Specified as a boolean value.
#                           - `docker run --read-only`
# HostConfig/RestartPolicy – The behavior to apply when the container exits. The value is an object with a Name property of either "always" to always restart, "unless-stopped" to restart always except when user has manually stopped the container or "on-failure" to restart only when the container exit code is non-zero. If on-failure is used, MaximumRetryCount controls the number of times to retry before giving up. The default is not to restart. (optional) An ever increasing delay (double the previous delay, starting at 100mS) is added before each restart to prevent flooding the server.
#                          - `docker run --restart no`
# HostConfig/RestartPolicy/Name
#                               - `docker run --restart always`
# HostConfig/RestartPolicy/MaximumRetryCount
#                                            - `docker run --restart on-failure:20`
# HostConfig/SandboxSize - uint64 // System drive will be expanded to at least this size (in bytes)
# HostConfig/SecurityOpt - A list of string values to customize labels for MLS systems, such as SELinux.
#                        - docker run --security-opt label:disabled
# HostConfig/ShmSize - Size of /dev/shm in bytes. The size must be greater than 0. If omitted the system uses 64MB.
#                    - `docker run --shm-size 4m`
# HostConfig/StorageOpt - []string          // Storage driver options per container.
# HostConfig/Sysctls - map[string]string    // List of Namespaced sysctls used for the container
# HostConfig/Tmpfs - map[string]string // List of tmpfs (mounts) used for the container
# HostConfig/Ulimits - A list of ulimits to set in the container, specified as { "Name": <name>, "Soft": <soft limit>, "Hard": <hard limit> }, for example: Ulimits: { "Name": "nofile", "Soft": 1024, "Hard": 2048 }
#                    - `docker run --ulimit /dev/sda:1024:2048`
# HostConfig/UTSMode - UTSMode           // UTS namespace to use for the container
#                    - `docker run --uts host`
# HostConfig/UsernsMode - UsernsMode     // The user namespace to use for the container
# HostConfig/VolumeDriver - Driver that this container users to mount volumes.
#                         - `docker run --volume-driver supervolume`
# HostConfig/VolumesFrom - A list of volumes to inherit from another container. Specified in the form <container name>[:<ro|rw>]
#                        - `docker run --volumes-from db`
# Hostname - A string value containing the hostname to use for the container.
#          - `docker run --hostname blah`
# Image - A string specifying the image name to use for the container.
#       - `docker run IMAGE_NAME ...`
# Labels - Adds a map of labels to a container. To specify a map: {"key":"value"[,"key2":"value2"]}
#        - `docker run --label a=b`
# MacAddress - string                // Mac Address of the container
#            - `docker run --mac-address 92:d0:c6:0a:29:33`
# Mounts - An array of mount points in the container.
# NetworkDisabled - Boolean value, when true disables networking for the container
# NetworkSettings/<network>/IPAMConfig/IPv4Address
#                                                  - `docker run --ip address`
# NetworkSettings/<network>/IPAMConfig/IPv6Address
#                                                  - `docker run --ip6 address`
# NetworkSettings/<network>/Aliases
#                                   - `docker run --net-alias blah`
# OnBuild - []string              // ONBUILD metadata that were defined on the image Dockerfile
# OpenStdin - Boolean value, opens stdin,
#           - `docker run --interactive`
# PublishService - string                // Name of the network service exposed by the container
# StdinOnce - Boolean value, close stdin after the 1 attached client disconnects.
# StopSignal - Signal to stop a container as a string or unsigned integer. SIGTERM by default.
#            - `docker run --stop-signal SIGKILL`
# Tty - Boolean value, Attach standard streams to a tty, including stdin if it is not closed.
#     - `docker run --tty`
# User - A string value specifying the user inside the container.
#      - `docker run --user bob:wheel`
# Volumes - map[string]struct{}   // List of volumes (mounts) used for the container
#         - `docker run --volume blarghle`
# WorkingDir - A string specifying the working directory for commands to run in.
#            - `docker run --workdir /home/uber`
#
# The following are runtime updateable:
#	HostConfig/BlkioBps
#	HostConfig/BlkioIOps
#	HostConfig/BlkioWeight
#	HostConfig/BlkioWeightDevice
#	HostConfig/BlkioDeviceReadBps
#	HostConfig/BlkioDeviceWriteBps
#	HostConfig/BlkioDeviceReadIOps
#	HostConfig/BlkioDeviceWriteIOps
#	HostConfig/CgroupParent
#	HostConfig/CpuPeriod
#	HostConfig/CpuQuota
#	HostConfig/CpuShares
#	HostConfig/CpusetCpus
#	HostConfig/CpusetMems
#	HostConfig/Devices
#	HostConfig/DiskQuota
#	HostConfig/KernelMemory
#	HostConfig/Memory
#	HostConfig/MemoryReservation
#	HostConfig/MemorySwap
#	HostConfig/MemorySwappiness
#	HostConfig/OomKillDisable
#	HostConfig/PidsLimit
# HostConfig/RestartPolicy
#	HostConfig/SandboxSize
#	HostConfig/Ulimits
#
class DockerRunOptions
  def self.include_command_line_options_in_container_config(config, docker_options)

    # Grab the command line options we've begun supporting
    # The following are command line equivalents for `docker run`
    docker_options.each do |key, value|
      # Remove -, symbolize key
      key = key.to_s.gsub('-', '_').to_sym
      option = cli_options[key]
      if !option
        raise "Unknown option in docker_options: #{key.inspect}"
      end

      # Figure out the new value
      if option[:type] == :boolean
        value == !!value
      elsif option[:type] == Array
        value = Array(value)
      elsif option[:type] == Integer
        value = parse_int(value) if value.is_a?(String)
      elsif option[:type].is_a?(String)
        # If it's A:B:C, translate [ "a:b:c", "d:e:f" ] -> [ { "A" => "a", "B" => "b", "C" => "c" }, { "A" => "d", "B" => "e", "C" => "f" } ]
        names = option[:type].split(":")
        if names.size == 2 && value.is_a?(Hash)
          value.map { |key,value| { names[0] => key, names[1] => value } }
        else
          Array(value).map do |item|
            item_values = item.split(":", names.size)
            item = Hash[names.zip(item_values)]
          end
        end
      end

      option[:api].each do |api|
        # Grab the parent API key so we know what we're setting
        api_parent = config
        api.split("/")[0..-2].each do |api_key|
          api_parent[api_key] = {} if !api_parent[api_key]
          api_parent = api_parent[api_key]
        end
        api_key = api.split("/")[-1] if api

        # Bring in the current value
        if option[:type] == Array || option[:type].is_a?(String)
          api_parent[api_key] ||= []
          api_parent[api_key] += value
        else
          api_parent[api_key] = value
        end
      end

      # Call the block (if any)
      if option[:block]
        option[:block].call(config, value)
      end
    end
    config
  end

  def self.cli_options
    @cli_options ||= {}
  end

  def self.cli_option(option_name, type=nil, aliases: nil, api: nil, &block)
    api = Array(api)
    cli_options[option_name] = { type: type, api: Array(api), block: block }
    Array(aliases).each do |option_name|
      cli_options[option_name] = { type: type, api: Array(api), block: block }
    end
  end

  #   docker run [OPTIONS] IMAGE COMMAND
  cli_option :command do |config, command|
    command = Shellwords.split(command) if command.is_a?(String)
    config["Cmd"] = command
  end

  #   docker run [OPTIONS] IMAGE COMMAND
  cli_option :image,                api: "Image"

  #   -a, --attach=[]               Attach to STDIN, STDOUT or STDERR
  cli_option :attach, Array, aliases: :a do |config,value|
    Array(value).each do |stream|
      # STDIN -> Stdin
      stream = stream.to_s.downcase.capitalize
      config["Attach#{stream}"] = true
    end
  end
  #   --add-host=[]                 Add a custom host-to-IP mapping (host:ip)
  cli_option :add_host, Array,      api: "HostConfig/ExtraHosts", aliases: :add_hosts
  #   --blkio-weight=0              Block IO weight (relative weight)
  cli_option :blkio_weight,         api: "HostConfig/BlkioWeight"
  #   --blkio-weight-device=[]      Block IO weight (relative device weight, format: `DEVICE_NAME:WEIGHT`)
  cli_option :blkio_weight, Array,  api: "HostConfig/BlkioWeightDevice", aliases: :blkio_weights
  #   --cap-add=[]                  Add Linux capabilities
  cli_option :cap_add, Array,       api: "HostConfig/CapAdd"
  #   --cap-drop=[]                 Drop Linux capabilities
  cli_option :cap_drop, Array,      api: "HostConfig/CapDrop"
  #   --cgroup-parent=""            Optional parent cgroup for the container
  cli_option :cgroup_parent,        api: "HostConfig/CgroupParent"
  #   --cidfile=""                  Write the container ID to the file
  cli_option :cidfile,              api: "HostConfig/ContainerIDFile"
  #   --cpu-period=0                Limit CPU CFS (Completely Fair Scheduler) period
  cli_option :cpu_period,           api: "HostConfig/CpuShares"
  #   --cpu-quota=0                 Limit CPU CFS (Completely Fair Scheduler) quota
  cli_option :cpu_quota,            api: "HostConfig/CpuQuota"
  #   --cpu-shares=0                CPU shares (relative weight)
  cli_option :cpu_period,           api: "HostConfig/CpuPeriod"
  #   --cpuset-cpus=""              CPUs in which to allow execution (0-3, 0,1)
  cli_option :cpuset_cpus,          api: "HostConfig/CpusetCpus"
  #   --cpuset-mems=""              Memory nodes (MEMs) in which to allow execution (0-3, 0,1)
  cli_option :cpuset_mems,          api: "HostConfig/CpusetMems"
  #   --device=[]                   Add a host device to the container
  cli_option :device, "PathOnHost:PathInContainer", api: "HostConfig/Devices", aliases: :devices
  #   --device-read-bps=[]          Limit read rate (bytes per second) from a device (e.g., --device-read-bps=/dev/sda:1mb)
  cli_option :device_read_bps, "Path:Rate", api: "HostConfig/BlkioDeviceReadBps"
  #   --device-read-iops=[]         Limit read rate (IO per second) from a device (e.g., --device-read-iops=/dev/sda:1000)
  cli_option :device_read_iops, "Path:Rate", api: "HostConfig/BlkioDeviceReadIOps"
  #   --device-write-bps=[]         Limit write rate (bytes per second) to a device (e.g., --device-write-bps=/dev/sda:1mb)
  cli_option :device_write_bps, "Path:Rate", api: "HostConfig/BlkioDeviceWriteBps"
  #   --device-write-iops=[]        Limit write rate (IO per second) to a device (e.g., --device-write-bps=/dev/sda:1000)
  cli_option :device_write_iops, "Path:Rate", api: "HostConfig/BlkioDeviceWriteIOps"
  #   --dns=[]                      Set custom DNS servers
  cli_option :dns, Array,          api: "HostConfig/Dns"
  #   --dns-opt=[]                  Set custom DNS options
  cli_option :dns_opt, Array,      api: "HostConfig/DnsOptions", aliases: :dns_opts
  #   --dns-search=[]               Set custom DNS search domains
  cli_option :dns_search, Array,   api: "HostConfig/DnsSearch"
  #   --entrypoint=""               Overwrite the default ENTRYPOINT of the image
  cli_option :entrypoint do |config, command|
    command = Shellwords.split(command) if command.is_a?(String)
    config["Entrypoint"] = command
  end
  #   -e, --env=[]                  Set environment variables
  cli_option :env,                 aliases: :e do |config, env|
    if env.is_a?(Hash)
      env = env.map { |k,v| "#{k}=#{v}" }
    end
    config["Env"] ||= []
    config["Env"] += Array(env)
  end
  #   --expose=[]                   Expose a port or a range of ports
  cli_option :expose do |config, value|
    config["ExposedPorts"] ||= {}
    Array(value).each do |port|
      parse_port(port).each do |host_ip, host_port, container_port|
        config["ExposedPorts"][container_port] = {}
      end
    end
  end
  #   --group-add=[]                Add additional groups to run as
  cli_option :group_add, Array,    api: 'HostConfig/GroupAdd'
  #   -h, --hostname=""             Container host name
  cli_option :hostname,            api: 'HostConfig/Hostname', aliases: :h
  #   -i, --interactive             Keep STDIN open even if not attached
  cli_option :interactive, :boolean, api: [ 'OpenStdin', 'AttachStdin' ]
  #   --ip=""                       Container IPv4 address (e.g. 172.30.100.104)
  cli_option :ip do |config, value|
    # Where this goes depends on the network! TODO doesn't work with `--net`
    config["NetworkSettings"] ||= {}
    network = config["NetworkMode"] || "default"
    config["NetworkSettings"][network] ||= {}
    config["NetworkSettings"][network]["IPAMConfig"] ||= {}
    config["NetworkSettings"][network]["IPAMConfig"]["IPv4Address"] = value
  end
  #   --ip6=""                      Container IPv6 address (e.g. 2001:db8::33)
  cli_option :ip6 do |config, value|
    # Where this goes depends on the network! TODO doesn't work with `--net`
    config["NetworkSettings"] ||= {}
    network = config["NetworkMode"] || "default"
    config["NetworkSettings"][network] ||= {}
    config["NetworkSettings"][network]["IPAMConfig"] ||= {}
    config["NetworkSettings"][network]["IPAMConfig"]["IPv6Address"] = value
  end
  #   --ipc=""                      IPC namespace to use
  cli_option :ipc,                 api: 'HostConfig/IpcMode' do |config, value|
    # TODO this should ONLY be set if security-opt isn't set at all.
    config["HostConfig"]["SecurityOpt"] ||= [ "label:disable" ]
  end
  #   --isolation=""                Container isolation technology
  cli_option :isolation,           api: 'Isolation'
  #   --kernel-memory=""            Kernel memory limit
  cli_option :kernel_memory, Integer, api: 'KernelMemory'
  #   -l, --label=[]                Set metadata on the container (e.g., --label=com.example.key=value)
  cli_option :label, Array,        api: "Labels", aliases: [ :l, :labels ]
  #   --link=[]                     Add link to another container
  cli_option :link, Array,         api: "HostConfig/Links", aliases: :links
  #   --log-driver=""               Logging driver for container
  cli_option :log_driver,          api: "HostConfig/LogConfig/Type"
  #   --log-opt=[]                  Log driver specific options
  cli_option :log_opt, aliases: :log_opts do |config, value|
    config["HostConfig"] ||= {}
    config["HostConfig"]["LogConfig"] ||= {}
    config["HostConfig"]["LogConfig"]["Type"] ||= {}
    Array(value).each do |keyval|
      k,v = keyval.split("=", 2)
      config["HostConfig"]["LogConfig"][k] = v
    end
  end
  #   --mac-address=""              Container MAC address (e.g. 92:d0:c6:0a:29:33)
  cli_option :mac_address,         api: "MacAddress"
  #   -m, --memory=""               Memory limit
  cli_option :memory, Integer,     api: "HostConfig/Memory", aliases: :m
  #   --memory-reservation=""       Memory soft limit
  cli_option :memory_reservation, Integer,     api: "HostConfig/MemoryReservation"
  #   --memory-swap=""              A positive integer equal to memory plus swap. Specify -1 to enable unlimited swap.
  cli_option :memory_swap, Integer, api: "HostConfig/MemorySwap"
  #   --memory-swappiness=""        Tune a container's memory swappiness behavior. Accepts an integer between 0 and 100.
  cli_option :memory_swappiness, Integer, api: "HostConfig/MemorySwappiness"
  #   --net="bridge"                Connect a container to a network
  #                                 'bridge': create a network stack on the default Docker bridge
  #                                 'none': no networking
  #                                 'container:<name|id>': reuse another container's network stack
  #                                 'host': use the Docker host network stack
  #                                 '<network-name>|<network-id>': connect to a user-defined network
  cli_option :net do |config, value|
    value = value.to_s
    old_network = config["NetworkMode"] || "default"
    config["NetworkMode"] = value
    # If we already stored stuff in the default network, move it to the new network
    if config["NetworkSettings"] && config["NetworkSettings"][old_network]
      config["NetworkSettings"][value] = config["NetworkSettings"].delete(old_network)
    end
  end
  #   --net-alias=[]                Add network-scoped alias for the container
  cli_option :net_alias, aliases: :net_aliases do |config, value|
    # Where this goes depends on the network! TODO doesn't work with `--net`
    config["NetworkSettings"] ||= {}
    network = config["NetworkMode"] || "default"
    config["NetworkSettings"][network] ||= {}
    config["NetworkSettings"][network]["Aliases"] ||= []
    config["NetworkSettings"][network]["Aliases"] += Array(value)
  end
  #   --oom-kill-disable            Whether to disable OOM Killer for the container or not
  cli_option :oom_kill_disable, :boolean, api: "HostConfig/OomKillDisable"
  #   --oom-score-adj=0             Tune the host's OOM preferences for containers (accepts -1000 to 1000)
  cli_option :oom_score_adj, Integer, api: "HostConfig/OomScoreAdj"
  #   --pid=""                      PID namespace to use
  cli_option :pid, api: "HostConfig/PidMode" do |config, value|
    # TODO this should ONLY be set if security-opt isn't set at all.
    config["HostConfig"]["SecurityOpt"] ||= [ "label:disable" ]
  end
  #   --privileged                  Give extended privileges to this container
  cli_option :privileged, :boolean, api: "HostConfig/Privileged"
  #   -p, --publish=[]              Publish a container's port(s) to the host
  cli_option :publish, aliases: [ :p, :ports ] do |config, value|
    config["HostConfig"] ||= {}
    config["HostConfig"]["PortBindings"] ||= {}
    config["ExposedPorts"] ||= {}

    Array(value).each do |port|
      parse_port(port).each do |host_ip, host_port, container_port|
        config["HostConfig"]["PortBindings"][container_port] ||= []
        config["HostConfig"]["PortBindings"][container_port] << { "HostIp" => host_ip, "HostPort" => host_port }
        config["ExposedPorts"][container_port] = {}
      end
    end
  end
  #   -P, --publish-all             Publish all exposed ports to random ports
  cli_option :publish_all, :boolean, api: "HostConfig/PublishAllPorts", aliases: :P
  #   --read-only                   Mount the container's root filesystem as read only
  cli_option :read_only, :boolean, api: "HostConfig/ReadonlyRootfs"
  #   --restart="no"                Restart policy (no, on-failure[:max-retry], always, unless-stopped)
  cli_option :restart do |config, value|
    name, retries = value.split(':')
    config["HostConfig"] ||= {}
    config["HostConfig"]["RestartPolicy"] ||= {}
    config["HostConfig"]["RestartPolicy"]["Name"] = name
    if retries
      config["HostConfig"]["RestartPolicy"]["MaximumRetryCount"] = retries
    else
      config["HostConfig"]["RestartPolicy"].delete("MaximumRetryCount")
    end
  end
  #   --rm                          Automatically remove the container when it exits
  cli_option :rm, :boolean,        api: "HostConfig/AutoRemove"
  #   --shm-size=[]                 Size of `/dev/shm`. The format is `<number><unit>`. `number` must be greater than `0`.  Unit is optional and can be `b` (bytes), `k` (kilobytes), `m` (megabytes), or `g` (gigabytes). If you omit the unit, the system uses bytes. If you omit the size entirely, the system uses `64m`.
  cli_option :shm_size, Integer,   api: "HostConfig/ShmSize", aliases: :shm_sizes
  #   --security-opt=[]             Security Options
  cli_option :security_opt, Array, api: "HostConfig/SecurityOpt", aliases: :security_opts
  #   --stop-signal="SIGTERM"       Signal to stop a container
  cli_option :stop_signal,         api: "StopSignal"
  #   -t, --tty                     Allocate a pseudo-TTY
  cli_option :tty, :boolean,       api: "Tty", aliases: :tty
  #   -u, --user=""                 Username or UID (format: <name|uid>[:<group|gid>])
  cli_option :user,                api: "User", aliases: :u
  #   --ulimit=[]                   Ulimit options
  cli_option :ulimit, aliases: :ulimits do |config, value|
    config["HostConfig"] ||= {}
    config["HostConfig"]["Ulimits"] ||= []
    value.each do |ulimit|
      type, values = ulimit.split("=", 2)
      soft, hard = values.split(":", 2)
      config["HostConfig"]["Ulimits"] << { "Name" => type, "Soft" => soft, "Hard" => hard }
    end
  end
  #   --uts=""                      UTS namespace to use
  cli_option :uts,                 api: "HostConfig/UTSMode"
  #   -v, --volume=[host-src:]container-dest[:<options>]
  #                                 Bind mount a volume. The comma-delimited
  #                                 `options` are [rw|ro], [z|Z], or
  #                                 [[r]shared|[r]slave|[r]private]. The
  #                                 'host-src' is an absolute path or a name
  #                                 value.
  cli_option :volume, aliases: [ :v, :volumes ] do |config, value|
    # Things without : in them at all, are just volumes.
    binds, volumes = Array(value).partition { |v| v.include?(':') }
    config["HostConfig"] ||= {}
    unless binds.empty?
      config["HostConfig"]["Binds"] ||= []
      config["HostConfig"]["Binds"] += binds
    end
    unless volumes.empty?
      config["Volumes"] ||= []
      config["Volumes"] += volumes
    end
  end
  #   --volume-driver=""            Container's volume driver
  cli_option :volume_driver,       api: "HostConfig/VolumeDriver"
  #   -w, --workdir=""              Working directory inside the container
  cli_option :workdir,             api: "WorkingDir", aliases: :w
  #   --volumes-from=[]             Mount volumes from the specified container(s)
  cli_option :volumes_from, Array, api: 'HostConfig/VolumesFrom'

  # Not relevant to API or Chef:
  #   -d, --detach                  Run container in background and print container ID
  #   --detach-keys                 Specify the escape key sequence used to detach a container
  #   --disable-content-trust=true  Skip image verification
  #   --env-file=[]                 Read in a file of environment variables
  #   --help                        Print usage
  #   --label-file=[]               Read in a file of labels (EOL delimited)
  #   --name=""                     Assign a name to the container
  #   --sig-proxy=true              Proxy received signals to the process

  private

  # Lifted from docker cookbook
  def self.parse_port(v)
    parts = v.to_s.split(':')
    case parts.length
    when 3
      host_ip = parts[0]
      host_port = parts[1]
      container_port = parts[2]
    when 2
      host_ip = '0.0.0.0'
      host_port = parts[0]
      container_port = parts[1]
    when 1
      host_ip = ''
      host_port = ''
      container_port = parts[0]
    end
    port_range, protocol = container_port.split('/')
    if port_range.include?('-')
      port_range = container_port.split('-')
      port_range.map!(&:to_i)
      Chef::Log.fatal("FATAL: Invalid port range! #{container_port}") if port_range[0] > port_range[1]
      port_range = (port_range[0]..port_range[1]).to_a
    end
    # qualify the port-binding protocol even when it is implicitly tcp #427.
    protocol = 'tcp' if protocol.nil?
    Array(port_range).map do |port|
      [ host_ip, host_port, "#{port}/#{protocol}"]
    end
  end

  def self.parse_int(value)
    value = value.upcase
    if value.end_with?("TB") || value.end_with?("T")
      value.to_i * 1024*1024*1024*1024
    elsif value.end_with?("GB") || value.end_with?("G")
      value.to_i * 1024*1024*1024
    elsif value.end_with?("MB") || value.end_with?("M")
      value.to_i * 1024*1024
    elsif value.end_with?("KB") || value.end_with?("K")
      value.to_i * 1024
    else
      value.to_i
    end
  end

end
end
end
end
