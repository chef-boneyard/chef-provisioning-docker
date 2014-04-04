module ChefMetalDocker
  module Helpers
    module Container
      # These are helper functions that the Chef::Provider::DockerContainer class
      # will use to to help execute commands and analyze the current system
      module Helpers

        def cidfile
          if service?
            new_resource.cidfile || "/var/run/#{service_name}.cid"
          else
            new_resource.cidfile
          end
        end

        def container_command_matches_if_exists?(command)
          return true if new_resource.command.nil?
          # try the exact command but also the command with the ' and " stripped out, since docker will
          # sometimes strip out quotes.
          subcommand = new_resource.command.gsub(/['"]/, '')
          command.include?(new_resource.command) || command.include?(subcommand)
        end

        def container_id_matches?(id)
          if new_resource.id == nil
            false
          else 
            id.start_with?(new_resource.id)
          end 
        end

        def container_image_matches?(image)
          if new_resource.image == nil
            false
          else
            image.include?(new_resource.image)
          end
        end

        def container_name_matches_if_exists?(names)
          return false if new_resource.container_name && new_resource.container_name != names
          true
        end

        def container_name
          if service?
            new_resource.container_name || new_resource.image.gsub(/^.*\//, '')
          else
            new_resource.container_name
          end
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

        def command_timeout_error_message(cmd)
          <<-EOM

  Command timed out:
  #{cmd}

  Please adjust node container_cmd_timeout attribute or this docker_container cmd_timeout attribute if necessary.
  EOM
        end

        def exists?
          @current_resource.id
        end

        def port
          # DEPRECATED support for public_port attribute and Fixnum port
          if new_resource.public_port && new_resource.port.is_a?(Fixnum)
            "#{new_resource.public_port}:#{new_resource.port}"
          elsif new_resource.port && new_resource.port.is_a?(Fixnum)
            ":#{new_resource.port}"
          else
            new_resource.port
          end
        end

        def running?
          @current_resource.status.include?('Up') if @current_resource.status
        end

        def service?
          new_resource.init_type
        end

        def service_name
          container_name
        end

        def sockets
          return [] if port.empty?
          [*port].map { |p| p.gsub!(/.*:/, '') }
        end
      end
    end
  end
end
