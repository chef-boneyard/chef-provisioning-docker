machine 'ssh1' do
  recipe 'docker-tests::create-user'
  recipe 'openssh::default'
  machine_options :docker_options => {
    :base_image => {
        :name => 'ubuntu',
        :repository => 'ubuntu',
        :tag => '14.04'
    },
    :command => '/usr/sbin/sshd -D -o UsePAM=no',
    :ports => [22],
  }
end

machine_image 'ssh' do
  recipe 'docker-tests::create-user'
  recipe 'openssh::default'
  machine_options :docker_options => {
    :base_image => {
        :name => 'ubuntu',
        :repository => 'ubuntu',
        :tag => '14.04'
    }
  }
end

machine_batch do
  machine 'ssh2' do
    from_image 'ssh'
    machine_options :docker_options => {
      :command => '/usr/sbin/sshd -D -o UsePAM=no',
      :ports => [22],
    }
  end

  machine 'ssh3' do
    from_image 'ssh'
    machine_options :docker_options => {
      :command => '/usr/sbin/sshd -D -o UsePAM=no',
      :ports => [22],
    }
  end  
end