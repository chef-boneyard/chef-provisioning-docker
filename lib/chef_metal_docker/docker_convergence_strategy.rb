require 'chef_metal/convergence_strategy'
require 'docker'

module ChefMetalDocker
  class DockerConvergenceStrategy < ChefMetal::ConvergenceStrategy
    def initialize(real_convergence_strategy, repository_name, container_name, container_configuration, host_configuration, credentials, connection)
      @real_convergence_strategy = real_convergence_strategy
      @repository_name = repository_name
      @container_name = container_name
      @container_configuration = container_configuration
      @host_configuration = host_configuration
      @credentials = credentials
      @connection = connection
    end

    attr_reader :real_convergence_strategy
    attr_reader :container_name
    attr_reader :repository_name
    attr_reader :container_configuration
    attr_reader :host_configuration
    attr_reader :credentials
    attr_reader :connection

    def setup_convergence(action_handler, machine, machine_resource)
      real_convergence_strategy.setup_convergence(action_handler, machine, machine_resource)
    end

    def converge(action_handler, machine)
      real_convergence_strategy.converge(action_handler, machine)

      # After converge, we bring up the container command
      if container_configuration
        action_handler.perform_action "Start container command"
        begin
          connection.delete("/containers/#{container_name}")
        rescue Docker::Error::NotFoundError
        end
        container = Docker::Container.create({
          'name' => container_name,
          'Image' => "#{repository_name}:latest"
        }.merge(container_configuration), connection)
        container.start!(host_configuration)
        # We don't bother waiting ... our only job is to bring it up.
      end
    end

    def cleanup_convergence(action_handler, node)
      real_convergence_strategy.cleanup_convergence(action_handler, node)
    end
  end
end
