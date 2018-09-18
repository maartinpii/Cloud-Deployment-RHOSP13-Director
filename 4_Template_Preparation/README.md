# Overcloud Templates Preparation

## Objectives

* Prepare environment files for the overcloud deployment
* Configure network connections in the controller node template
* Configure network connections in the compute node template

1. Review General Customization Concepts

The undercloud includes a set of TripleO Heat templates that acts as a plan for your overcloud creation. You can customize aspects of the overcloud using environment files, which are YAML-formatted files that override parameters and resources in the core Heat template collection. You can include as many environment files as necessary. However, the order of the environment files is important because the parameters and resources defined in subsequent environment files take precedence.

Use the following list as an example of the environment file order:

* The environment file specifying the number of nodes per role and their flavors. It is vital to include this information for overcloud creation.
* The environment file specifying the location of the container images for containerized OpenStack services.
* Network configuration environment files:
Start with the network initialization file (environments/network-isolation.yaml) from the TripleO Heat template collection if you plan to implement network isolation in your overcloud. The core TripleO Heat template collection contains Jinja2 templates that are used to generate this file dynamically during the deployment.
Follow with a network environment file with the registry of the NIC configuration templates for different roles and any additional network parameters such as VLANs, IPv4, and IPv6 subnets.
* Any extra files that may be necessary in the advanced deployments, such as:
External load balancing environment files
Storage environment files for Red Hat Ceph Storage, NFS, iSCSI, etc.
Environment files for Red Hat Content Delivery Network or Red Hat Satellite registration
Other custom environment files

Some of the core Heat templates for the overcloud are in the Jinja2 format. Red Hat OpenStack Platform director renders them to Heat environment files in the YAML format at the beginning of the overcloud deployment, using roles and network parameters. The default values for these parameters are provided in the roles_data.yaml and network_data.yaml files. Use them as starting points for customization.

The instructions below cover only one of them with Open Virtual Networking (OVN) and Distributed Virtual Routing (DVR) with High Availability (HA). This is a new feature in Red Hat OpenStack Platform 13 and it is recommended for new deployments.

Note: This example does not use Ceph Storage, which is the recommended way. LVM is not supported.


2. Environment Files for Overcloud Deployment

2.1 Create directories for the environment files and Heat templates:

```
(undercloud) [stack@undercloud ~]$ mkdir -p ~/templates/environments
(undercloud) [stack@undercloud ~]$ mkdir -p ~/templates/heat
```

2.2 Prepare a custom environment file specifying the number of nodes per role and their flavors:

Note: Example /home/stack/templates/environments/node-info.yaml File

```
parameter_defaults:
  OvercloudControlFlavor: control
  OvercloudComputeFlavor: compute
  ControllerCount: 1
  ComputeCount: 2
```

2.3 Review the contents of the environment file specifying the location of the container images for containerized OpenStack services:

```
(undercloud) [stack@undercloud templates]$ head environments/overcloud_images.yaml
```

Note: The listed images are to be used on the overcloud nodes.

2.4 Create a Heat template that defines the userdata resource, which sets the root password:


Note: Example /home/stack/templates/heat/firstboot.yaml File

```
heat_template_version: 2014-10-16

description: >
  Set root password

resources:
  userdata:
    type: OS::Heat::MultipartMime
    properties:
      parts:
      - config: {get_resource: set_pass}

  set_pass:
    type: OS::Heat::SoftwareConfig
    properties:
      config: |
        #!/bin/bash
        echo 'r3dh4t1!' | passwd --stdin root

outputs:
  OS::stack_id:
    value: {get_resource: userdata}

```

2.5 Environment file that defines the user data to be used during the first boot on all of the overcloud nodes: Example /home/stack/templates/environments/firstboot.yaml File

```
resource_registry:
  OS::TripleO::NodeUserData: ../heat/firstboot.yaml
```

2.6 Prepare an environment file to work around the lack of resources on this demo environment: Example /home/stack/templates/environments/fix-nova-reserved-host-memory.yaml File

```
parameter_defaults:
  NovaReservedHostMemory: 1024
```

3. Network Definitions

