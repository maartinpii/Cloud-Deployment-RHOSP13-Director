# Undercloud Installation

## Architecture

                                                __   _
                                              _(  )_( )_
                                              (_   _    _)  Internet
                                              (_) (__)
                                                  |
                                                  |
                                                 |\/| Router
              ____________                       |/\|
              |undercloud|                       ----
              |__________|                       |  |
          eth0  |       | eth1                   |  |
     ___________|_______|________________________|  |  provisioning network
                   |    |     |                |    |
           ________|____|_____|________________|____|  data center network
             |     |          |      |         |   |
      _______|_____|__   _____|______|____   __|___|__________
      |              |   |               |   |               |
      |______________|   |_______________|   |_______________|
                   Controllers and Compute Nodes

## Objectives

* Test network connectivity and settings
* Create a non-root installation user
* Set a hostname for the undercloud
* Verify software channels
* Install software packages
* Configure the undercloud
* Install the undercloud
* Verify the undercloud installation
* Configure the undercloud’s Neutron subnet

### Under Cloud First Tasks

1. Validate undercloud Network

1.1 Log In to undercloud VM and validate Network connectivity to the data center and provisioning network

```
$ ssh accout@undercloud

$ sudo -i

# Check hostname
[root@undercloud ~]# hostnamectl --static status

# Check ip addresses
[root@undercloud ~]# ip a

# Check Network Interfaces
[root@undercloud ~]# cat /etc/sysconfig/network-scripts/ifcfg-eth0

# Verify Network Resolution and Internet Connectivity
[root@undercloud ~]# ping -c1 www.google.com
```

2. Create Non-Root Installation User

2.1 Create a user on the undercloud node called stack:

```
[root@undercloud ~]# useradd stack
```

2.2 Configure SSH authentication for the stack user using the root user’s authorized_keys file as a template:

```
[root@undercloud ~]# mkdir /home/stack/.ssh
[root@undercloud ~]# cp /root/.ssh/authorized_keys /home/stack/.ssh/
[root@undercloud ~]# chown -R stack:stack /home/stack/.ssh
```

2.3 Create a sudo rule allowing the stack user to run any command as root without requiring a password:

```
[root@undercloud ~]# echo 'stack ALL=(root) NOPASSWD:ALL' | tee -a /etc/sudoers.d/stack
```

2.4 Set the correct permissions on the stack user’s sudo rule file:

```
[root@undercloud ~]# chmod 0440 /etc/sudoers.d/stack
```

3. Set and Verify Software Channels

3.1 Register the undercloud

```
[stack@undercloud ~]$ sudo subscription-manager register
```

3.2 Find the entitlement pool ID for Red Hat OpenStack Platform director. For example:

```
[stack@undercloud ~]$ sudo subscription-manager list --available --all --matches="Red Hat OpenStack"
Subscription Name:   Name of SKU
Provides:            Red Hat Single Sign-On
                     Red Hat Enterprise Linux Workstation
                     Red Hat CloudForms
                     Red Hat OpenStack
                     Red Hat Software Collections (for RHEL Workstation)
                     Red Hat Virtualization
SKU:                 SKU-Number
Contract:            Contract-Number
Pool ID:             Valid-Pool-Number-123456
Provides Management: Yes
Available:           1
Suggested:           1
Service Level:       Support-level
Service Type:        Service-Type
Subscription Type:   Sub-type
Ends:                End-date
System Type:         Physical
```

3.3 Locate the Pool ID value and attach the Red Hat OpenStack Platform 13 entitlement:

```
[stack@undercloud ~]$ sudo subscription-manager attach --pool=Valid-Pool-Number-123456
```

3.4 Disable all default repositories, and then enable the required Red Hat Enterprise Linux repositories:

```
[stack@undercloud ~]$ sudo subscription-manager repos --disable=*
[stack@undercloud ~]$ sudo subscription-manager repos --enable=rhel-7-server-rpms --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-rh-common-rpms --enable=rhel-ha-for-rhel-7-server-rpms --enable=rhel-7-server-openstack-13-rpms
```

