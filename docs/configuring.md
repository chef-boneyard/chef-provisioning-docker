# Chef Provisioning Docker Driver

## Setting the driver

Two basic URLs are supported:

## Driver options

Several modifications can be made to a driver's configuration.  These options can be set in Chef::Config (`knife.rb` or `client.rb`) and include:

- **`:excon_options`**: a hash of options that will be passed to `Docker::Connection.new()`
  and ultimately to Excon.  Documentation on these options can be found at Excon
  in general form [in the README](https://github.com/excon/excon#options) as well
  as with many more specifics [in the rubydocs](http://www.rubydoc.info/github/excon/excon/Excon/Connection#initialize-instance_method).
- **`:docker_credentials`**: Your credentials to the Docker image registry.  Documentation
  on [docker-api](http://www.rubydoc.info/github/swipely/docker-api/Docker.creds=) as of the time of this writing, but code inspection shows it is a Hash of the form `{'username' => <your username>, 'password' => <your password>, 'email' => <your email>, 'serveraddress' => <registry server address> }`.  Not all values need be supplied.  Not sure which actually *do*; if you get the right values to send, let me know!
