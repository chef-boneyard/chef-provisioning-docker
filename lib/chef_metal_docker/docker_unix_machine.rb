require 'chef_metal/machine/unix_machine'

module ChefMetalDocker
  class DockerUnixMachine < ChefMetal::Machine::UnixMachine
    def execute_always(command)
      transport.execute_nocommit(command, false)
    end
  end
end