Regarding the architecture diagram on 1_UnderCloud-Installation, we have defined the use of two different networks, Provisioning and DataCenter. One is attached to the eth0 and the other to the eth1.

DataCenter network is a trunk configured with multiple vLANs.

The undercloud can use different VLANs for traffic separation. TripleO provides definitions for a default set of networks listed in the table below. The network names used in this table are also used in the TripleO network configuration templates and environment files.

|Name          |vLAN  |Subnet         |Gateway IP  |Description                              |
|--------------|------|---------------|------------|-----------------------------------------|
|ControlPlane  |flat  |192.0.2.0/24   |192.0.2.254 |Undercloud control plane and PXE boot    |
|External      |10    |10.0.0.0/24    |10.0.0.1    |Overcloud external API and floating IP   |
|InternalApi   |20    |172.17.0.0/24  |            |Overcloud internal API endpoints         |
|Storage       |30    |172.18.0.0/24  |            |Storage access network                   |
|StorageMgmt   |40    |172.19.0.0/24  |            |Internal storage cluster network         |
|Tenant        |50    |172.16.0.0/24  |            |Network for tenant tunnels               |     


Note: The External, InternalApi, Storage, StorageMgmt, and Tenant networks are configured using VLANs on the datacentre network. The ControlPlane network is mapped to the flat provisioning network

4. Create Custom Network Environment File

Red Hat OpenStack Platform 13 director provides a tool to generate environment files and sample NIC configuration templates using data from the roles_data.yaml and network_data.yaml

4.1  Customize Roles and Network Data

4.1.1 Define the THT shell variable as a path to the TripleO Heat templates directory:

```
(undercloud) [stack@undercloud ~]$ THT=/usr/share/openstack-tripleo-heat-templates
```

4.1.2 Copy the default roles_data.yaml and network_data.yaml files from $THT to a local directory:

```
(undercloud) [stack@undercloud ~]$ cp $THT/roles_data.yaml ~/templates
(undercloud) [stack@undercloud ~]$ cp $THT/network_data.yaml ~/templates
```

4.1.3 Review the contenhe file defines the default roles and their parameters.

Pay attention to the list of networks defined for each role.ts of the roles_data.yaml file

```
(undercloud) [stack@undercloud ~]$ grep -A10 'Role: Compute' templates/roles_data.yaml
```

Kind of Sample Output:

```
# Role: Compute                                                               #
###############################################################################
- name: Compute
  description: |
    Basic Compute Node role
  CountDefault: 1
  networks:
    - InternalApi
    - Tenant
    - Storage
  HostnameFormatDefault: '%stackname%-compute-%index%'
  ```

Note: By default, nodes in the Compute role do not have a connection to the External network. The connection is not necessary if you deploy an overcloud with ML2/OVS networking and without DVR. However, you must define this connection for the deployment scenario with OVN and DVR.

4.1.4 Add the External network to the list of networks defined for the Compute role

```
$ nano templates/roles_data.yaml

//add '- External' Line 185

```

4.1.5 Review Results

```
(undercloud) [stack@undercloud ~]$ grep -A11 'Role: Compute' templates/roles_data.yaml
```

Kind of Sample Output:

```
# Role: Compute                                                               #
###############################################################################
- name: Compute
  description: |
    Basic Compute Node role
  CountDefault: 1
  networks:
    - InternalApi
    - Tenant
    - Storage
    - External
  HostnameFormatDefault: '%stackname%-compute-%index%'
```

Note: this could have been done with git (git patch) instead of performing manually.


4.1.6 Review the network_data.yaml file:

```
(undercloud) [stack@undercloud ~]$ egrep -v '^#|^$' templates/network_data.yaml
```

Kind of Sample Output:

