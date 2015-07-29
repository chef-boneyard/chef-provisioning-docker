require 'chef/provisioning/machine/unix_machine'

class Chef
module Provisioning
module DockerDriver
  class DockerContainerMachine < Chef::Provisioning::Machine::UnixMachine

    # Expects a machine specification, a usable transport and convergence strategy
    # Options is expected to contain the optional keys
    #   :command => the final command to execute
    #   :ports => a list of port numbers to listen on
    def initialize(machine_spec, transport, convergence_strategy, command = nil)
      super(machine_spec, transport, convergence_strategy)
      @command = command
      @transport = transport
    end

    def converge(action_handler)
      super action_handler
      Chef::Log.debug("DockerContainerMachine converge complete, executing #{@command} in #{@container_name}")
      image = transport.container.commit(
        'repo' => 'chef',
        'tag' => machine_spec.reference['container_name']
      )
      machine_spec.reference['image_id'] = image.id

      if @command && transport.container.info['Config']['Cmd'].join(' ') != @command
        transport.container.delete(:force => true)
        container = image.run(Shellwords.split(@command))
        container.rename(machine_spec.reference['container_name'])
        machine_spec.reference['container_id'] = container.id
        transport.container = container
      end
      machine_spec.save(action_handler)
    end
  end
end
end
end
