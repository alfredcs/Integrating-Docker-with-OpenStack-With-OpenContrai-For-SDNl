# Integrating-Docker-with-OpenStack-With-OpenContrail-For-SDN
Describe architecture design and deployment method of integrating Docker with OpenStack and OpenContrail.  
Docker has been steadily gaining momentum for it agility, simplexity and performance. Docker containers run like traditional processs but with resource isolation. It comes with native lightweight API for high level operations complemnting Docker CLIs. Integrating Docker with OpenStack allow Containers to ve deployed and managed jusy like VMs, with all relative mature orachstration layer(i.e. Heat, Murano), centerlized management (i.e. Horizon, Nova) and functional services (i.e. Keystone, SDN and tec).

Since Havana, Glance supports docker image format. Docker images can be imported into Glance just like VM images.

    (Detail to be updated)
    

Nova-compute agent talks with Docker via linux socket or API. Nova-docker is a supported compute_driver type since Havana which allows Nova and Glance to interact with Docker. The nova-docker is s seperated component outside of OpenStack and users will need to get the source from https://github.com/stackforge/nova-docker#egg=novadocker, compile and install it on compute nodes. Up to Kilo release, a compute node must be designated as a Hypervisor node or a Docker container node. OpenStack does not support hybrid compute_driver on a single compute node up to Kilo release.  

    (Detail to be added)
