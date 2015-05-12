# Changelog
## 0.6 (5/12/2015)

- Fix issue #38 (issue transferring data over local mode proxy) (@shaneramey)
- Add volumes support (@marc-)

## 0.5.2 (2/25/2015)

- Fix Docker driver on IPv6 containers

## 0.5.1 (12/15/2014)

- Fix for more recent Docker API library
- Support ENV variables in the options hash

## 0.5 (10/6/2014)

- rename to chef-provisioning-docker

## 0.4.3 (10/6/2014)

* Disable event output stream live stream if the support for it isn't there
* Support multiple port mappings for containers
* Removed em_proxy dependency 
* Support keeping STDIN open in containers for things that need it (like node)

## 0.4.2 (9/23/2014)

- Bug fixes
- Run final command in detached mode
- Removed DockerContainer so that it didn't conflict with the docker cookbook
- Properly use URLs in  key


## 0.3 (8/19/2014)

- Rewritten to support the new  API
- Supports remote API endpoints as well as local 
- Replaced EMProxy with a plain HTTP proxy 
- Supports machine images

## 0.2 (4/13/2014)

- Add container-create-only mode to provisioner

## 0.1.1 (4/11/2014)

- Increase stability of transport.execute()
- Add port forwarding (not presently working, but hopefully close)

## 0.1 (4/11/2014)

- Initial revision.  Use at own risk :)
