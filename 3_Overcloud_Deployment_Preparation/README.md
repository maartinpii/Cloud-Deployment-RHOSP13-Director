# Overcloud Deployment Preparation

## Objectives

* Register nodes for the overcloud
* Inspect the nodes' hardware
* Tag nodes into profiles

1. Register Nodes for Overcloud

Node registration uses a template file and makes nodes known to the undercloud so that overcloud components can be deployed on them.

Note: The only details that are required during node registration are for the given power management driver, although you use additional fields in your template to keep later operations simpler.

1.1 In the stack user’s home directory, create the instackenv.json file with this content:

```
{
    "nodes": [
        {
            "mac": [
                "2c:c2:60:01:02:02"
            ],
            "name": "ctrl01",
            "pm_addr": "192.0.2.221",
            "pm_password": "redhat",
            "pm_type": "pxe_ipmitool",
            "pm_user": "admin"
        },
        {
            "mac": [
                "2c:c2:60:01:02:05"
            ],
            "name": "compute01",
            "pm_addr": "192.0.2.224",
            "pm_password": "redhat",
            "pm_type": "pxe_ipmitool",
            "pm_user": "admin"
        },
        {
            "mac": [
                "2c:c2:60:01:02:06"
            ],
            "name": "compute02",
            "pm_addr": "192.0.2.225",
            "pm_password": "redhat",
            "pm_type": "pxe_ipmitool",
            "pm_user": "admin"
        }
    ]
}

```
The file defines the parameters of the three nodes present in the environment—one controller and two compute nodes.

1.2 Confirm that there are currently no bare-metal nodes registered with Red Hat OpenStack Platform director:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node list
```

Note: Expect the output to be empty.

2. Inspect Registered Nodes

2.1 Import the instackenv.json file and perform introspection of the registered nodes:

```
(undercloud) [stack@undercloud ~]$ openstack overcloud node import --introspect --provide instackenv.json
```

Kind of Sample Output:

```
Started Mistral Workflow tripleo.baremetal.v1.register_or_update. Execution ID: 1023cc00-e423-4fa2-9b0c-a50596b49ae5
Waiting for messages on queue 'tripleo' with no timeout.


3 node(s) successfully moved to the "manageable" state.
Successfully registered node UUID aa7203d0-8e83-4a06-9d4b-c018a2d933d9
Successfully registered node UUID 6ea50622-65ca-4db1-aab7-9f9ae91395ea
Successfully registered node UUID 6927ea32-455b-4454-bee1-c715087e2424
Waiting for introspection to finish...
Started Mistral Workflow tripleo.baremetal.v1.introspect. Execution ID: a224ba39-b7aa-4b43-b8cf-419836b9ef2b
Waiting for messages on queue 'tripleo' with no timeout.
Introspection of node 6ea50622-65ca-4db1-aab7-9f9ae91395ea completed. Status:SUCCESS. Errors:None
Introspection of node 6927ea32-455b-4454-bee1-c715087e2424 completed. Status:SUCCESS. Errors:None
Introspection of node aa7203d0-8e83-4a06-9d4b-c018a2d933d9 completed. Status:SUCCESS. Errors:None
Successfully introspected 3 node(s).
Started Mistral Workflow tripleo.baremetal.v1.provide. Execution ID: 42dfc548-4426-4bb0-9e75-ce09e5726601
Waiting for messages on queue 'tripleo' with no timeout.

3 node(s) successfully moved to the "available" state.
```

2.2 List the nodes that registered:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node list
```
Kind of Sample Output:

```
+--------------------------------------+-----------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name      | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-----------+---------------+-------------+--------------------+-------------+
| aa7203d0-8e83-4a06-9d4b-c018a2d933d9 | ctrl01    | None          | power off   | available          | False       |
| 6ea50622-65ca-4db1-aab7-9f9ae91395ea | compute01 | None          | power off   | available          | False       |
| 6927ea32-455b-4454-bee1-c715087e2424 | compute02 | None          | power off   | available          | False       |
+--------------------------------------+-----------+---------------+-------------+--------------------+-------------+
```

Note: For all of the nodes, verify that Power State is set to power off, Provisioning State is set to available, and Maintenance is set to False.

2.3 Display the details for each of the defined nodes—for example, for ctrl01:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node show ctrl01
```

2.4 Review the parameters in the driver_info field:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node show ctrl01 -f json -c driver_info
```

Kind of Sample Output:
```
{
  "driver_info": {
    "deploy_kernel": "4d927f7d-3d58-4cd0-bddf-272797116d46",
    "ipmi_address": "192.0.2.221",
    "deploy_ramdisk": "d6e19781-5d14-45cb-a24c-46f6d08b783b",
    "ipmi_password": "******",
    "ipmi_username": "admin"
  }
}
```
* Verify that the output contains the IPMI access parameters: ipmi_address, ipmi_password, and ipmi_username.
* Make sure that there are entries for deploy_kernel and deploy_ramdisk.

