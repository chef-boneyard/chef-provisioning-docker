require 'chef/provisioning/docker_/docker_transport'

transport = Chef::Provisioning::Docker::DockerTransport.new('blarghle', 'blarghle', nil, Docker.connection)
#transport.write_file('/tmp/blah.txt', 'hi there again')
#puts transport.execute('ls -d /etc/chef', false)
#transport.download_file('/tmp/chef_11.10.4-1.ubuntu.12.04_amd64.deb', '/tmp/b.deb')
#transport.upload_file('/tmp/x.txt', '/tmp/b.txt')
#puts transport.read_file('/tmp/b.txt')
#puts ARGV.inspect
new_url = transport.make_url_available('http://127.0.0.1:8456/blah.html')
uri = URI(new_url)
puts uri
#result = transport.execute("/opt/chef/embedded/bin/ruby -e ''", false)
result = transport.execute(ARGV, false)
puts result.stdout
puts result.stderr
exit(result.exitstatus)