3.5 Perform an update on your system to make sure you have the latest base system packages:

```
[stack@undercloud ~]$ sudo yum update -y
[stack@undercloud ~]$ sudo reboot
```

4. Install Software Packages

4.1 Install the required command line tools for the director’s installation and configuration:

```
[root@undercloud ~]# yum -y install python-tripleoclient
```

4.2 If you aim to create an overcloud with Ceph Storage nodes, install the additional ceph-ansible package:

```
[root@undercloud ~]$  yum install -y ceph-ansible
```

5. Configure Undercloud Installation

The OpenStack Platform director’s installation process requires certain settings to determine your network configurations. The settings are stored in the undercloud.conf file in the stack user’s home directory. Red Hat provides a sample template (/usr/share/instack-undercloud/undercloud.conf.sample) to help determine the required settings and default values for your installation.

5.1 Log in to the undercloud node as the stack user

5.2 Create the undercloud.conf file in the /home/stack directory with the following content:

```
[DEFAULT]
undercloud_hostname = undercloud.example.com
local_ip = 192.0.2.1/24
undercloud_public_host = 192.0.2.2
undercloud_admin_host = 192.0.2.3
undercloud_nameservers = 192.0.2.254
#undercloud_ntp_servers =
#overcloud_domain_name = example.com
subnets = ctlplane-subnet
local_subnet = ctlplane-subnet
#undercloud_service_certificate =
generate_service_certificate = true
certificate_generation_ca = local
local_interface = eth0
inspection_extras = false
undercloud_debug = false
enable_tempest = false
enable_ui = false

[auth]

[ctlplane-subnet]
cidr = 192.0.2.0/24
dhcp_start = 192.0.2.5
dhcp_end = 192.0.2.24
inspection_iprange = 192.0.2.100,192.0.2.120
gateway = 192.0.2.254
```


* For the full set of options, check [Director Installation and Usage] (https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html-single/director_installation_and_usage/index)


6. Install Undercloud and Verify Installation

6.1 Install the undercloud

```
[stack@undercloud ~]$ openstack undercloud install
```

6.2 Examine the log messages to make sure that there are no errors and that you see confirmation of the successful installation

6.3 Review the contents of the two files that the installation process created in the stack user’s home directory:

```
[stack@undercloud ~]$ cat ~/stackrc
[stack@undercloud ~]$ cat ~/undercloud-passwords.conf
```

6.4 Review the undercloud catalog to confirm successful installation of the undercloud:

```
[stack@undercloud ~]$ source ~/stackrc

(undercloud) [stack@undercloud ~]$ openstack catalog list

Kind of Sample output:

+------------------+-------------------------+----------------------------------------------------------------------------+
| Name             | Type                    | Endpoints                                                                  |
+------------------+-------------------------+----------------------------------------------------------------------------+
| zaqar            | messaging               | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8888                                             |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13888                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8888                                          |
|                  |                         |                                                                            |
| glance           | image                   | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13292                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:9292                                             |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:9292                                          |
|                  |                         |                                                                            |
| ironic-inspector | baremetal-introspection | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:5050                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13050                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:5050                                             |
|                  |                         |                                                                            |
| heat             | orchestration           | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8004/v1/a4dd704102e545d8af2616ac9a1cdbdf         |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13004/v1/a4dd704102e545d8af2616ac9a1cdbdf      |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8004/v1/a4dd704102e545d8af2616ac9a1cdbdf      |
|                  |                         |                                                                            |
| neutron          | network                 | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:9696                                             |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:9696                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13696                                          |
|                  |                         |                                                                            |
| swift            | object-store            | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8080                                             |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13808/v1/AUTH_a4dd704102e545d8af2616ac9a1cdbdf |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8080/v1/AUTH_a4dd704102e545d8af2616ac9a1cdbdf |
|                  |                         |                                                                            |
| heat-cfn         | cloudformation          | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8000/v1/a4dd704102e545d8af2616ac9a1cdbdf      |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13800/v1/a4dd704102e545d8af2616ac9a1cdbdf      |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8000/v1/a4dd704102e545d8af2616ac9a1cdbdf         |
|                  |                         |                                                                            |
| nova             | compute                 | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13774/v2.1                                     |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8774/v2.1                                        |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8774/v2.1                                     |
|                  |                         |                                                                            |
| zaqar-websocket  | messaging-websocket     | regionOne                                                                  |
|                  |                         |   admin: ws://192.0.2.3:9000                                               |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: wss://192.0.2.2:9000                                             |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: ws://192.0.2.3:9000                                            |
|                  |                         |                                                                            |
| ironic           | baremetal               | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:6385                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13385                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:6385                                             |
|                  |                         |                                                                            |
| keystone         | identity                | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:5000                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:35357                                            |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13000                                          |
|                  |                         |                                                                            |
| placement        | placement               | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8778/placement                                |
|                  |                         | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8778/placement                                   |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13778/placement                                |
|                  |                         |                                                                            |
| mistral          | workflowv2              | regionOne                                                                  |
|                  |                         |   admin: http://192.0.2.3:8989/v2                                          |
|                  |                         | regionOne                                                                  |
|                  |                         |   internal: http://192.0.2.3:8989/v2                                       |
|                  |                         | regionOne                                                                  |
|                  |                         |   public: https://192.0.2.2:13989/v2                                       |
|                  |                         |                                                                            |
+------------------+-------------------------+----------------------------------------------------------------------
```

