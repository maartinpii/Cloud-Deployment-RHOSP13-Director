# Test Instance Launching

## Objectives

* Configure networks, subnets, and a router in overcloud
* Create a flavor, modify the default security group, and upload an image
* Launch a test instance
* Assign a floating IP to test connectivity with the instance

1. Configure Overcloud Network

Note: Before launching an instance, the necessary virtual network infrastructure must be created.

1.1 Log in to the overcloud controller:

```
(undercloud) [stack@undercloud ~]$ ssh heat-admin@<controller node IP address>
```
1.2 Source the overcloudrc file:

```
[heat-admin@overcloud-controller-0 ~]$ source ~/overcloudrc
```

1.3 Create a tenant network named default in the overcloud:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack network create default
```

Kind of Sample Output:
```
+---------------------------+--------------------------------------+
| Field                     | Value                                |
+---------------------------+--------------------------------------+
| admin_state_up            | UP                                   |
| availability_zone_hints   |                                      |
| availability_zones        |                                      |
| created_at                | 2018-07-10T14:12:14Z                 |
| description               |                                      |
| dns_domain                | None                                 |
| id                        | 5ccd17a8-fce0-4510-8434-608da9311801 |
| ipv4_address_scope        | None                                 |
| ipv6_address_scope        | None                                 |
| is_default                | False                                |
| is_vlan_transparent       | None                                 |
| mtu                       | 1442                                 |
| name                      | default                              |
| port_security_enabled     | True                                 |
| project_id                | 3092b7d5c72d436eaf160bfc59b947aa     |
| provider:network_type     | geneve                               |
| provider:physical_network | None                                 |
| provider:segmentation_id  | 46                                   |
| qos_policy_id             | None                                 |
| revision_number           | 3                                    |
| router:external           | Internal                             |
| segments                  | None                                 |
| shared                    | False                                |
| status                    | ACTIVE                               |
| subnets                   |                                      |
| tags                      |                                      |
| updated_at                | 2018-07-10T14:12:14Z                 |
+---------------------------+--------------------------------------+
```

1.4 Create a subnet for the newly created default network:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack subnet create \
  --network default \
  --dns-nameserver 8.8.4.4 --gateway 172.16.1.1 \
  --subnet-range 172.16.1.0/24 default
```

Kind of Sample Output:

```
+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| allocation_pools  | 172.16.1.2-172.16.1.254              |
| cidr              | 172.16.1.0/24                        |
| created_at        | 2018-07-10T14:12:50Z                 |
| description       |                                      |
| dns_nameservers   | 8.8.4.4                              |
| enable_dhcp       | True                                 |
| gateway_ip        | 172.16.1.1                           |
| host_routes       |                                      |
| id                | 23f7a57b-21ae-465f-9c1a-60833730d6b2 |
| ip_version        | 4                                    |
| ipv6_address_mode | None                                 |
| ipv6_ra_mode      | None                                 |
| name              | default                              |
| network_id        | 5ccd17a8-fce0-4510-8434-608da9311801 |
| project_id        | 3092b7d5c72d436eaf160bfc59b947aa     |
| revision_number   | 0                                    |
| segment_id        | None                                 |
| service_types     |                                      |
| subnetpool_id     | None                                 |
| tags              |                                      |
| updated_at        | 2018-07-10T14:12:50Z                 |
+-------------------+--------------------------------------+
```

1.5 Confirm that the network was created:


```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack network list
```

Kind of Sample Output:

```
+--------------------------------------+---------+--------------------------------------+
| ID                                   | Name    | Subnets                              |
+--------------------------------------+---------+--------------------------------------+
| 5ccd17a8-fce0-4510-8434-608da9311801 | default | 23f7a57b-21ae-465f-9c1a-60833730d6b2 |
+--------------------------------------+---------+--------------------------------------+
```

1.6 Create an external network called public—for the environment, the external network is implemented as VLAN 10 over the datacentre physical network:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack network create public \
  --share --external --provider-physical-network datacentre \
  --provider-network-type vlan --provider-segment 10