```
- name: Storage
  vip: true
  vlan: 30
  name_lower: storage
  ip_subnet: '172.16.1.0/24'
  allocation_pools: [{'start': '172.16.1.4', 'end': '172.16.1.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:3000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:3000::10', 'end': 'fd00:fd00:fd00:3000:ffff:ffff:ffff:fffe'}]
- name: StorageMgmt
  name_lower: storage_mgmt
  vip: true
  vlan: 40
  ip_subnet: '172.16.3.0/24'
  allocation_pools: [{'start': '172.16.3.4', 'end': '172.16.3.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:4000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:4000::10', 'end': 'fd00:fd00:fd00:4000:ffff:ffff:ffff:fffe'}]
- name: InternalApi
  name_lower: internal_api
  vip: true
  vlan: 20
  ip_subnet: '172.16.2.0/24'
  allocation_pools: [{'start': '172.16.2.4', 'end': '172.16.2.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:2000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:2000::10', 'end': 'fd00:fd00:fd00:2000:ffff:ffff:ffff:fffe'}]
- name: Tenant
  vip: false  # Tenant network does not use VIPs
  name_lower: tenant
  vlan: 50
  ip_subnet: '172.16.0.0/24'
  allocation_pools: [{'start': '172.16.0.4', 'end': '172.16.0.250'}]
  # Note that tenant tunneling is only compatible with IPv4 addressing at this time.
  ipv6_subnet: 'fd00:fd00:fd00:5000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:5000::10', 'end': 'fd00:fd00:fd00:5000:ffff:ffff:ffff:fffe'}]
- name: External
  vip: true
  name_lower: external
  vlan: 10
  ip_subnet: '10.0.0.0/24'
  allocation_pools: [{'start': '10.0.0.4', 'end': '10.0.0.250'}]
  gateway_ip: '10.0.0.1'
  ipv6_subnet: '2001:db8:fd00:1000::/64'
  ipv6_allocation_pools: [{'start': '2001:db8:fd00:1000::10', 'end': '2001:db8:fd00:1000:ffff:ffff:ffff:fffe'}]
  gateway_ipv6: '2001:db8:fd00:1000::1'
- name: Management
  # Management network is enabled by default for backwards-compatibility, but
  # is not included in any roles by default. Add to role definitions to use.
  enabled: true
  vip: false  # Management network does not use VIPs
  name_lower: management
  vlan: 60
  ip_subnet: '10.0.1.0/24'
  allocation_pools: [{'start': '10.0.1.4', 'end': '10.0.1.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:6000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:6000::10', 'end': 'fd00:fd00:fd00:6000:ffff:ffff:ffff:fffe'}]

```

4.1.7 Compare the ip_subnet, gateway_ip and vlan parameters with the values specified in the Lab Networks and VLANs table above. As you can see, the gateway_ip of the External network and vlan parameters in the network_data.yaml file match values in the table. However, the ip_subnet and allocation_pools values need to be modified.

Note: Again, edit manually or with git.

The result of the modification should look like this:

```

- name: Storage
  vip: true
  vlan: 30
  name_lower: storage
  ip_subnet: '172.18.0.0/24'
  allocation_pools: [{'start': '172.18.0.4', 'end': '172.18.0.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:3000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:3000::10', 'end': 'fd00:fd00:fd00:3000:ffff:ffff:ffff:fffe'}]
- name: StorageMgmt
  name_lower: storage_mgmt
  vip: true
  vlan: 40
  ip_subnet: '172.19.0.0/24'
  allocation_pools: [{'start': '172.19.0.4', 'end': '172.19.0.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:4000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:4000::10', 'end': 'fd00:fd00:fd00:4000:ffff:ffff:ffff:fffe'}]
- name: InternalApi
  name_lower: internal_api
  vip: true
  vlan: 20
  ip_subnet: '172.17.0.0/24'
  allocation_pools: [{'start': '172.17.0.4', 'end': '172.17.0.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:2000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:2000::10', 'end': 'fd00:fd00:fd00:2000:ffff:ffff:ffff:fffe'}]
- name: Tenant
  vip: false  # Tenant network does not use VIPs
  name_lower: tenant
  vlan: 50
  ip_subnet: '172.16.0.0/24'
  allocation_pools: [{'start': '172.16.0.4', 'end': '172.16.0.250'}]
  # Note that tenant tunneling is only compatible with IPv4 addressing at this time.
  ipv6_subnet: 'fd00:fd00:fd00:5000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:5000::10', 'end': 'fd00:fd00:fd00:5000:ffff:ffff:ffff:fffe'}]
- name: External
  vip: true
  name_lower: external
  vlan: 10
  ip_subnet: '10.0.0.0/24'
  allocation_pools: [{'start': '10.0.0.4', 'end': '10.0.0.250'}]
  gateway_ip: '10.0.0.1'
  ipv6_subnet: '2001:db8:fd00:1000::/64'
  ipv6_allocation_pools: [{'start': '2001:db8:fd00:1000::10', 'end': '2001:db8:fd00:1000:ffff:ffff:ffff:fffe'}]
  gateway_ipv6: '2001:db8:fd00:1000::1'
- name: Management
  # Management network is enabled by default for backwards-compatibility, but
  # is not included in any roles by default. Add to role definitions to use.
  enabled: true
  vip: false  # Management network does not use VIPs
  name_lower: management
  vlan: 60
  ip_subnet: '10.0.1.0/24'
  allocation_pools: [{'start': '10.0.1.4', 'end': '10.0.1.250'}]
  ipv6_subnet: 'fd00:fd00:fd00:6000::/64'
  ipv6_allocation_pools: [{'start': 'fd00:fd00:fd00:6000::10', 'end': 'fd00:fd00:fd00:6000:ffff:ffff:ffff:fffe

  ```

  4.2 Generate Environment Files

  In this section, we use a tool to process the core TripleO Heat template collection to produce environment files and NIC configuration templates suitable for customization in your network environment.

