Docker has been steadily gaining momentum for it agility, simplecity and performance. Docker containers run like traditional processs but with resource isolation. It comes with native lightweight API for high level operations complemnting Docker CLIs. Integrating Docker with OpenStack allow Containers to ve deployed and managed jusy like VMs, with all relative mature orachstration layer(i.e. Heat, Murano), centerlized management (i.e. Horizon, Nova) and functional services (i.e. Keystone, SDN and tec).

Since Havana, Glance supports docker image format. Docker images can be imported into Glance just like VM images.

    In /etc/glance/glance.conf, update cpntainer_formats by adding docker as one of the supported formats.
    
    [image_format]
    container_formats=ami,ari,aki,bare,ovf,ova,docker
    
    From Docker, save the Docker image to a file
    # docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    wdc7                latest              e1adc7a45de7        4 weeks ago         344.6 MB

    # docker save <docker_image_name> /tmp/<docker_image_file>.tar
    # docker save wdc7 > /tmp/wdc7.tar
    
    Import the saved docker image file to Glance
    # glance image-create -is-public=True --container-format=docker --disk-format=raw --name <glance_image_name> --file <docker_iame_file>.tar
    
    Display the Glance images
    # openstack image list
    +--------------------------------------+----------+
    | ID                                   | Name     |
    +--------------------------------------+----------+
    | b4ca9864-9ceb-4b42-9c82-620f0e2fd60d | dockerc7 |
    | 4a064b38-caae-4cf8-9396-e02a85b368f5 | cirros   |
    +--------------------------------------+----------+
    [root@ctrail72 glance]# openstack image show dockerc7
    +------------------+--------------------------------------+
    | Field            | Value                                |
    +------------------+--------------------------------------+
    | checksum         | a0e4fe5648ef1f96d9e2494f8b2d4c89     |
    | container_format | docker                               |
    | created_at       | 2015-04-13T23:06:11.000000           |
    | deleted          | False                                |
    | deleted_at       | None                                 |
    | disk_format      | raw                                  |
    | id               | b4ca9864-9ceb-4b42-9c82-620f0e2fd60d |
    | is_public        | True                                 |
    | min_disk         | 0                                    |
    | min_ram          | 0                                    |
    | name             | dockerc7                             |
    | owner            | None                                 |
    | properties       | {}                                   |
    | protected        | False                                |
    | size             | 357081088                            |
    | status           | active                               |
    | updated_at       | 2015-04-13T23:06:12.000000           |
    | virtual_size     | None                                 |
    +------------------+--------------------------------------+
    

Nova-compute agent talks with Docker via linux socket or API. Nova-docker is a supported compute_driver type since Havana which allows Nova and Glance to interact with Docker. The nova-docker is s seperated component outside of OpenStack and users will need to get the source from https://github.com/stackforge/nova-docker#egg=novadocker, compile and install it on compute nodes. Up to Kilo release, a compute node must be designated as a Hypervisor node or a Docker container node. OpenStack does not support hybrid compute_driver on a single compute node up to Kilo release.  

    Update /etc/nova/nova.conf to specify comput_driver for the compute node. Openstack Kilo or earliuer code releases do not support hybrid mode. Only docker or KVM/XEN/QEMU is allowed for any given node.
    
    # cat /etc/nova/nova.conf
    [DEFAULT]
    ......
    compute_driver=novadocker.virt.docker.DockerDriver
    ......
    
    Install following RPMs on a OpenStack controller and compute nodes. 
    # rpm -qa | grep docker
    docker-1.5.0-1.el7.x86_64   <----- or newer
    nova-docker-0.0.0.post183-1.noarch  <---- or newer
    docker-py-1.1.0-1.noarch <--- or newer
    
    (More detail to be added)
    
    (Container networking with Contrail VRF)
    
    (Running containers with limited change rights without enabling privileged mode)
