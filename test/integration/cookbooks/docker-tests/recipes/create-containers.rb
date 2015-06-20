machine 'ssh1' do
  recipe 'openssh::default'
  recipe 'docker-tests::create-user'
  machine_options :docker_options => {
    :base_image => {
        :name => 'ubuntu',
        :repository => 'ubuntu',
        :tag => '14.04'
    },
    :command => '/usr/sbin/sshd -D -o UsePAM=no -o UsePrivilegeSeparation=no -o PidFile=/tmp/sshd.pid',
    :ports => [22],
  }
end

machine_image 'ssh' do
  recipe 'openssh::default'
  recipe 'docker-tests::create-user'
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
      :command => '/usr/sbin/sshd -D -o UsePAM=no -o UsePrivilegeSeparation=no -o PidFile=/tmp/sshd.pid',
      :ports => [22],
    }
  end

  machine 'ssh3' do
    from_image 'ssh'
    machine_options :docker_options => {
      :command => '/usr/sbin/sshd -D -o UsePAM=no -o UsePrivilegeSeparation=no -o PidFile=/tmp/sshd.pid',
      :ports => [22],
    }
  end  
end