# Overcloud Deployment

## Objectives

* Deploy the overcloud
* Review the overcloud deployment

1. Deploy Overcloud

1.1 Create a script containing the overcloud deploy command with all of the necessary optionsC:

deploy.sh script

```
#!/bin/bash

openstack overcloud deploy --templates /usr/share/openstack-tripleo-heat-templates \
-r /home/stack/templates/roles_data.yaml \
-e /home/stack/templates/environments/node-info.yaml \
-e /home/stack/templates/environments/overcloud_images.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml \
-e /home/stack/templates/environments/network-environment.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/services-docker/neutron-ovn-dvr-ha.yaml \
-e /usr/share/openstack-tripleo-heat-templates/environments/low-memory-usage.yaml \
-e /home/stack/templates/environments/fix-nova-reserved-host-memory.yaml \
-e /home/stack/templates/environments/firstboot.yaml \
```
1.2 Make the script executable:

```
(undercloud) [stack@undercloud ~]$ chmod 755 deploy.sh
```

1.3 Run the script from the undercloud node:

```
(undercloud) [stack@undercloud ~]$ ./deploy.sh
```

Note: This initiates overcloud deployment according to the supplied environment files and templates.

1.4 Open a second SSH session to the undercloud node to monitor the overcloud deployment process using the openstack stack list command:

```
[stack@undercloud ~]$ source ~/stackrc
(undercloud) [stack@undercloud ~]$ watch -n 30 "openstack stack list --nested" | grep COMPLETE
```

1.5 After successful deployment of the overcloud, locate the following files under the stack user’s home directory:


|File name                   |Description                                              |
|----------------------------|---------------------------------------------------------|     
|overcloudrc                 |Environment variables allowing access to overcloud       |
|tempest-deployer-input.conf |Tempest configuration file used to validate installation |

2. Review Deployment

2.1 Obtain the list of IP addresses assigned to the overcloud nodes:

```
(undercloud) [stack@undercloud ~]$ openstack server list
```

Kind of Sample Output:

```
+--------------------------------------+------------------------+--------+---------------------+----------------+---------+
| ID                                   | Name                   | Status | Networks            | Image          | Flavor  |
+--------------------------------------+------------------------+--------+---------------------+----------------+---------+
| 84d26467-b5d6-4de0-9555-86994995ee42 | overcloud-compute-0    | ACTIVE | ctlplane=192.0.2.6  | overcloud-full | compute |
| 4a086163-31f1-4286-8aeb-625cc6f613db | overcloud-controller-0 | ACTIVE | ctlplane=192.0.2.13 | overcloud-full | control |
| 80051a7e-83e3-4020-9edf-0e86cb800dae | overcloud-compute-1    | ACTIVE | ctlplane=192.0.2.16 | overcloud-full | compute |
+--------------------------------------+------------------------+--------+---------------------+----------------+---------+
```

Note: We have a working overcloud, but it is not yet configured to host end-user projects.

2.2 Verify that you can log in to the overcloud nodes as the heat-admin user:

```
(undercloud) [stack@undercloud ~]$ ssh heat-admin@192.0.2.6
```

2.3 Log in to the overcloud controller and review the running overcloud compute services:

```
[heat-admin@overcloud-controller-0 ~]$ source ~/overcloudrc
(overcloud) [heat-admin@overcloud-controller-0 ~]$ openstack compute service list
```

Kind of Sample Output:

```
+----+------------------+------------------------------------+----------+---------+-------+----------------------------+
| ID | Binary           | Host                               | Zone     | Status  | State | Updated At                 |
+----+------------------+------------------------------------+----------+---------+-------+----------------------------+
|  1 | nova-scheduler   | overcloud-controller-0.localdomain | internal | enabled | up    | 2018-07-10T14:10:51.000000 |
|  2 | nova-consoleauth | overcloud-controller-0.localdomain | internal | enabled | up    | 2018-07-10T14:10:48.000000 |
|  3 | nova-conductor   | overcloud-controller-0.localdomain | internal | enabled | up    | 2018-07-10T14:10:47.000000 |
|  4 | nova-compute     | overcloud-compute-0.localdomain    | nova     | enabled | up    | 2018-07-10T14:10:47.000000 |
|  5 | nova-compute     | overcloud-compute-1.localdomain    | nova     | enabled | up    | 2018-07-10T14:10:47.000000 |
+----+------------------+------------------------------------+----------+---------+-------+----------------------------+
```