```

Kind of Sample Output:

```
+---------------------------+--------------------------------------+
| Field                     | Value                                |
+---------------------------+--------------------------------------+
| admin_state_up            | UP                                   |
| availability_zone_hints   |                                      |
| availability_zones        |                                      |
| created_at                | 2018-07-10T14:14:03Z                 |
| description               |                                      |
| dns_domain                | None                                 |
| id                        | c6b21020-d67f-4eba-a49d-235cbcef4088 |
| ipv4_address_scope        | None                                 |
| ipv6_address_scope        | None                                 |
| is_default                | False                                |
| is_vlan_transparent       | None                                 |
| mtu                       | 1500                                 |
| name                      | public                               |
| port_security_enabled     | True                                 |
| project_id                | 3092b7d5c72d436eaf160bfc59b947aa     |
| provider:network_type     | vlan                                 |
| provider:physical_network | datacentre                           |
| provider:segmentation_id  | 10                                   |
| qos_policy_id             | None                                 |
| revision_number           | 6                                    |
| router:external           | External                             |
| segments                  | None                                 |
| shared                    | True                                 |
| status                    | ACTIVE                               |
| subnets                   |                                      |
| tags                      |                                      |
| updated_at                | 2018-07-10T14:14:03Z                 |
+---------------------------+--------------------------------------+

```

1.7 Create a subnet on the public network, using this command to match the subnet parameters to the actual subnet range and gateway IP address in the environment:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack subnet create public \
  --no-dhcp --network public --subnet-range 10.0.0.0/24 \
  --allocation-pool start=10.0.0.100,end=10.0.0.200  \
  --gateway 10.0.0.1 --dns-nameserver 8.8.8.8
```

```
+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| allocation_pools  | 10.0.0.100-10.0.0.200                |
| cidr              | 10.0.0.0/24                          |
| created_at        | 2018-07-10T14:14:58Z                 |
| description       |                                      |
| dns_nameservers   | 8.8.8.8                              |
| enable_dhcp       | False                                |
| gateway_ip        | 10.0.0.1                             |
| host_routes       |                                      |
| id                | 09203288-8a54-4893-a54f-6e6d70d43efe |
| ip_version        | 4                                    |
| ipv6_address_mode | None                                 |
| ipv6_ra_mode      | None                                 |
| name              | public                               |
| network_id        | c6b21020-d67f-4eba-a49d-235cbcef4088 |
| project_id        | 3092b7d5c72d436eaf160bfc59b947aa     |
| revision_number   | 0                                    |
| segment_id        | None                                 |
| service_types     |                                      |
| subnetpool_id     | None                                 |
| tags              |                                      |
| updated_at        | 2018-07-10T14:14:58Z                 |
+-------------------+--------------------------------------+
```

1.8 Confirm that the public network exists:


```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack network list
```

Kind of Sample Output:

```
+--------------------------------------+---------+--------------------------------------+
| ID                                   | Name    | Subnets                              |
+--------------------------------------+---------+--------------------------------------+
| 5ccd17a8-fce0-4510-8434-608da9311801 | default | 23f7a57b-21ae-465f-9c1a-60833730d6b2 |
| c6b21020-d67f-4eba-a49d-235cbcef4088 | public  | 09203288-8a54-4893-a54f-6e6d70d43efe |
+--------------------------------------+---------+--------------------------------------+
```

1.9 List the available subnets:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack subnet list
```

Kind of Sample Output:

```
+--------------------------------------+---------+--------------------------------------+---------------+
| ID                                   | Name    | Network                              | Subnet        |
+--------------------------------------+---------+--------------------------------------+---------------+
| 09203288-8a54-4893-a54f-6e6d70d43efe | public  | c6b21020-d67f-4eba-a49d-235cbcef4088 | 10.0.0.0/24   |
| 23f7a57b-21ae-465f-9c1a-60833730d6b2 | default | 5ccd17a8-fce0-4510-8434-608da9311801 | 172.16.1.0/24 |
+--------------------------------------+---------+--------------------------------------+---------------+
```
1.10 Create a virtual router:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack router create router1
```

Kind of Sample Output:

