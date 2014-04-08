require 'chef_metal/machine/unix_machine'

module ChefMetalDocker
  class DockerUnixMachine < ChefMetal::Machine::UnixMachine
    def execute_always(command, options = {})
      transport.execute(command, { :read_only => true }.merge(options))
    end
  end
end