4.2.1 Create the temporary directories used for the template processing:

```
(undercloud) [stack@undercloud ~]$ mkdir ~/workplace
(undercloud) [stack@undercloud ~]$ mkdir ~/output
```

4.2.2 Copy the contents of the TripleO Heat templates' directory to the workplace directory:

```
(undercloud) [stack@undercloud ~]$ cp -rp /usr/share/openstack-tripleo-heat-templates/* workplace
```

4.2.3 Process TripleO Heat templates to generate environment files that are suitable for customization:

```
(undercloud) [stack@undercloud ~]$ cd workplace
(undercloud) [stack@undercloud workplace]$ tools/process-templates.py -r ../templates/roles_data.yaml -n ../templates/network_data.yaml -o ../output
```

Note: The -r and -n options specify the locations of the custom roles_data.yaml and network_data.yaml files. The rendered environment files and sample NIC configuration templates are placed into the directory specified by the -o option.

4.2.4 Review the network-environment.yaml file generated by the previous command:

```
(undercloud) [stack@undercloud workplace]$ cd ../output
(undercloud) [stack@undercloud output]$ cat environments/network-environment.yaml
```

Kind of Sample output:

```
#This file is an example of an environment file for defining the isolated
#networks and related parameters.
resource_registry:
  # Network Interface templates to use (these files must exist). You can
  # override these by including one of the net-*.yaml environment files,
  # such as net-bond-with-vlans.yaml, or modifying the list here.
  # Port assignments for the Controller
  OS::TripleO::Controller::Net::SoftwareConfig:
    ../network/config/single-nic-vlans/controller.yaml
  # Port assignments for the Compute
  OS::TripleO::Compute::Net::SoftwareConfig:
    ../network/config/single-nic-vlans/compute.yaml
  # Port assignments for the BlockStorage
  OS::TripleO::BlockStorage::Net::SoftwareConfig:
    ../network/config/single-nic-vlans/cinder-storage.yaml
  # Port assignments for the ObjectStorage
  OS::TripleO::ObjectStorage::Net::SoftwareConfig:
    ../network/config/single-nic-vlans/swift-storage.yaml
  # Port assignments for the CephStorage
  OS::TripleO::CephStorage::Net::SoftwareConfig:
    ../network/config/single-nic-vlans/ceph-storage.yaml

parameter_defaults:
  # This section is where deployment-specific configuration is done
  # CIDR subnet mask length for provisioning network
  ControlPlaneSubnetCidr: '24'
  # Gateway router for the provisioning network (or Undercloud IP)
  ControlPlaneDefaultRoute: 192.168.24.254
  EC2MetadataIp: 192.168.24.1  # Generally the IP of the Undercloud
  # Customize the IP subnets to match the local environment
  StorageNetCidr: '172.18.0.0/24'
  StorageMgmtNetCidr: '172.19.0.0/24'
  InternalApiNetCidr: '172.17.0.0/24'
  TenantNetCidr: '172.16.0.0/24'
  ExternalNetCidr: '10.0.0.0/24'
  ManagementNetCidr: '10.0.1.0/24'
  # Customize the VLAN IDs to match the local environment
  StorageNetworkVlanID: 30
  StorageMgmtNetworkVlanID: 40
  InternalApiNetworkVlanID: 20
  TenantNetworkVlanID: 50
  ExternalNetworkVlanID: 10
  ManagementNetworkVlanID: 60
  StorageAllocationPools: [{'start': '172.18.0.4', 'end': '172.18.0.250'}]
  StorageMgmtAllocationPools: [{'start': '172.19.0.4', 'end': '172.19.0.250'}]
  InternalApiAllocationPools: [{'start': '172.17.0.4', 'end': '172.17.0.250'}]
  TenantAllocationPools: [{'start': '172.16.0.4', 'end': '172.16.0.250'}]
  # Leave room if the external network is also used for floating IPs
  ExternalAllocationPools: [{'start': '10.0.0.4', 'end': '10.0.0.250'}]
  ManagementAllocationPools: [{'start': '10.0.1.4', 'end': '10.0.1.250'}]
  # Gateway routers for routable networks
  ExternalInterfaceDefaultRoute: '10.0.0.1'
  # Define the DNS servers (maximum 2) for the overcloud nodes
  DnsServers: ["8.8.8.8","8.8.4.4"]
  # List of Neutron network types for tenant networks (will be used in order)
  NeutronNetworkType: 'vxlan,vlan'
  # The tunnel type for the tenant network (vxlan or gre). Set to '' to disable tunneling.
  NeutronTunnelTypes: 'vxlan'
  # Neutron VLAN ranges per network, for example 'datacentre:1:499,tenant:500:1000':
  NeutronNetworkVLANRanges: 'datacentre:1:1000'
  # Customize bonding options, e.g. "mode=4 lacp_rate=1 updelay=1000 miimon=100"
  # for Linux bonds w/LACP, or "bond_mode=active-backup" for OVS active/backup.
  BondInterfaceOvsOptions: "bond_mode=active-backup"
  ```


