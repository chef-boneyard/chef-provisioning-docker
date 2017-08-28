directory "/var/run/sshd"

user "vagrant" do
  action :create
  supports manage_home: true
  home "/home/vagrant"
  shell "/bin/bash"
end

bash "create password" do
  code <<-EOS
    usermod -p "`openssl passwd -1 'vagrant'`" vagrant
  EOS
end

bash "add vagrant to sudoers" do
  user "root"
  cwd "/tmp"
  code <<-EOH
     echo 'vagrant ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
  EOH
end
