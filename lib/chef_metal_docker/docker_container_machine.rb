require 'chef_metal/machine/unix_machine'

module ChefMetalDocker
  class DockerContainerMachine < ChefMetal::Machine::UnixMachine

    # Expects a machine specification, a usable transport and convergence strategy
    # Options is expected to contain the optional keys
    #   :command => the final command to execute
    #   :ports => a list of port numbers to listen on
    def initialize(machine_spec, transport, convergence_strategy, opts = {})
      super(machine_spec, transport, convergence_strategy)
      @command = opts[:command]
      @ports = opts[:ports]
      @keep_stdin_open = opts[:keep_stdin_open]
      @container_name = machine_spec.location['container_name']
      @transport = transport
    end

    def execute_always(command, options = {})
      transport.execute(command, { :read_only => true }.merge(options))
    end

    def converge(action_handler)
      super action_handler
      if @command
        Chef::Log.debug("DockerContainerMachine converge complete, executing #{@command} in #{@container_name}")
        @transport.execute(@command, :detached => true, :read_only => true, :ports => @ports, :keep_stdin_open => @keep_stdin_open)
      end
    end

  end
end