Note: If there are issues, check the installation log - /home/stack/.instack/install-undercloud.log


7. Review Network Configuration Changes

7.1 Display the undercloud host’s IP addresses:

```
(undercloud) [stack@undercloud ~]$ ip a
```

Kind of Sample Output:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast master ovs-system state UP group default qlen 1000
    link/ether 2c:c2:60:01:01:01 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::2ec2:60ff:fe01:101/64 scope link
       valid_lft forever preferred_lft forever
3: ovs-system: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether fe:98:35:ef:98:3e brd ff:ff:ff:ff:ff:ff
4: br-ctlplane: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 2c:c2:60:01:01:01 brd ff:ff:ff:ff:ff:ff
    inet 192.0.2.1/24 brd 192.0.2.255 scope global br-ctlplane
       valid_lft forever preferred_lft forever
    inet 192.0.2.3/32 scope global br-ctlplane
       valid_lft forever preferred_lft forever
    inet 192.0.2.2/32 scope global br-ctlplane
       valid_lft forever preferred_lft forever
    inet6 fe80::2ec2:60ff:fe01:101/64 scope link
       valid_lft forever preferred_lft forever
5: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:05:d6:2b:db brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
6: br-int: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 8a:88:f1:b5:60:42 brd ff:ff:ff:ff:ff:ff
```

7.2 Examine the network routes:

```
(undercloud) [stack@undercloud ~]$ ip r
```

Kind of Sample Output
```
169.254.0.0/16 dev eth0 scope link metric 1002
169.254.0.0/16 dev br-ctlplane scope link metric 1004
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
192.0.2.0/24 dev br-ctlplane proto kernel scope link src 192.0.2.1
```
7.3 Examine the Open vSwitch database:

```
(undercloud) [stack@undercloud ~]$ sudo ovs-vsctl show
```
Kind of Sample Output

```
f17f9d67-2aee-4a88-badb-cc4134957a79
    Manager "ptcp:6640:127.0.0.1"
        is_connected: true
    Bridge br-ctlplane
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
        Port phy-br-ctlplane
            Interface phy-br-ctlplane
                type: patch
                options: {peer=int-br-ctlplane}
        Port br-ctlplane
            Interface br-ctlplane
                type: internal
        Port "eth0"
            Interface "eth0"
    Bridge br-int
        Controller "tcp:127.0.0.1:6633"
            is_connected: true
        fail_mode: secure
        Port int-br-ctlplane
            Interface int-br-ctlplane
                type: patch
                options: {peer=phy-br-ctlplane}
        Port "tapb4231c3a-eb"
            tag: 1
            Interface "tapb4231c3a-eb"
                type: internal
        Port br-int
            Interface br-int
                type: internal
    ovs_version: "2.9.0"