```
+-------------------------+--------------------------------------+
| Field                   | Value                                |
+-------------------------+--------------------------------------+
| admin_state_up          | UP                                   |
| availability_zone_hints | None                                 |
| availability_zones      | None                                 |
| created_at              | 2018-07-10T14:16:14Z                 |
| description             |                                      |
| distributed             | False                                |
| external_gateway_info   | None                                 |
| flavor_id               | None                                 |
| ha                      | False                                |
| id                      | 2330d6e4-96db-46c7-91ab-7c79868c8ae9 |
| name                    | router1                              |
| project_id              | 3092b7d5c72d436eaf160bfc59b947aa     |
| revision_number         | 0                                    |
| routes                  |                                      |
| status                  | ACTIVE                               |
| tags                    |                                      |
| updated_at              | 2018-07-10T14:16:14Z                 |
+-------------------------+--------------------------------------+
```
1.11 Add the default subnet to the router:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack router add subnet router1 default
```

1.12 Set router1 as a gateway to the public network:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack router set router1 --external-gateway public
```

1.13 Verify that the router has fixed IP addresses on the public and default subnets:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack port list --router=router1
```

Kind of Sample Output:

```
+--------------------------------------+------+-------------------+---------------------------------------------------------------------------+--------+
| ID                                   | Name | MAC Address       | Fixed IP Addresses                                                        | Status |
+--------------------------------------+------+-------------------+---------------------------------------------------------------------------+--------+
| 724aa760-45ab-49c1-a90e-5cd447aac4c5 |      | fa:16:3e:8d:90:73 | ip_address='10.0.0.108', subnet_id='09203288-8a54-4893-a54f-6e6d70d43efe' | DOWN   |
| a9114b60-c75e-4d61-bdb6-2e490ce1f854 |      | fa:16:3e:5a:bd:b8 | ip_address='172.16.1.1', subnet_id='23f7a57b-21ae-465f-9c1a-60833730d6b2' | DOWN   |
+--------------------------------------+------+-------------------+---------------------------------------------------------------------------+--------+
```

2. Create Flavor, Modify Security Group, and Upload Image

2.1 Create Flavor in Overcloud

2.1.1 Create a custom flavor with one vCPU and 64 MB of memory:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack flavor create m1.nano \
  --id 0 --vcpus 1 --ram 64 --disk 1
```

Kind of Sample Output:

```
+----------------------------+---------+
| Field                      | Value   |
+----------------------------+---------+
| OS-FLV-DISABLED:disabled   | False   |
| OS-FLV-EXT-DATA:ephemeral  | 0       |
| disk                       | 1       |
| id                         | 0       |
| name                       | m1.nano |
| os-flavor-access:is_public | True    |
| properties                 |         |
| ram                        | 64      |
| rxtx_factor                | 1.0     |
| swap                       |         |
| vcpus                      | 1       |
+----------------------------+---------+
```

2.2 Modify Default Security Group in Overcloud

2.2.1 Confirm the presence of the default security group:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack security group list
```

Kind of Sample Output:

```
+--------------------------------------+---------+------------------------+----------------------------------+
| ID                                   | Name    | Description            | Project                          |
+--------------------------------------+---------+------------------------+----------------------------------+
| 081cbed6-fcf7-40ee-b7f5-f248f56752fb | default | Default security group |                                  |
| 2bcf5b07-907d-486e-85f7-f90915f5f029 | default | Default security group | 3092b7d5c72d436eaf160bfc59b947aa |
+--------------------------------------+---------+------------------------+----------------------------------+
```

2.2.2 List the projects defined in the overcloud:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack project list
```

Kind of Sample Output:

```
+----------------------------------+---------+
| ID                               | Name    |
+----------------------------------+---------+
| 3092b7d5c72d436eaf160bfc59b947aa | admin   |
| 4c1288e9bd424e05b2aac8287aaf2386 | service |
+----------------------------------+---------+
```

Note:  the admin project’s ID is the one to use the default security group that belongs to this project.

2.2.3 Save the ID of the default security group that belongs to the admin project in the sg_id variable:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ sg_id=$(openstack security group list | grep $(openstack project show admin -f value -c id) | awk '{ print $2 }')
```

2.2.4 Using the security group ID saved in the sg_id variable, create a rule that allows pinging cloud instances:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack security group \
  rule create --proto icmp $sg_id
```