2.5 Verify that all of the nodes were successfully introspected:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal introspection list
```

Kind of Sample Output:

```
+--------------------------------------+---------------------+---------------------+-------+
| UUID                                 | Started at          | Finished at         | Error |
+--------------------------------------+---------------------+---------------------+-------+
| 6927ea32-455b-4454-bee1-c715087e2424 | 2018-07-01T00:57:17 | 2018-07-01T00:59:49 | None  |
| 6ea50622-65ca-4db1-aab7-9f9ae91395ea | 2018-07-01T00:57:15 | 2018-07-01T00:59:54 | None  |
| aa7203d0-8e83-4a06-9d4b-c018a2d933d9 | 2018-07-01T00:57:14 | 2018-07-01T00:59:57 | None  |
+--------------------------------------+---------------------+---------------------+-------+
```

2.6 After introspection finishes, examine some of the data gathered about each node:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node show ctrl01 -f json -c properties
```

Kind of Sample Output:

```
{
  "properties": {
    "memory_mb": "8192",
    "cpu_arch": "x86_64",
    "local_gb": "59",
    "cpus": "2",
    "capabilities": "boot_mode:bios,cpu_hugepages:true,boot_option:local"
  }
}
```
* The properties field has the memory_mb, cpu_arch, local_gb, and cpus values obtained during the introspection.
* The capabilities entry has boot_option:local present.

3. Tag Nodes into Profiles

After registering and inspecting the hardware of each node, you tag them into specific profiles. These profile tags match nodes to flavors, and in turn the flavors are assigned to a deployment role. The default compute, control, swift-storage, ceph-storage, and block-storage profile flavors are created during the undercloud installation and can be used without modification in most environments.

In this section, we add a profile option to the properties/capabilities parameter for each node to tag a node into a specific profile.

3.1 List the default flavors defined in the undercloud:

```
(undercloud) [stack@undercloud ~]$ openstack flavor list
```

Kind of Expected Output:

```
+--------------------------------------+---------------+------+------+-----------+-------+-----------+
| ID                                   | Name          |  RAM | Disk | Ephemeral | VCPUs | Is Public |
+--------------------------------------+---------------+------+------+-----------+-------+-----------+
| 2d96c2b9-57b3-446b-8b08-72fdc08041f6 | baremetal     | 4096 |   40 |         0 |     1 | True      |
| 31066a89-9dd9-42ce-a3e8-f1c352b743e1 | control       | 4096 |   40 |         0 |     1 | True      |
| 59003812-d96d-4f81-a5b8-054f338be6a0 | swift-storage | 4096 |   40 |         0 |     1 | True      |
| 7b984338-4b7c-46b3-b55d-29c6a8462d3c | ceph-storage  | 4096 |   40 |         0 |     1 | True      |
| 84fc5fd8-2a5f-4076-8d1c-292539792923 | block-storage | 4096 |   40 |         0 |     1 | True      |
| a8c7af38-05bb-41ee-b32a-aa0c16165c72 | compute       | 4096 |   40 |         0 |     1 | True      |
+--------------------------------------+---------------+------+------+-----------+-------+-----------+
```

3.2 Verify that each flavor in the list (except baremetal) has the corresponding profile defined in its properties/capabilities parameter—for example, to get data about the control flavor:

```
(undercloud) [stack@undercloud ~]$ openstack flavor show control -f json -c properties
```

Kind of Sample Output:

```
{
  "properties": "capabilities:boot_option='local', capabilities:profile='control', resources:CUSTOM_BAREMETAL='1', resources:DISK_GB='0', resources:MEMORY_MB='0', resources:VCPU='0'"
}
```


The control flavor is defined with profile='control'.

Note: The baremetal flavor is the default and it does not have a profile assigned.

3.3 List the overcloud profiles assigned to the registered bare-metal nodes:

```
(undercloud) [stack@undercloud ~]$ openstack overcloud profiles list
```

Check that the nodes has no profile assigned

3.4 Assign a tag to the nodes to use Control and Compute profiles:

```
(undercloud) [stack@undercloud ~]$ openstack baremetal node set --property capabilities=boot_mode:bios,cpu_hugepages:true,boot_option:local,profile:control ctrl01
(undercloud) [stack@undercloud ~]$ openstack baremetal node set --property capabilities=boot_mode:bios,cpu_hugepages:true,boot_option:local,profile:compute compute01
(undercloud) [stack@undercloud ~]$ openstack baremetal node set --property capabilities=boot_mode:bios,cpu_hugepages:true,boot_option:local,profile:compute compute02
```

3.5 Verify

```
(undercloud) [stack@undercloud ~]$ openstack overcloud profiles list
```
Kind of Sample Output:

```
+--------------------------------------+-----------+-----------------+-----------------+-------------------+
| Node UUID                            | Node Name | Provision State | Current Profile | Possible Profiles |
+--------------------------------------+-----------+-----------------+-----------------+-------------------+
| aa7203d0-8e83-4a06-9d4b-c018a2d933d9 | ctrl01    | available       | control         |                   |
| 6ea50622-65ca-4db1-aab7-9f9ae91395ea | compute01 | available       | compute         |                   |
| 6927ea32-455b-4454-bee1-c715087e2424 | compute02 | available       | compute         |                   |
+--------------------------------------+-----------+-----------------+-----------------+-------------------+
```
