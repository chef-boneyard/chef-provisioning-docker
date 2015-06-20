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
  let(:container) { Docker::Container.get(name) }
  let(:image) { Docker::Image.get("chef:#{name}") }

  describe 'ssh1' do
    let(:name) { 'ssh1' }

    it 'has a running container' do
      expect(container.info['State']['Running']).to be true
    end
    it 'has an image' do
      expect(image.id).to_not be nil
    end    
  end

  describe 'ssh2' do
    let(:name) { 'ssh2' }

    it 'has no container' do
      expect{container}.to raise_error(Docker::Error::NotFoundError)
    end
    it 'has no image' do
      expect{image}.to raise_error(Docker::Error::NotFoundError)
    end    
  end

  describe 'ssh3' do
    let(:name) { 'ssh3' }

    it 'has a running container' do
      expect(container.info['State']['Running']).to be true
    end
    it 'has an image' do
      expect(image.id).to_not be nil
    end    
  end

  describe 'ssh port' do
    let(:container) { Docker::Container.get('ssh1') }
    let(:ip) { container.info['NetworkSettings']['IPAddress']}
    let(:file) { Net::SSH.start(ip, 'vagrant', password: 'vagrant').exec!('sudo cat /etc/chef/client.rb') }

    it 'returns chef client file' do
      expect(file).to include 'ssh1'
    end
  end
end