Kind of Sample Output:

```
+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| created_at        | 2018-07-10T14:20:36Z                 |
| description       |                                      |
| direction         | ingress                              |
| ether_type        | IPv4                                 |
| id                | f6473427-177a-40ae-85a1-64b33a58aa79 |
| name              | None                                 |
| port_range_max    | None                                 |
| port_range_min    | None                                 |
| project_id        | 3092b7d5c72d436eaf160bfc59b947aa     |
| protocol          | icmp                                 |
| remote_group_id   | None                                 |
| remote_ip_prefix  | 0.0.0.0/0                            |
| revision_number   | 0                                    |
| security_group_id | 2bcf5b07-907d-486e-85f7-f90915f5f029 |
| updated_at        | 2018-07-10T14:20:36Z                 |
+-------------------+--------------------------------------+
```

2.2.5 Create a rule allowing SSH access to cloud instances:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack security group \
  rule create --dst-port 22 $sg_id
```

2.3 Upload Image

2.3.1 Download the cirros image:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ curl -O http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
```
2.3.2   Upload the cirros image file to the overcloud Glance repository:

```

(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack image create cirros \
  --file cirros-0.4.0-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public
```

Kind of Sample Output:

```
+------------------+------------------------------------------------------------------------------+
| Field            | Value                                                                        |
+------------------+------------------------------------------------------------------------------+
| checksum         | 443b7623e27ecf03dc9e01ee93f67afe                                             |
| container_format | bare                                                                         |
| created_at       | 2018-07-10T14:22:02Z                                                         |
| disk_format      | qcow2                                                                        |
| file             | /v2/images/0947fca2-d641-499e-a33f-63f3922c942e/file                         |
| id               | 0947fca2-d641-499e-a33f-63f3922c942e                                         |
| min_disk         | 0                                                                            |
| min_ram          | 0                                                                            |
| name             | cirros                                                                       |
| owner            | 3092b7d5c72d436eaf160bfc59b947aa                                             |
| properties       | direct_url='swift+config://ref1/glance/0947fca2-d641-499e-a33f-63f3922c942e' |
| protected        | False                                                                        |
| schema           | /v2/schemas/image                                                            |
| size             | 12716032                                                                     |
| status           | active                                                                       |
| tags             |                                                                              |
| updated_at       | 2018-07-10T14:22:04Z                                                         |
| virtual_size     | None                                                                         |
| visibility       | public                                                                       |
+------------------+------------------------------------------------------------------------------+
```

3. Launch Test Instance

3.1.1 Create the test-instance using the flavor, image, network, and security group defined earlier:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack server create test-instance \
  --flavor m1.nano --image cirros --nic net-id=default
```

Kind of Sample Output:

```
+-------------------------------------+-----------------------------------------------+
| Field                               | Value                                         |
+-------------------------------------+-----------------------------------------------+
| OS-DCF:diskConfig                   | MANUAL                                        |
| OS-EXT-AZ:availability_zone         |                                               |
| OS-EXT-SRV-ATTR:host                | None                                          |
| OS-EXT-SRV-ATTR:hypervisor_registry.access.redhat.com | None                                          |
| OS-EXT-SRV-ATTR:instance_name       |                                               |
| OS-EXT-STS:power_state              | NOSTATE                                       |
| OS-EXT-STS:task_state               | scheduling                                    |
| OS-EXT-STS:vm_state                 | building                                      |
| OS-SRV-USG:launched_at              | None                                          |
| OS-SRV-USG:terminated_at            | None                                          |
| accessIPv4                          |                                               |
| accessIPv6                          |                                               |
| addresses                           |                                               |
| adminPass                           | 92cWrTcmyS8J                                  |
| config_drive                        |                                               |
| created                             | 2018-07-10T14:22:44Z                          |
| flavor                              | m1.nano (0)                                   |
| hostId                              |                                               |
| id                                  | 781f2972-3dde-4028-a403-e981c8b5ad04          |
| image                               | cirros (0947fca2-d641-499e-a33f-63f3922c942e) |
| key_name                            | None                                          |
| name                                | test-instance                                 |
| progress                            | 0                                             |
| project_id                          | 3092b7d5c72d436eaf160bfc59b947aa              |
| properties                          |                                               |
| security_groups                     | name='default'                                |
| status                              | BUILD                                         |
| updated                             | 2018-07-10T14:22:45Z                          |
| user_id                             | 3ef124e7c80c4851a6febb91d859e0cf              |
| volumes_attached                    |                                               |
+-------------------------------------+-----------------------------------------------+
```

3.1.2 Verify the status of test-instance:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack server list
```

