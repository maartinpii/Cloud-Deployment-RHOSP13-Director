#  Overcloud and Container Images

## Objectives

* Obtain overcloud images
* Upload the overcloud images to the undercloud node
* Prepare for the containerized overcloud deployment
* Upload container images to the local container registry
* Prepare a template for using the local container registry during the overcloud deployment


1. Obtain Overcloud Images

The Red Hat OpenStack Platform director requires several disk images for provisioning overcloud nodes:

|Required Overcloud Image	|Usage                                             |
|-------------------------|--------------------------------------------------|
|Introspection kernel     |Bare-metal system introspection over PXE boot     |
|Introspection ramdisk    |Bare-metal system introspection over PXE boot     |
|Deployment kernel        |System provisioning and deployment                |
|Deployment ramdisk       |System provisioning and deployment                |
|Overcloud kernel         |Base overcloud system written to node’s hard disk |
|Overcloud ramdisk        |Base overcloud system written to node’s hard disk |
|Overcloud full image     |Base overcloud system written to node’s hard disk |

These images are available from the rhosp-director-images and rhosp-director-images-ipa packages.

Note: For custom use cases, overcloud images can be built using diskimage-builder or other tools.

1.1 As the stack user on undercloud, create directories for the overcloud images, templates, and environment files:

```
(undercloud) [stack@undercloud ~]$ mkdir images
(undercloud) [stack@undercloud ~]$ mkdir -p templates/environments
```

1.2 Install software packages containing the overcloud and inspection images:

```
(undercloud) [stack@undercloud ~]$ sudo yum -y install rhosp-director-images
```

1.3 Extract the overcloud images to the images directory:

```
(undercloud) [stack@undercloud ~]$ tar -C images -xvf /usr/share/rhosp-director-images/overcloud-full.tar
```


1.4 Extract the images from the ironic-python-agent.tar archive to the images directory of the stack user’s home directory:

```
(undercloud) [stack@undercloud ~]$ tar -C images -xvf /usr/share/rhosp-director-images/ironic-python-agent.tar
```

1.5 Upload the images to the undercloud’s image repository:

```
(undercloud) [stack@undercloud ~]$ openstack overcloud image upload --image-path ~/images

```

2. Verify Upload of Overcloud Images

2.1 List the overcloud images to confirm that all five images uploaded successfully:

```
(undercloud) [stack@undercloud ~]$ openstack image list
```

Kind of Sample Ouput:

```
+--------------------------------------+------------------------+--------+
| ID                                   | Name                   | Status |
+--------------------------------------+------------------------+--------+
| ac09c978-50ea-4144-b2ee-a59c72806a41 | bm-deploy-kernel       | active |
| bc8a2a6f-0ae7-4628-a3c9-b091dc10673c | bm-deploy-ramdisk      | active |
| 6b26fa99-26b5-4c46-a1fd-c604f81927ea | overcloud-full         | active |
| 3a7f5849-f332-4b5b-a162-4163644e4b5f | overcloud-full-initrd  | active |
| 40759dfb-3ae2-479e-9eb0-8efdb779714a | overcloud-full-vmlinuz | active |
+--------------------------------------+------------------------+--------+
```

Note: The list shows only the overcloud and deployment images—it does not show the inspection images.

2.2 Examine the content of the /httpboot directory to view the director’s discovery images and inspection image installation script:

```
(undercloud) [stack@undercloud ~]$ ls -al /httpboot
```

Kind of Sample Output:
```
total 421712
drwxr-xr-x.  2 ironic           ironic                  82 May 17 13:33 .
dr-xr-xr-x. 19 root             root                  4096 May 17 13:01 ..
-rwxr-xr-x.  1 root             root               6381872 May 17 13:33 agent.kernel
-rw-r--r--.  1 root             root             425433702 May 17 13:33 agent.ramdisk
-rw-r--r--.  1 ironic           ironic                 758 May 17 13:07 boot.ipxe
-rw-r--r--.  1 ironic-inspector ironic-inspector       449 May 17 13:01 inspector.ipxe
```

Note: The inspection images are stored outside the undercloud’s OpenStack infrastructure because they are used by the target hosts before they are aware of, or capable of requesting, images from the undercloud. These images are distributed to the hosts using either PXE or iPXE depending on your configuration.

2.3 Examine the inspector.ipxe file, which contains instructions on how to boot the hosts:

```
(undercloud) [stack@undercloud ~]$ cat /httpboot/inspector.ipxe
```

Kind of Sample Output:

```
#!ipxe

:retry_boot
imgfree
kernel --timeout 60000 http://192.0.2.1:8088/agent.kernel ipa-inspection-callback-url=http://192.0.2.1:5050/v1/continue ipa-inspection-collectors=default,extra-hardware,numa-topology,logs systemd.journald.forward_to_console=yes BOOTIF=${mac} ipa-inspection-dhcp-all-interfaces=1 ipa-collect-lldp=1 initrd=agent.ramdisk || goto retry_boot
initrd --timeout 60000 http://192.0.2.1:8088/agent.ramdisk || goto retry_boot
boot
```
3. Prepare for Containerized Overcloud Deployment

A containerized overcloud requires access to a registry with the required container images. The Director Installation and Usage guide describes several ways to prepare the registry and your overcloud configuration to use container images for Red Hat OpenStack Platform.

Red Hat OpenStack Platform supports the following registry types:

* Remote Registry — The overcloud pulls container images directly from registry.access.redhat.com. This is the easiest method for generating the initial configuration. However, each overcloud node pulls each image directly from the Red Hat Container Catalog, which can cause network congestion and slower deployment. In addition, all overcloud nodes require Internet access to the Red Hat Container Catalog.
* Local Registry — You create a local registry on the undercloud, synchronize the images from registry.access.redhat.com, and the overcloud pulls the container images from the undercloud. This method allows you to store a registry internally, which can speed up the deployment and decrease network congestion. However, the undercloud only acts as a basic registry and provides limited life cycle management for container images.
* Satellite Server — You can manage the complete application life cycle of your container images and publish them through a Red Hat Satellite 6 server. The overcloud pulls the images from the Satellite server. This method provides an enterprise-grade solution for storing, managing, and deploying Red Hat OpenStack Platform containers.


Note: For this example I will choose a local registry. For more information check out this [link](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/pdf/director_installation_and_usage/Red_Hat_OpenStack_Platform-13-Director_Installation_and_Usage-en-US.pdf)


3.1 Generating a Container Image Environment File for the Overcloud

3.1.1 Verify access the registry and discover image tags:

```
(undercloud) [stack@undercloud ~]$ openstack overcloud container image tag discover \
     --image registry.access.redhat.com/rhosp13/openstack-base \
     --tag-from-label {version}-{release}
```


3.2 Create a template to upload the the container images required to implement your overcloud deployment plan to the local registry, and the environment file to refer to those images:
```
(undercloud) $ openstack overcloud container image prepare \
--namespace=registry.access.redhat.com/rhosp13 \
--push-destination=192.0.2.1:8787 \
--prefix=openstack- \
--tag-from-label {version}-{release} \
-e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-ovn-dvr-ha.yaml \
--output-env-file=/home/stack/templates/overcloud_images.yaml \
--output-images-file /home/stack/local_registry_images.yaml
```
This creates two files:

* local_registry_images.yaml, which contains container image information from the
remote source. Use this file to pull the images from the Red Hat Container Registry
(registry.access.redhat.com) to the undercloud.
* overcloud_images.yaml, which contains the eventual image locations on the
undercloud. You include this file with your deployment.

Check that both files exist.

If your overcloud needs to use Ceph Storage, include the additional environment file and parameters to define the Ceph Storage container image location:
```
(undercloud) $ openstack overcloud container image prepare \
--namespace=registry.access.redhat.com/rhosp13 \
--push-destination=192.0.2.1:8787 \
--prefix=openstack- \
--tag-from-label {version}-{release} \
-e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-ovn-dvr-ha.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
--output-env-file=/home/stack/templates/overcloud_images.yaml \
--output-images-file /home/stack/local_registry_images.yaml
```

3.2.1 Examine the overcloud_images.yaml environment file:
```
(undercloud) [stack@undercloud ~]$ cat ~/templates/environments/overcloud_images.yaml
```

Kind of Sample Output:

```
# Generated with the following on 2018-07-09T18:43:18.515417
#
#   openstack overcloud container image prepare --namespace=classroom.example.com:5000/rhosp13 --push-destination=192.0.2.1:8787 --tag=13.0 --tag-from-label {version}-{release} -e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-ovn-dvr-ha.yaml --output-env-file /home/stack/templates/environments/overcloud_images.yaml --output-images-file /home/stack/local_registry_images.yaml
#

parameter_defaults:
  DockerAodhApiImage: 192.0.2.1:8787/rhosp13/openstack-aodh-api:13.0-40
  DockerAodhConfigImage: 192.0.2.1:8787/rhosp13/openstack-aodh-api:13.0-40
  DockerAodhEvaluatorImage: 192.0.2.1:8787/rhosp13/openstack-aodh-evaluator:13.0-39
  DockerAodhListenerImage: 192.0.2.1:8787/rhosp13/openstack-aodh-listener:13.0-39
  DockerAodhNotifierImage: 192.0.2.1:8787/rhosp13/openstack-aodh-notifier:13.0-39
  DockerCeilometerCentralImage: 192.0.2.1:8787/rhosp13/openstack-ceilometer-central:13.0-37
  DockerCeilometerComputeImage: 192.0.2.1:8787/rhosp13/openstack-ceilometer-compute:13.0-38
  DockerCeilometerConfigImage: 192.0.2.1:8787/rhosp13/openstack-ceilometer-central:13.0-37
  DockerCeilometerNotificationImage: 192.0.2.1:8787/rhosp13/openstack-ceilometer-notification:13.0-37
  DockerCinderApiImage: 192.0.2.1:8787/rhosp13/openstack-cinder-api:13.0-39
  DockerCinderConfigImage: 192.0.2.1:8787/rhosp13/openstack-cinder-api:13.0-39
  DockerCinderSchedulerImage: 192.0.2.1:8787/rhosp13/openstack-cinder-scheduler:13.0-38
  DockerCinderVolumeImage: 192.0.2.1:8787/rhosp13/openstack-cinder-volume:13.0-38
  DockerClustercheckConfigImage: 192.0.2.1:8787/rhosp13/openstack-mariadb:13.0-40
  DockerClustercheckImage: 192.0.2.1:8787/rhosp13/openstack-mariadb:13.0-40
  DockerCrondConfigImage: 192.0.2.1:8787/rhosp13/openstack-cron:13.0-43
  DockerCrondImage: 192.0.2.1:8787/rhosp13/openstack-cron:13.0-43
  DockerGlanceApiConfigImage: 192.0.2.1:8787/rhosp13/openstack-glance-api:13.0-38
  DockerGlanceApiImage: 192.0.2.1:8787/rhosp13/openstack-glance-api:13.0-38
  DockerGnocchiApiImage: 192.0.2.1:8787/rhosp13/openstack-gnocchi-api:13.0-38
  DockerGnocchiConfigImage: 192.0.2.1:8787/rhosp13/openstack-gnocchi-api:13.0-38
  DockerGnocchiMetricdImage: 192.0.2.1:8787/rhosp13/openstack-gnocchi-metricd:13.0-39
  DockerGnocchiStatsdImage: 192.0.2.1:8787/rhosp13/openstack-gnocchi-statsd:13.0-39
  DockerHAProxyConfigImage: 192.0.2.1:8787/rhosp13/openstack-haproxy:13.0-40
  DockerHAProxyImage: 192.0.2.1:8787/rhosp13/openstack-haproxy:13.0-40
  DockerHeatApiCfnConfigImage: 192.0.2.1:8787/rhosp13/openstack-heat-api-cfn:13.0-39
  DockerHeatApiCfnImage: 192.0.2.1:8787/rhosp13/openstack-heat-api-cfn:13.0-39
  DockerHeatApiConfigImage: 192.0.2.1:8787/rhosp13/openstack-heat-api:13.0-40
  DockerHeatApiImage: 192.0.2.1:8787/rhosp13/openstack-heat-api:13.0-40
  DockerHeatConfigImage: 192.0.2.1:8787/rhosp13/openstack-heat-api:13.0-40
  DockerHeatEngineImage: 192.0.2.1:8787/rhosp13/openstack-heat-engine:13.0-38
  DockerHorizonConfigImage: 192.0.2.1:8787/rhosp13/openstack-horizon:13.0-38
  DockerHorizonImage: 192.0.2.1:8787/rhosp13/openstack-horizon:13.0-38
  DockerInsecureRegistryAddress:
  - 192.0.2.1:8787
  DockerIscsidConfigImage: 192.0.2.1:8787/rhosp13/openstack-iscsid:13.0-38
  DockerIscsidImage: 192.0.2.1:8787/rhosp13/openstack-iscsid:13.0-38
  DockerKeystoneConfigImage: 192.0.2.1:8787/rhosp13/openstack-keystone:13.0-38
  DockerKeystoneImage: 192.0.2.1:8787/rhosp13/openstack-keystone:13.0-38
  DockerMemcachedConfigImage: 192.0.2.1:8787/rhosp13/openstack-memcached:13.0-39
  DockerMemcachedImage: 192.0.2.1:8787/rhosp13/openstack-memcached:13.0-39
  DockerMysqlClientConfigImage: 192.0.2.1:8787/rhosp13/openstack-mariadb:13.0-40
  DockerMysqlConfigImage: 192.0.2.1:8787/rhosp13/openstack-mariadb:13.0-40
  DockerMysqlImage: 192.0.2.1:8787/rhosp13/openstack-mariadb:13.0-40
  DockerNeutronApiImage: 192.0.2.1:8787/rhosp13/openstack-neutron-server-ovn:13.0-36
  DockerNeutronConfigImage: 192.0.2.1:8787/rhosp13/openstack-neutron-server-ovn:13.0-36
  DockerNovaApiImage: 192.0.2.1:8787/rhosp13/openstack-nova-api:13.0-42
  DockerNovaComputeImage: 192.0.2.1:8787/rhosp13/openstack-nova-compute:13.0-41
  DockerNovaConductorImage: 192.0.2.1:8787/rhosp13/openstack-nova-conductor:13.0-42
  DockerNovaConfigImage: 192.0.2.1:8787/rhosp13/openstack-nova-api:13.0-42
  DockerNovaConsoleauthImage: 192.0.2.1:8787/rhosp13/openstack-nova-consoleauth:13.0-41
  DockerNovaLibvirtConfigImage: 192.0.2.1:8787/rhosp13/openstack-nova-compute:13.0-41
  DockerNovaLibvirtImage: 192.0.2.1:8787/rhosp13/openstack-nova-libvirt:13.0-43
  DockerNovaMetadataImage: 192.0.2.1:8787/rhosp13/openstack-nova-api:13.0-42
  DockerNovaPlacementConfigImage: 192.0.2.1:8787/rhosp13/openstack-nova-placement-api:13.0-42
  DockerNovaPlacementImage: 192.0.2.1:8787/rhosp13/openstack-nova-placement-api:13.0-42
  DockerNovaSchedulerImage: 192.0.2.1:8787/rhosp13/openstack-nova-scheduler:13.0-42
  DockerNovaVncProxyImage: 192.0.2.1:8787/rhosp13/openstack-nova-novncproxy:13.0-42
  DockerOvnControllerConfigImage: 192.0.2.1:8787/rhosp13/openstack-ovn-controller:13.0-40
  DockerOvnControllerImage: 192.0.2.1:8787/rhosp13/openstack-ovn-controller:13.0-40
  DockerOvnDbsConfigImage: 192.0.2.1:8787/rhosp13/openstack-ovn-northd:13.0-40
  DockerOvnDbsImage: 192.0.2.1:8787/rhosp13/openstack-ovn-northd:13.0-40
  DockerOvnMetadataImage: 192.0.2.1:8787/rhosp13/openstack-neutron-metadata-agent-ovn:13.0-37
  DockerOvnNbDbImage: 192.0.2.1:8787/rhosp13/openstack-ovn-nb-db-server:13.0-40
  DockerOvnNorthdImage: 192.0.2.1:8787/rhosp13/openstack-ovn-northd:13.0-40
  DockerOvnSbDbImage: 192.0.2.1:8787/rhosp13/openstack-ovn-sb-db-server:13.0-40
  DockerPankoApiImage: 192.0.2.1:8787/rhosp13/openstack-panko-api:13.0-40
  DockerPankoConfigImage: 192.0.2.1:8787/rhosp13/openstack-panko-api:13.0-40
  DockerRabbitmqConfigImage: 192.0.2.1:8787/rhosp13/openstack-rabbitmq:13.0-40
  DockerRabbitmqImage: 192.0.2.1:8787/rhosp13/openstack-rabbitmq:13.0-40
  DockerRedisConfigImage: 192.0.2.1:8787/rhosp13/openstack-redis:13.0-42
  DockerRedisImage: 192.0.2.1:8787/rhosp13/openstack-redis:13.0-42
  DockerSwiftAccountImage: 192.0.2.1:8787/rhosp13/openstack-swift-account:13.0-38
  DockerSwiftConfigImage: 192.0.2.1:8787/rhosp13/openstack-swift-proxy-server:13.0-38
  DockerSwiftContainerImage: 192.0.2.1:8787/rhosp13/openstack-swift-container:13.0-39
  DockerSwiftObjectImage: 192.0.2.1:8787/rhosp13/openstack-swift-object:13.0-38
  DockerSwiftProxyImage: 192.0.2.1:8787/rhosp13/openstack-swift-proxy-server:13.0-38
  ```

  Note: The DockerInsecureRegistryAddress entry specifies the IP address of the undercloud node. During deployment, it is used by overcloud nodes to pull images.