* Most of the network CIDR values, the allocation pools, and the VlanID match the values specified in the network_data.yaml file.
* The parameters of the control plane need to be adjusted to match the configuration of the provisioning network in the environment.
* The resource_registry section contains a sample configuration that needs to be changed.

4.2.5 Modify the network-environment.yaml file to reflect details of your lab environment

After modification it should looks as follow:

```
resource_registry:
  OS::TripleO::Controller::Net::SoftwareConfig:
    ../nic-configs/controller.yaml
  OS::TripleO::Compute::Net::SoftwareConfig:
    ../nic-configs/compute.yaml

parameter_defaults:
  # This section is where deployment-specific configuration is done
  # CIDR subnet mask length for provisioning network
  ControlPlaneSubnetCidr: '24'
  # Gateway router for the provisioning network (or Undercloud IP)
  ControlPlaneDefaultRoute: 192.0.2.254
  EC2MetadataIp: 192.0.2.1 # Generally the IP of the Undercloud
  # Customize the IP subnets to match the local environment
  StorageNetCidr: '172.18.0.0/24'
  StorageMgmtNetCidr: '172.19.0.0/24'
  InternalApiNetCidr: '172.17.0.0/24'
  TenantNetCidr: '172.16.0.0/24'
  ExternalNetCidr: '10.0.0.0/24'
  ManagementNetCidr: '10.0.1.0/24'
  # Customize the VLAN IDs to match the local environment
  StorageNetworkVlanID: 30
  StorageMgmtNetworkVlanID: 40
  InternalApiNetworkVlanID: 20
  TenantNetworkVlanID: 50
  ExternalNetworkVlanID: 10
  ManagementNetworkVlanID: 60
  StorageAllocationPools: [{'start': '172.18.0.4', 'end': '172.18.0.250'}]
  StorageMgmtAllocationPools: [{'start': '172.19.0.4', 'end': '172.19.0.250'}]
  InternalApiAllocationPools: [{'start': '172.17.0.4', 'end': '172.17.0.250'}]
  TenantAllocationPools: [{'start': '172.16.0.4', 'end': '172.16.0.250'}]
  # Leave room if the external network is also used for floating IPs
  ExternalAllocationPools: [{'start': '10.0.0.4', 'end': '10.0.0.250'}]
  ManagementAllocationPools: [{'start': '10.0.1.4', 'end': '10.0.1.250'}]
  # Gateway routers for routable networks
  ExternalInterfaceDefaultRoute: '10.0.0.1'
  # Define the DNS servers (maximum 2) for the overcloud nodes
  DnsServers: ["192.0.2.254"]
  # List of Neutron network types for tenant networks (will be used in order)
  NeutronNetworkType: 'vxlan,vlan'
  # The tunnel type for the tenant network (vxlan or gre). Set to '' to disable tunneling.
  NeutronTunnelTypes: 'vxlan'
  # Neutron VLAN ranges per network, for example 'datacentre:1:499,tenant:500:1000':
  NeutronNetworkVLANRanges: 'datacentre:1:1000'
  # Customize bonding options, e.g. "mode=4 lacp_rate=1 updelay=1000 miimon=100"
  # for Linux bonds w/LACP, or "bond_mode=active-backup" for OVS active/backup.
  BondInterface
  ```

