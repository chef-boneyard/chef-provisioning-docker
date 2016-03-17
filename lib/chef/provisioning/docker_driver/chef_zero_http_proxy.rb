require 'socket'
require 'uri'

class ChefZeroHttpProxy

  def initialize(local_address, local_port, remote_address, remote_port)
    @local_address = local_address
    @local_port = local_port
    @remote_address = remote_address
    @remote_port = remote_port
  end

  def run
    begin
      Chef::Log.debug("Running proxy main loop on #{@local_address}:#{@local_port}!")

      # Start our server to handle connections (will raise things on errors)
      @socket = TCPServer.new @local_address, @local_port

      # Handle every request in another thread
      loop do
        s = @socket.accept
        Thread.new s, &method(:handle_request)
      end

    ensure
      @socket.close if @socket
    end
  end

  def handle_request(to_client)
    begin
      request_line = to_client.readline

      verb = request_line[/^\w+/]
      url = request_line[/^\w+\s+(\S+)/, 1]
      version = request_line[/HTTP\/(1\.\d)\s*$/, 1]
      uri = URI::parse url

      # Show what got requested
      Chef::Log.debug("[C->S]: #{verb} ->  #{url}")

      querystr = if uri.query
                   "#{uri.path}?#{uri.query}"
                 else
                   uri.path
                 end

      to_server = TCPSocket.new(@remote_address, @remote_port)

      to_server.write("#{verb} #{querystr} HTTP/#{version}\r\n")

      content_len = 0

      loop do
        line = to_client.readline

        if line =~ /^Content-Length:\s+(\d+)\s*$/
          content_len = $1.to_i
        end

        # Strip proxy headers
        if line =~ /^proxy/i
          next
        elsif line.strip.empty?
          to_server.write("Connection: close\r\n\r\n")

          if content_len >= 0
            to_server.write(to_client.read(content_len))
            Chef::Log.debug("[C->S]: Wrote #{content_len} bytes")
          end

          break
        else
          to_server.write(line)
        end
      end

      buff = ''
      while to_server.read(8192, buff)
        to_client.write(buff)
      end

    rescue
      Chef::Log.error $!
      raise

    ensure
      # Close the sockets
      to_client.close
      to_server.close
    end
  end

end
