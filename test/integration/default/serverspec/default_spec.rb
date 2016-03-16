require 'serverspec'
require 'docker'

set :backend, :exec

describe file('/tmp/kitchen/nodes/ssh1.json') do
  it { should be_file }
end

describe file('/tmp/kitchen/nodes/ssh2.json') do
  it { should_not be_file }
end

describe file('/tmp/kitchen/nodes/ssh3.json') do
  it { should be_file }
end

describe 'containers and images' do
  it 'ssh1 is a running container' do
    container = Docker::Container.get('ssh1')
    expect(container.info['State']['Running']).to be true
  end

  it 'ssh2 has no container' do
    expect { Docker::Container.get('ssh2') }.to raise_error(Docker::Error::NotFoundError)
  end

  it 'ssh3 is a stopped container' do
    container = Docker::Container.get('ssh3')
    expect(container.info['State']['Running']).to be false
  end

  it 'ssh is an image' do
    expect { Docker::Image.get('ssh') }.not_to raise_error
  end

  it 'ssh1 has ssh port open and can cat chef client file' do
    container = Docker::Container.get('ssh1')
    ip = container.info['NetworkSettings']['IPAddress']
    connection = container.info['NetworkSettings']['IPAddress']
    file = Net::SSH.start(ip, 'vagrant', password: 'vagrant').exec!('sudo cat /etc/chef/client.rb')
    expect(file).to include 'ssh1'
  end
end