* The resource_registry section defines two resources that should be implemented in the ../nic-configs directory.

5. Create Network Interface Configuration Templates

The process-templates.py tool you used before to generate the network-environment.yaml file also creates a few sets of the sample network interface configuration templates. The idea is to select a sample configuration that best matches the hardware on which the overcloud is being deployed. For this env, the closest configuration is single-nic-vlans. Your overcloud has only controller and compute nodes, so only templates for these roles are necessary.

In this section, you use the sample NIC configuration templates generated by the process-templates.py tool and make a few changes to reflect the lab environment’s network topology:

* Configure the nic1 interface on the overcloud nodes as the interface to the undercloud control plane.
Move the control plane network to the nic1 interface.
Configure routes for the nic1 interface.
* Configure the nic2 interface as a member of the overcloud bridge.

5.1 Create a directory for the NIC configuration templates:

```
(undercloud) [stack@undercloud ~]$ mkdir -p ~/templates/nic-configs
```

5.2 Copy the suitable NIC configuration templates to the nic-configs directory:

```
(undercloud) [stack@undercloud ~]$ cp ~/output/network/config/single-nic-vlans/controller.yaml ~/templates/nic-configs/
(undercloud) [stack@undercloud ~]$ cp ~/output/network/config/single-nic-vlans/compute.yaml ~/templates/nic-configs/
```
5.3 Review the OsNetConfigImpl resource definition in the nic-configs templates:

```
(undercloud) [stack@undercloud ~]$ grep -A10 OsNetConfigImpl: templates/nic-configs/controller.yaml
```

Kind of Sample Output:

```
  OsNetConfigImpl:
    type: OS::Heat::SoftwareConfig
    properties:
      group: script
      config:
        str_replace:
          template:
            get_file: ../../scripts/run-os-net-config.sh
          params:
            $network_config:
              network_config:
```

* The resource refers to a script used to perform network configuration on overcloud nodes.
* The reference to the script uses a relative path, so it needs to be changed to the absolute path as shown below.

5.4 Modify the relative path in the controller.yaml and compute.yaml files:

```
(undercloud) [stack@undercloud ~]$ for i in controller compute; do sed 's#../../scripts/run-os-net-config.sh#/usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh#' -i templates/nic-configs/$i.yaml ; done
```
5.5 Review changes in the controller.yaml file:

```
(undercloud) [stack@undercloud ~]$ grep -A10 OsNetConfigImpl: templates/nic-configs/controller.yaml
```

Kind of Sample Output:

```
  OsNetConfigImpl:
    type: OS::Heat::SoftwareConfig
    properties:
      group: script
      config:
        str_replace:
          template:
            get_file: /usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh
          params:
            $network_config:
              network_config:
```

Note: Now the file contains the absolute path to the script.