3.3 Verify that the registry is running on port 8787 on the undercloud node:

```
(undercloud) [stack@undercloud ~]$ sudo netstat -tulpn | grep 8787
```

Kind of Sample Output:

```
tcp        0      0 192.0.2.1:8787          0.0.0.0:*               LISTEN      1401/registry
tcp        0      0 192.0.2.3:8787          0.0.0.0:*               LISTEN      1485/haproxy
```

3.4 Check the content of the local registry before you upload container images into it:

```
(undercloud) [stack@undercloud ~]$ sudo docker images
```

Kind of Sample Output:

```
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
```

3.5 Upload container images into the local registry:

```
(undercloud) [stack@undercloud ~]$ sudo openstack overcloud container image upload \
     --config-file /home/stack/local_registry_images.yaml --verbose
```

3.6 List the repositories in the local registry at the undercloud node:

```
(undercloud) [stack@undercloud ~]$ curl -s -H "Accept: application/json" http://192.0.2.1:8787/v2/_catalog | python -m json.tool
```

Kind of Sample Output:

```
{
    "repositories": [
        "rhosp13/openstack-aodh-api",
        "rhosp13/openstack-aodh-evaluator",
        "rhosp13/openstack-aodh-listener",
        "rhosp13/openstack-aodh-notifier",
        "rhosp13/openstack-ceilometer-central",
        "rhosp13/openstack-ceilometer-compute",
        "rhosp13/openstack-ceilometer-notification",
        "rhosp13/openstack-cinder-api",
        "rhosp13/openstack-cinder-scheduler",
        "rhosp13/openstack-cinder-volume",
        "rhosp13/openstack-cron",
        "rhosp13/openstack-glance-api",
        "rhosp13/openstack-gnocchi-api",
        "rhosp13/openstack-gnocchi-metricd",
        "rhosp13/openstack-gnocchi-statsd",
        "rhosp13/openstack-haproxy",
        "rhosp13/openstack-heat-api",
        "rhosp13/openstack-heat-api-cfn",
        "rhosp13/openstack-heat-engine",
        "rhosp13/openstack-horizon",
        "rhosp13/openstack-iscsid",
        "rhosp13/openstack-keystone",
        "rhosp13/openstack-mariadb",
        "rhosp13/openstack-memcached",
        "rhosp13/openstack-neutron-metadata-agent-ovn",
        "rhosp13/openstack-neutron-server-ovn",
        "rhosp13/openstack-nova-api",
        "rhosp13/openstack-nova-compute",
        "rhosp13/openstack-nova-conductor",
        "rhosp13/openstack-nova-consoleauth",
        "rhosp13/openstack-nova-libvirt",
        "rhosp13/openstack-nova-novncproxy",
        "rhosp13/openstack-nova-placement-api",
        "rhosp13/openstack-nova-scheduler",
        "rhosp13/openstack-ovn-controller",
        "rhosp13/openstack-ovn-nb-db-server",
        "rhosp13/openstack-ovn-northd",
        "rhosp13/openstack-ovn-sb-db-server",
        "rhosp13/openstack-panko-api",
        "rhosp13/openstack-rabbitmq",
        "rhosp13/openstack-redis",
        "rhosp13/openstack-swift-account",
        "rhosp13/openstack-swift-container",
        "rhosp13/openstack-swift-object",
        "rhosp13/openstack-swift-proxy-server"
    ]
}
```