Kind of Sample Output:

```
+--------------------------------------+---------------+--------+---------------------+--------+---------+
| ID                                   | Name          | Status | Networks            | Image  | Flavor  |
+--------------------------------------+---------------+--------+---------------------+--------+---------+
| 781f2972-3dde-4028-a403-e981c8b5ad04 | test-instance | ACTIVE | default=172.16.1.12 | cirros | m1.nano |
+--------------------------------------+---------------+--------+---------------------+--------+---------+
```

Note: Wait until the instance is in the ACTIVE state.


3.1.3 print the console log of the instance when it is ACTIVE:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack console log show test-instance
```

Kind of Sample Output:

```
...
login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
test-instance login: /dev/root resized successfully [took 0.42s]
```

3.2 Assign Floating IP Address to Test Instance

3.2.1 Create a floating IP address from the floating IP allocation pool defined for the public network:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack floating ip create public
```

Kind of Sample Output:

```
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| created_at          | 2018-07-10T14:24:43Z                 |
| description         |                                      |
| fixed_ip_address    | None                                 |
| floating_ip_address | 10.0.0.100                           |
| floating_network_id | c6b21020-d67f-4eba-a49d-235cbcef4088 |
| id                  | fc4749ef-fe04-432c-b7f8-2539952e1e31 |
| name                | 10.0.0.100                           |
| port_id             | None                                 |
| project_id          | 3092b7d5c72d436eaf160bfc59b947aa     |
| qos_policy_id       | None                                 |
| revision_number     | 0                                    |
| router_id           | None                                 |
| status              | DOWN                                 |
| subnet_id           | None                                 |
| updated_at          | 2018-07-10T14:24:43Z                 |
+---------------------+--------------------------------------+
```

3.2.2 List the floating IP addresses:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack floating ip list
```

Kind of Sample Output:

```
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
| ID                                   | Floating IP Address | Fixed IP Address | Port | Floating Network                     | Project                          |
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
| fc4749ef-fe04-432c-b7f8-2539952e1e31 | 10.0.0.100          | None             | None | c6b21020-d67f-4eba-a49d-235cbcef4088 | 3092b7d5c72d436eaf160bfc59b947aa |
+--------------------------------------+---------------------+------------------+------+--------------------------------------+----------------------------------+
```

3.2.3 Assign the floating IP address that you just created to the test instance:

```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack server add floating ip test-instance 10.0.0.100
```

3.2.4 Verify


```
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack server show test-instance -f json -c addresses
```

Expected output:

```
{
  "addresses": "default=172.16.1.12, 10.0.0.100"
}
```

3.3 Connect to Test Instance

From a node inside the vLAN 10, verify that the floating IP address allocated to the instance works as expected.

```
[user@nodeInsideVLAN10 ~]$ ping -c3 10.0.0.100
```

Note: OVN may take some time to establish a data path to the instance. It may cause a loss of the first packet in the packet stream. You should not see any packet loss if you ping the instance again.

3.3.1 Connect to the instance using the floating ip

```
[user@nodeInsideVLAN10 ~]$ ssh  cirros@10.0.0.100
```

3.3.2 Check the /etc/resolv.conf file in the test-instance:


```
$ cat /etc/resolv.conf
```

Expected Output:

```
nameserver 8.8.4.4
```

Note: the nameserver with the same IP address that you used in the dns-nameserver parameter when you created the default subnet (8.8.4.4).

3.3.3 Check connectivity from the instance to the Internet:

```
$ ping -c3 google.com
```

Note: This confirms that overcloud has been successfully installed and configured.