5.6 Review the compute.yaml file:

```
(undercloud) [stack@undercloud ~]$ grep -A10 OsNetConfigImpl: templates/nic-configs/compute.yaml
```

Kind of Sample Output:

```
  OsNetConfigImpl:
    type: OS::Heat::SoftwareConfig
    properties:
      group: script
      config:
        str_replace:
          template:
            get_file: /usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh
          params:
            $network_config:
              network_config:
```

Note: This template also contains the absolute path to the script.

5.7 Modify the controller.yaml and compute.yaml templates to reflect the fact that the eth0 interface in the overcloud nodes is connected to the provisioning network used by the undercloud as its control plane and that the eth1 interface is connected to the trunk network and needs to be a member of the overcloud bridge that provides access to different VLANs used for traffic separation.

5.7.1 After the modification it should looks as follow:

```
(undercloud) [stack@undercloud ~]$ cat templates/nic-configs/controller.yaml
```

Kind of sample output:

```
heat_template_version: queens
description: >
  Software Config to drive os-net-config to configure VLANs for the Controller role.
parameters:
  ControlPlaneIp:
    default: ''
    description: IP address/subnet on the ctlplane network
    type: string
  StorageIpSubnet:
    default: ''
    description: IP address/subnet on the storage network
    type: string
  StorageMgmtIpSubnet:
    default: ''
    description: IP address/subnet on the storage_mgmt network
    type: string
  InternalApiIpSubnet:
    default: ''
    description: IP address/subnet on the internal_api network
    type: string
  TenantIpSubnet:
    default: ''
    description: IP address/subnet on the tenant network
    type: string
  ExternalIpSubnet:
    default: ''
    description: IP address/subnet on the external network
    type: string
  ManagementIpSubnet:
    default: ''
    description: IP address/subnet on the management network
    type: string
  StorageNetworkVlanID:
    default: 30
    description: Vlan ID for the storage network traffic.
    type: number
  StorageMgmtNetworkVlanID:
    default: 40
    description: Vlan ID for the storage_mgmt network traffic.
    type: number
  InternalApiNetworkVlanID:
    default: 20
    description: Vlan ID for the internal_api network traffic.
    type: number
  TenantNetworkVlanID:
    default: 50
    description: Vlan ID for the tenant network traffic.
    type: number
  ExternalNetworkVlanID:
    default: 10
    description: Vlan ID for the external network traffic.
    type: number
  ManagementNetworkVlanID:
    default: 60
    description: Vlan ID for the management network traffic.
    type: number
  ControlPlaneSubnetCidr: # Override this via parameter_defaults
    default: '24'
    description: The subnet CIDR of the control plane network.
    type: string
  ControlPlaneDefaultRoute: # Override this via parameter_defaults
    description: The default route of the control plane network.
    type: string
  ExternalInterfaceDefaultRoute:
    default: '10.0.0.1'
    description: default route for the external network
    type: string
  DnsServers: # Override this via parameter_defaults
    default: []
    description: A list of DNS servers (2 max for some implementations) that will be added to resolv.conf.
    type: comma_delimited_list
  EC2MetadataIp: # Override this via parameter_defaults
    description: The IP address of the EC2 metadata server.
    type: string
resources:
  OsNetConfigImpl:
    type: OS::Heat::SoftwareConfig
    properties:
      group: script
      config:
        str_replace:
          template:
            get_file: /usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh
          params:
            $network_config:
              network_config:
              - type: interface
                name: nic1
                use_dhcp: false
                dns_servers:
                  get_param: DnsServers
                addresses:
                - ip_netmask:
                    list_join:
                    - /
                    - - get_param: ControlPlaneIp
                      - get_param: ControlPlaneSubnetCidr
                routes:
                - ip_netmask: 169.254.169.254/32
                  next_hop:
                    get_param: EC2MetadataIp
              - type: ovs_bridge
                name: bridge_name
                use_dhcp: false
                members:
                - type: interface
                  name: nic2
                  # force the MAC address of the bridge to this interface
                  primary: true
                - type: vlan
                  vlan_id:
                    get_param: StorageNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: StorageIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: StorageMgmtNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: StorageMgmtIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: InternalApiNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: InternalApiIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: TenantNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: TenantIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: ExternalNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: ExternalIpSubnet
                  routes:
                  - default: true
                    next_hop:
                      get_param: ExternalInterfaceDefaultRoute
outputs:
  OS::stack_id:
    description: The OsNetConfigImpl resource.
    value:
      get_resource: OsNetConfigImpl
```

