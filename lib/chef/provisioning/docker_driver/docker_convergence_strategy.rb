class Chef
  module Provisioning
    module DockerDriver
      class DockerConvergenceStrategy < Chef::Provisioning::ConvergenceStrategy::Preinstalled
        def initialize(connection, create_options, convergence_options, config)
          @create_options = create_options
          super(convergence_options, config)
        end

        attr_reader :create_options
        attr_reader :connection
        def container_name
          create_options['name']
        end

        def host_chef_mount
          convergence_options[:host_chef_mount] || '/opt/chef'
        end
        def container_tmp_dir
          File.join(convergence_options[:tmpdir] || "/tmp", "container_chef_config", container_name
        end
        def container_config_dir
          File.join(container_tmp_dir, 'chef_config')
        end
        def client_rb_path
          File.join(container_config_dir, 'client.rb')
        end
        def client_pem_path
          File.join(container_config_dir, 'client.pem')
        end
        def container_cache_dir
          File.join(container_tmp_dir, 'chef_cache')
        end

        def setup_convergence(action_handler, machine)
        end

        def converge(action_handler, machine)
          image = converge_image(action_handler, machine)
          converge_container(action_handler, machine, image)
        end

        def create_container(action_handler, override_image=nil)
          # If there were changes and we now have a new image to base off of, Delete the existing container so we can start it fresh from the new image
          if override_image
            delete_container(action_handler)
          else
            container = Docker::Container.get(container_name, {}, connection)
          end

          # Create the container if it doesn't exist
          if !container
            create_options = self.create_options
            if override_image
              create_options = create_options.merge('Image' => override_image)
            end
            converge_by "create container #{container_name}" do
              container = Docker::Container.create(create_options, connection)
            end
          else
            # TODO compare existing container's properties with desired create_options
          end

          container
        end

        def docker_options_for(machine_options)
          docker_options = (machine_options[:docker_options] || {}).dup
          docker_options[:base_image] ||= {}
          docker_options
        end

        def build_container(machine_spec, machine_options)

          docker_options = docker_options_for(machine_options)

          base_image = docker_options[:base_image]
          source_name = base_image[:name]
          source_repository = base_image[:repository]
          source_tag = base_image[:tag]

          # Don't do this if we're loading from an image
          if docker_options[:from_image]
            "#{source_repository}:#{source_tag}"
          else
            target_repository = 'chef'
            target_tag = machine_spec.name

            image = find_image(target_repository, target_tag)

            # kick off image creation
            if image == nil
              Chef::Log.debug("No matching images for #{target_repository}:#{target_tag}, creating!")
              if !source_name && !source_repository && !source_tag
                raise "Must specify `from_image` or `machine_options: { base_image: { name: 'imagename', repository: 'repository', tag: 'tag' } }`"
              end
              image = Docker::Image.create({ 'fromImage' => source_name,
                                             'repo' => source_repository ,
                                             'tag' => source_tag },
                                             credentials, connection)
              Chef::Log.debug("Allocated #{image}")
              image.tag('repo' => 'chef', 'tag' => target_tag)
              Chef::Log.debug("Tagged image #{image}")
            end

            "#{target_repository}:#{target_tag}"
          end
        end


        def start_container(action_handler, container=get_container)
          # Start the container if it's not started
          if container.info['State']['Running']
            # TODO compare existing container's properties with desired start_options
          else
            converge_by "start container #{container_name}" do
              container.start
            end
          end
        end

        def stop_container(action_handler, container=get_container)
          # Stop the container if it's not stopped
          if container.info['State']['Running']
            converge_by "stop container #{container_name}" do
              container.stop
            end
          end
        end

        def delete_container(action_handler)
          if get_container
            converge_by "delete container #{container_name}" do
              begin
                Docker::Container.new({ 'id': container_name }).delete!(force: true)
              rescue Docker::Error::NotFoundError
              end
            end
          end
        end

        def get_container
          begin
            Docker::Container.get(container_name, {}, connection)
          rescue Docker::Error::NotFoundError
          end
        end

        protected



        def converge_container(action_handler, machine, image)
          container = create_container(action_handler, image)
          start_container(action_handler, container)
        end

        def converge_image(action_handler, machine)
          private_key, public_key = configure_chef(action_handler, machine)

          config_create_options = create_options.dup
          config_create_options.delete('name')
          config_create_options['Volumes'] ||= {}
          config_create_options['Volumes']['/opt/chef'] = host_chef_mount
          config_create_options['Cmd'] = 'while 1; sleep 10; end'
          config_container = Docker::Container.create(create_options, connections)

          begin
            transport = DockerTransport.new(config, config_container.id, base_image_name, credentials, connection)

            # Support for multiple ohai hints, required on some platforms
            create_ohai_files(action_handler, transport)

            # Create client.rb and client.pem on machine
            content = client_rb_content(chef_server[:chef_server_url], machine.node['name'])
            transport.write_file(action_handler, client_rb_path, content, :ensure_dir => true)

            if run_chef(action_handler, transport)
              return config_container.commit
            end
          ensure
            config_container.delete(force: true)
          end
          nil
        end

        def configure_chef(action_handler, machine)
          private_key = nil
          Chef::Provisioning.inline_resource(action_handler) do
            private_key 'in_memory' do
              path :none
              private_key_options.each { |key, value| send(key, value) }
              after { |resource, key| private_key = key }
            end
          end

          # Create node and client on chef server
          create_chef_objects(action_handler, machine, private_key, private_key.public_key)

          [ private_key, private_key.public_key ]
        end

        def run_chef(action_handler, machine, transport)
          action_handler.open_stream(machine.node['name']) do |stdout|
            action_handler.open_stream(machine.node['name']) do |stderr|
              command_line = chef_client_path
              command_line << " -l #{config[:log_level].to_s}" if config[:log_level]
              command_line << " -c \"#{client_rb_path}\""
              transport.execute(command_line,
                :stream_stdout => stdout,
                :stream_stderr => stderr,
                :timeout => @chef_client_timeout)
            end
          end
        end
      end
    end
  end
end
