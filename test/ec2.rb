require "chef/provisioning/fog"

ec2testdir = File.expand_path("./ec2creds")

directory ec2testdir

with_fog_ec2_provisioner

fog_key_pair "me" do
  private_key_path "#{ec2testdir}/me"
  public_key_path "#{ec2testdir}/me.pub"
end