5.7.2 Review the compute.yaml file:

```
(undercloud) [stack@undercloud ~]$ cat templates/nic-configs/compute.yaml
```

Kind of Sample output:

```
heat_template_version: queens
description: >
  Software Config to drive os-net-config to configure VLANs for the Compute role.
parameters:
  ControlPlaneIp:
    default: ''
    description: IP address/subnet on the ctlplane network
    type: string
  StorageIpSubnet:
    default: ''
    description: IP address/subnet on the storage network
    type: string
  StorageMgmtIpSubnet:
    default: ''
    description: IP address/subnet on the storage_mgmt network
    type: string
  InternalApiIpSubnet:
    default: ''
    description: IP address/subnet on the internal_api network
    type: string
  TenantIpSubnet:
    default: ''
    description: IP address/subnet on the tenant network
    type: string
  ExternalIpSubnet:
    default: ''
    description: IP address/subnet on the external network
    type: string
  ManagementIpSubnet:
    default: ''
    description: IP address/subnet on the management network
    type: string
  StorageNetworkVlanID:
    default: 30
    description: Vlan ID for the storage network traffic.
    type: number
  StorageMgmtNetworkVlanID:
    default: 40
    description: Vlan ID for the storage_mgmt network traffic.
    type: number
  InternalApiNetworkVlanID:
    default: 20
    description: Vlan ID for the internal_api network traffic.
    type: number
  TenantNetworkVlanID:
    default: 50
    description: Vlan ID for the tenant network traffic.
    type: number
  ExternalNetworkVlanID:
    default: 10
    description: Vlan ID for the external network traffic.
    type: number
  ManagementNetworkVlanID:
    default: 60
    description: Vlan ID for the management network traffic.
    type: number
  ControlPlaneSubnetCidr: # Override this via parameter_defaults
    default: '24'
    description: The subnet CIDR of the control plane network.
    type: string
  ControlPlaneDefaultRoute: # Override this via parameter_defaults
    description: The default route of the control plane network.
    type: string
  ExternalInterfaceDefaultRoute:
    default: '10.0.0.1'
    description: default route for the external network
    type: string
  DnsServers: # Override this via parameter_defaults
    default: []
    description: A list of DNS servers (2 max for some implementations) that will be added to resolv.conf.
    type: comma_delimited_list
  EC2MetadataIp: # Override this via parameter_defaults
    description: The IP address of the EC2 metadata server.
    type: string
resources:
  OsNetConfigImpl:
    type: OS::Heat::SoftwareConfig
    properties:
      group: script
      config:
        str_replace:
          template:
            get_file: /usr/share/openstack-tripleo-heat-templates/network/scripts/run-os-net-config.sh
          params:
            $network_config:
              network_config:
              - type: interface
                name: nic1
                use_dhcp: false
                dns_servers:
                  get_param: DnsServers
                addresses:
                - ip_netmask:
                    list_join:
                    - /
                    - - get_param: ControlPlaneIp
                      - get_param: ControlPlaneSubnetCidr
                routes:
                - ip_netmask: 169.254.169.254/32
                  next_hop:
                    get_param: EC2MetadataIp
                - default: true
                  next_hop:
                    get_param: ControlPlaneDefaultRoute
              - type: ovs_bridge
                name: bridge_name
                use_dhcp: false
                members:
                - type: interface
                  name: nic2
                  # force the MAC address of the bridge to this interface
                  primary: true
                - type: vlan
                  vlan_id:
                    get_param: StorageNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: StorageIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: InternalApiNetworkVlanID
                  addresses:
                  - ip_netmask:
                      get_param: InternalApiIpSubnet
                - type: vlan
                  vlan_id:
                    get_param: TenantNetworkVlanID
                  addresses:
                  - ip_n
```
