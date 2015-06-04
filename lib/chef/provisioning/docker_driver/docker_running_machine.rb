require 'chef/provisioning/machine/unix_machine'

class Chef
module Provisioning
module DockerDriver
  class DockerRunningMachine < Chef::Provisioning::Machine::UnixMachine

    def initialize(machine_spec, transport, convergence_strategy, keep_stdin_open)
      super(machine_spec, transport, convergence_strategy)
      @keep_stdin_open = keep_stdin_open
      @container_name = machine_spec.location['container_name']
      @transport = transport
    end

    def converge(action_handler)
      super action_handler
      if @command
        Chef::Log.debug("DockerContainerMachine converge complete, executing #{@command} in #{@container_name}")
      end
    end
  end
end
end
end