```

7.4 Examine the OpenStack network configuration parameters:

```
(undercloud) [stack@undercloud ~]$ cat /etc/os-net-config/config.json | python -m json.tool
```

Kind of Sample Output

```
{
    "network_config": [
        {
            "addresses": [
                {
                    "ip_netmask": "192.0.2.1/24"
                }
            ],
            "members": [
                {
                    "dns_servers": [
                        "192.0.2.254"
                    ],
                    "mtu": 1500,
                    "name": "eth0",
                    "primary": "true",
                    "type": "interface"
                }
            ],
            "mtu": 1500,
            "name": "br-ctlplane",
            "ovs_extra": [
                "br-set-external-id br-ctlplane bridge-id br-ctlplane"
            ],
            "routes": [],
            "type": "ovs_bridge"
        }
    ]
}
```

8. Configure Undercloud Neutron Subnet

Overcloud nodes require a nameserver so that they can resolve hostnames through DNS. For a standard overcloud without network isolation, the nameserver is defined using the undercloud’s Neutron subnet. In this section, you define the nameserver for the environment.

8.1 List the undercloud networks

```
(undercloud) [stack@undercloud ~]$ openstack network list
```

Kind of Sample Output

```
+--------------------------------------+----------+--------------------------------------+
| ID                                   | Name     | Subnets                              |
+--------------------------------------+----------+--------------------------------------+
| fa36cd0f-4e94-426b-9070-a7ad55f168bd | ctlplane | 88dc4ae7-5b69-44fd-a67d-a08be7306796 |
+--------------------------------------+----------+--------------------------------------+
```

8.2 List the undercloud subnets:

```
(undercloud) [stack@undercloud ~]$ openstack subnet list
```

Kind of Sample Output
```
+--------------------------------------+-----------------+--------------------------------------+--------------+
| ID                                   | Name            | Network                              | Subnet       |
+--------------------------------------+-----------------+--------------------------------------+--------------+
| 88dc4ae7-5b69-44fd-a67d-a08be7306796 | ctlplane-subnet | fa36cd0f-4e94-426b-9070-a7ad55f168bd | 192.0.2.0/24 |
+--------------------------------------+-----------------+--------------------------------------+--------------+
```

8.3 Examine the subnet details:

```
(undercloud) [stack@undercloud ~]$ openstack subnet show ctlplane-subnet
```


Kind of Sample Output

```
+-------------------+-------------------------------------------------------+
| Field             | Value                                                 |
+-------------------+-------------------------------------------------------+
| allocation_pools  | 192.0.2.5-192.0.2.24                                  |
| cidr              | 192.0.2.0/24                                          |
| created_at        | 2018-05-17T17:12:46Z                                  |
| description       |                                                       |
| dns_nameservers   |                                                       |
| enable_dhcp       | True                                                  |
| gateway_ip        | 192.0.2.254                                           |
| host_routes       | destination='169.254.169.254/32', gateway='192.0.2.1' |
| id                | 88dc4ae7-5b69-44fd-a67d-a08be7306796                  |
| ip_version        | 4                                                     |
| ipv6_address_mode | None                                                  |
| ipv6_ra_mode      | None                                                  |
| name              | ctlplane-subnet                                       |
| network_id        | fa36cd0f-4e94-426b-9070-a7ad55f168bd                  |
| project_id        | bc1e8eb45ca142d79804f33516158ed2                      |
| revision_number   | 0                                                     |
| segment_id        | None                                                  |
| service_types     |                                                       |
| subnetpool_id     | None                                                  |
| tags              |                                                       |
| updated_at        | 2018-05-17T17:12:46Z                                  |
+-------------------+-------------------------------------------------------+
```

8.4 Configure the DNS nameserver for the subnet:

```
(undercloud) [stack@undercloud ~]$ openstack subnet set ctlplane-subnet --dns-nameserver 192.0.2.254
```
