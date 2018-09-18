# Analysis

## Objectives


* Explore a containerized overcloud
* Review services running by docker or pacemaker
* Explore log files of containerized services
* Explore configuration files for containerized services

1. Explore Architecture

This new OSP architecture with containerized services, has lead to some changes in the implementation of the architecture.

* Pacemaker-managed containers use a new bundle resource type, which contains the information that Pacemaker needs to start the containers.
* Other containers are started by the docker daemon, rather than directly by systemd.

2. Review Pacemaker Setup

2.1 Check the pacemaker service (from the controller nodes):

```
[heat-admin@overcloud-controller-0 ~]$ sudo systemctl status pacemaker
```
Note: Pacemaker itself is not containerized.

2.2 Review the state of the Pacemaker cluster:

```
[heat-admin@overcloud-controller-0 ~]$ sudo pcs status
```

Kind of Sample Output:

```
Cluster name: tripleo_cluster
Stack: corosync
Current DC: overcloud-controller-0 (version 1.1.18-11.el7_5.2-2b07d5c5a9) - partition with quorum
Build Version: 1.0R   :   Last updated: Tue Jul 10 14:51:02 2018
Last change: Tue Jul 10 13:37:15 2018 by root via cibadmin on overcloud-controller-0

5 nodes configured
20 resources configured

Online: [ overcloud-controller-0 ]
GuestOnline: [ galera-bundle-0@overcloud-controller-0 ovn-dbs-bundle-0@overcloud-controller-0 rabbitmq-bundle-0@overcloud-controller-0 redis-bundle-0@overcloud-controller-0 ]

Full list of resources:

 Docker container: rabbitmq-bundle [192.0.2.1:8787/rhosp13/openstack-rabbitmq:pcmklatest]
   rabbitmq-bundle-0	(ocf::heartbeat:rabbitmq-cluster):	Started overcloud-controller-0
 Docker container: galera-bundle [192.0.2.1:8787/rhosp13/openstack-mariadb:pcmklatest]
   galera-bundle-0	(ocf::heartbeat:galera):	Master overcloud-controller-0
 Docker container: redis-bundle [192.0.2.1:8787/rhosp13/openstack-redis:pcmklatest]
   redis-bundle-0	(ocf::heartbeat:redis):	Master overcloud-controller-0
 ip-192.0.2.14	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 ip-10.0.0.10	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 ip-172.17.0.6	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 ip-172.17.0.4	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 ip-172.18.0.12	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 ip-172.19.0.11	(ocf::heartbeat:IPaddr2):	Started overcloud-controller-0
 Docker container: haproxy-bundle [192.0.2.1:8787/rhosp13/openstack-haproxy:pcmklatest]
   haproxy-bundle-docker-0	(ocf::heartbeat:docker):	Started overcloud-controller-0
 Docker container: ovn-dbs-bundle [192.0.2.1:8787/rhosp13/openstack-ovn-northd:13.0-40]
   ovn-dbs-bundle-0	(ocf::ovn:ovndb-servers):	Master overcloud-controller-0
 Docker container: openstack-cinder-volume [192.0.2.1:8787/rhosp13/openstack-cinder-volume:pcmklatest]
   openstack-cinder-volume-docker-0	(ocf::heartbeat:docker):	Started overcloud-controller-0

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
```
Note: The rabbitmq container is running as a Pacemaker bundle. The bundle resource specifies the container image to be used, the networking type, storage mounts, and other values

3. Examine Pacemaker-Managed Containers

3.1 Review the rabbitmq-bundle resource details:

```
[heat-admin@overcloud-controller-0 ~]$ sudo pcs resource show rabbitmq-bundle
```

Kind of Sample Output:

```
 Bundle: rabbitmq-bundle
  Docker: image=192.0.2.1:8787/rhosp13/openstack-rabbitmq:pcmklatest network=host options="--user=root --log-driver=journald -e KOLLA_CONFIG_STRATEGY=COPY_ALWAYS" replicas=1 run-command="/bin/bash /usr/local/bin/kolla_start"
  Network: control-port=3122
  Storage Mapping:
   options=ro source-dir=/var/lib/kolla/config_files/rabbitmq.json target-dir=/var/lib/kolla/config_files/config.json (rabbitmq-cfg-files)
   options=ro source-dir=/var/lib/config-data/puppet-generated/rabbitmq/ target-dir=/var/lib/kolla/config_files/src (rabbitmq-cfg-data)
   options=ro source-dir=/etc/hosts target-dir=/etc/hosts (rabbitmq-hosts)
   options=ro source-dir=/etc/localtime target-dir=/etc/localtime (rabbitmq-localtime)
   options=rw source-dir=/var/lib/rabbitmq target-dir=/var/lib/rabbitmq (rabbitmq-lib)
   options=ro source-dir=/etc/pki/ca-trust/extracted target-dir=/etc/pki/ca-trust/extracted (rabbitmq-pki-extracted)
   options=ro source-dir=/etc/pki/tls/certs/ca-bundle.crt target-dir=/etc/pki/tls/certs/ca-bundle.crt (rabbitmq-pki-ca-bundle-crt)
   options=ro source-dir=/etc/pki/tls/certs/ca-bundle.trust.crt target-dir=/etc/pki/tls/certs/ca-bundle.trust.crt (rabbitmq-pki-ca-bundle-trust-crt)
   options=ro source-dir=/etc/pki/tls/cert.pem target-dir=/etc/pki/tls/cert.pem (rabbitmq-pki-cert)
   options=rw source-dir=/var/log/containers/rabbitmq target-dir=/var/log/rabbitmq (rabbitmq-log)
   options=rw source-dir=/dev/log target-dir=/dev/log (rabbitmq-dev-log)
  Resource: rabbitmq (class=ocf provider=heartbeat type=rabbitmq-cluster)
   Attributes: set_policy="ha-all ^(?!amq\.).* {"ha-mode":"all"}"
   Meta Attrs: container-attribute-target=host notify=true
   Operations: monitor interval=10 timeout=40 (rabbitmq-monitor-interval-10)
               start interval=0s timeout=200s (rabbitmq-start-interval-0s)
               stop interval=0s timeout=200s (rabbitmq-stop-interval-0s)
```

3.2 View the openstack-rabbitmq container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker ps | grep rabbitmq
```
Note: the image field should be set to 192.0.2.1:8787/rhosp13/openstack-rabbitmq:pcmklatest, which confirms that the undercloud’s registry is being used.

3.3 Inspect the rabbitmq-bundle-docker-0 container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect -f '{{ .HostConfig.RestartPolicy.Name }}' rabbitmq-bundle-docker-0
```

Note: The restart policy for this container is no, so the docker daemon does not automatically start this container. This is Pacemaker’s job

3.4 Restart the cluster’s resource:

```
[heat-admin@overcloud-controller-0 ~]$ sudo pcs resource restart rabbitmq-bundle
```

3.4.1 Check the rabbitmq container again:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker ps | grep rabbitmq
```

4. Explore Non-Pacemaker Managed Containers

4.1 Filter the list of running containers by name to find glance_api:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker ps -f name=glance_api
```

Kind of Sample Output:

```
CONTAINER ID        IMAGE                                                 COMMAND             CREATED             STATUS                 PORTS               NAMES
598a275ba677        192.0.2.1:8787/rhosp13/openstack-glance-api:13.0-38   "kolla_start"       2 hours ago         Up 2 hours (healthy)                       glance_api
```

4.2 Inspect the glance_api container to get, for example, the container’s image:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect -f '{{.Config.Image}}' glance_api
```

Kind of Sample Output:

```
192.0.2.1:8787/rhosp13/openstack-glance-api:13.0-38
```

4.3 Inspect the glance_api container to get its restart policy:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect -f '{{ .HostConfig.RestartPolicy.Name }}' glance_api
```

Expected Output

```
always
```

Note: The restart of the container made by the docker service

4.4 Verify that the docker service itself is managed by systemd, which starts it at boot time:

```
[heat-admin@overcloud-controller-0 ~]$ sudo systemctl status docker | head -n 7
```

Kind of Sample Output:

```
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; vendor preset: disabled)
  Drop-In: /etc/systemd/system/docker.service.d
           └─99-unset-mountflags.conf
   Active: active (running) since Tue 2018-07-10 13:08:44 UTC; 1h 52min ago
     Docs: http://docs.docker.com
 Main PID: 18776 (dockerd-current)
```

5. Explore Service Running Inside Container

5.1 Run a shell within the container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker exec -it glance_api /bin/sh
```

5.2 From the controller node verify that the user ID assigned to the shell inside the glance_api container is defined in its metadata:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect -f '{{ .Config.User }}' glance_api
```

Expected Output

```
glance
```

5.3 Log in to the glance_api container as the root user:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker exec -it -u root glance_api /bin/sh
```

5.4 List the processes running within the container:

```
()[root@overcloud-controller-0 /]$ ps -ef
```

Kind of Sample Output:

```
UID          PID    PPID  C STIME TTY          TIME CMD
glance         1       0  0 13:34 ?        00:01:18 /usr/bin/python2 /usr/bin/glance-api --config-file /usr/share/glance/glance-api-dist.conf --config-file /etc/glance/glance-api.conf
glance        24       1  0 13:34 ?        00:00:21 /usr/bin/python2 /usr/bin/glance-api --config-file /usr/share/glance/glance-api-dist.conf --config-file /etc/glance/glance-api.conf
root        2405       0  0 15:47 ?        00:00:00 /bin/sh
root        2425    2405  0 15:48 ?        00:00:00 ps -ef
```

5.6 Check the Network Configuration:

```
()[root@overcloud-controller-0 /]$ ip a
```
Kind of Sample Output:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 2c:c2:60:01:02:02 brd ff:ff:ff:ff:ff:ff
    inet 192.0.2.13/24 brd 192.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 192.0.2.14/32 brd 192.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::2ec2:60ff:fe01:202/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast master ovs-system state UP group default qlen 1000
    link/ether 2c:c2:60:1f:6d:0e brd ff:ff:ff:ff:ff:ff
    inet6 fe80::2ec2:60ff:fe1f:6d0e/64 scope link
       valid_lft forever preferred_lft forever
4: ovs-system: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether ae:55:3c:7e:a5:73 brd ff:ff:ff:ff:ff:ff
5: br-ex: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 2c:c2:60:1f:6d:0e brd ff:ff:ff:ff:ff:ff
    inet6 fe80::2ec2:60ff:fe1f:6d0e/64 scope link
       valid_lft forever preferred_lft forever
6: vlan10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 92:4b:88:88:59:7c brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.15/24 brd 10.0.0.255 scope global vlan10
       valid_lft forever preferred_lft forever
    inet 10.0.0.10/32 brd 10.0.0.255 scope global vlan10
       valid_lft forever preferred_lft forever
    inet6 fe80::904b:88ff:fe88:597c/64 scope link
       valid_lft forever preferred_lft forever
7: vlan20: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether f6:b8:02:ba:41:fb brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.12/24 brd 172.17.0.255 scope global vlan20
       valid_lft forever preferred_lft forever
    inet 172.17.0.6/32 brd 172.17.0.255 scope global vlan20
       valid_lft forever preferred_lft forever
    inet 172.17.0.4/32 brd 172.17.0.255 scope global vlan20
       valid_lft forever preferred_lft forever
    inet6 fe80::f4b8:2ff:feba:41fb/64 scope link
       valid_lft forever preferred_lft forever
8: vlan30: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 96:6b:58:7b:48:7e brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.6/24 brd 172.18.0.255 scope global vlan30
       valid_lft forever preferred_lft forever
    inet 172.18.0.12/32 brd 172.18.0.255 scope global vlan30
       valid_lft forever preferred_lft forever
    inet6 fe80::946b:58ff:fe7b:487e/64 scope link
       valid_lft forever preferred_lft forever
9: vlan40: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 86:9f:b3:84:c9:99 brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.12/24 brd 172.19.0.255 scope global vlan40
       valid_lft forever preferred_lft forever
    inet 172.19.0.11/32 brd 172.19.0.255 scope global vlan40
       valid_lft forever preferred_lft forever
    inet6 fe80::849f:b3ff:fe84:c999/64 scope link
       valid_lft forever preferred_lft forever
10: vlan50: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 9e:94:b4:5a:ce:de brd ff:ff:ff:ff:ff:ff
    inet 172.16.0.11/24 brd 172.16.0.255 scope global vlan50
       valid_lft forever preferred_lft forever
    inet6 fe80::9c94:b4ff:fe5a:cede/64 scope link
       valid_lft forever preferred_lft forever
11: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:a7:af:9c:a5 brd ff:ff:ff:ff:ff:ff
    inet 172.31.0.1/24 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:a7ff:feaf:9ca5/64 scope link
       valid_lft forever preferred_lft forever
48: genev_sys_6081: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65000 qdisc noqueue master ovs-system state UNKNOWN group default qlen 1000
    link/ether be:76:83:dc:d7:e5 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::bc76:83ff:fedc:d7e5/64 scope link
       valid_lft forever preferred_lft forever
49: br-int: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 32:db:bc:cb:69:43 brd ff:ff:ff:ff:ff:ff

```

Note: All containers in Red Hat OpenStack Platform 13 use host networking, so all of the host’s network interfaces, IP addresses, routing tables, and other network objects are exposed in the container.
Note: Only the network objects in the default network namespace are visible within the container.


6. Examine Log Files

Check how a log written from inside the container becomes visible from the host.

The Glance API service use the /var/log/glance/api.log file by default. Because the Glance service is containerized, this file must be writable from inside the glance_api container.

6.1. Verify Write Access to Log File

6.1.1 Reattach to the glance_api container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker exec -it glance_api /bin/sh
```

6.1.2 Review the list of the log files in the Glance log directory:

```
()[glance@overcloud-controller-0 /]$ ls -al /var/log/glance/
```

Kind of Sample Output:

```
total 1024
drwxr-xr-x. 2 glance glance     21 Jul 10 13:26 .
drwxr-xr-x. 1 root   root       19 Jun 15 17:43 ..
-rw-r--r--. 1 glance glance 809750 Jul 10 16:32 api.log
```

Note: The api.log file exists and it is writable for the glance user.

6.1.3 Examine the contents of the api.log file:

```
()[glance@overcloud-controller-0 /]$ tail /var/log/glance/api.log
```

6.1.4 Write to the /var/log/glance/api.log file:

```
()[glance@overcloud-controller-0 /]$ echo "CHECK WRITE ACCESS FROM glance_api CONTAINER" >> /var/log/glance/api.log
```

6.1.5 Verify that the message was written successfully:

```
()[glance@overcloud-controller-0 /]$ grep 'CHECK WRITE ACCESS' /var/log/glance/api.log
```

6.2. Examine Log Outside Container

6.2.1 Try to view the contents of /var/log/glance/api.log outside the container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo cat /var/log/glance/api.log
```

Expected Output:

```
cat: /var/log/glance/api.log: No such file or directory
```

6.2.2 Examine the container’s metadata to determine which directory in the host file system is bind-mounted to the /var/log/glance directory inside the glance_api container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect glance_api | jq '.[].Mounts[] | select(.Destination == "/var/log/glance")'
```

Expected Output:

```
{
  "Propagation": "rprivate",
  "RW": true,
  "Mode": "",
  "Destination": "/var/log/glance",
  "Source": "/var/log/containers/glance",
  "Type": "bind"
}
```

Note: The docker daemon mounts the /var/log/containers/glance directory in the host file system to the /var/log/glance directory inside the container when the container is started.

6.2.3 Verify that the message written from inside the glance_api container appears in the /var/log/containers/glance/api.log file:

```
[heat-admin@overcloud-controller-0 ~]$ sudo grep 'CHECK WRITE ACCESS' /var/log/containers/glance/api.log
```

6.3. Compare Log Identity Inside and Outside of Container

Verify that /var/log/glance/api.log inside the container is the same as /var/log/containers/glance/api.log in the host operating system by comparing the device and inode of the file.

6.3.1 Run stat inside the container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker exec -t glance_api stat /var/log/glance/api.log
```

Kind of Sample Output:

```
  File: '/var/log/glance/api.log'
  Size: 923314          Blocks: 2048       IO Block: 4096   regular file
Device: fc02h/64514d    Inode: 58905122    Links: 1
Access: (0644/-rw-r--r--)  Uid: (42415/  glance)   Gid: (42415/  glance)
Access: 2018-07-10 16:55:51.897887625 +0000
Modify: 2018-07-10 16:58:02.961171639 +0000
Change: 2018-07-10 16:58:02.961171639 +0000
Birth: -
```

6.3.2 Run stat in the host operating system:

```
[heat-admin@overcloud-controller-0 ~]$ sudo stat /var/log/containers/glance/api.log
```

Kind of Sample Output:

```
  File: ‘/var/log/containers/glance/api.log’
  Size: 940005          Blocks: 2048       IO Block: 4096   regular file
Device: fc02h/64514d    Inode: 58905122    Links: 1
Access: (0644/-rw-r--r--)  Uid: (42415/ UNKNOWN)   Gid: (42415/ UNKNOWN)
Context: system_u:object_r:var_log_t:s0
Access: 2018-07-10 16:55:51.897887625 +0000
Modify: 2018-07-10 17:01:45.814353828 +0000
Change: 2018-07-10 17:01:45.814353828 +0000
Birth: -
```

Note: The device (fc02h/64514d) and inode (58905122) are the same in both cases.

7. Explore Container Bind Mounts

```
[heat-admin@overcloud-controller-0 ~]$ ls -al /var/log/containers /var/log/containers/httpd
```

Kind of Sample Output:

```
/var/log/containers:
total 4
drwxr-xr-x. 18 root   root    249 Jul 10 13:07 .
drwxr-xr-x. 50 root   root   4096 Jul 10 13:16 ..
drwxr-xr-x.  2  42402  42402  120 Jul 10 13:34 aodh
drwxr-xr-x.  2  42405  42405   85 Jul 10 13:37 ceilometer
drwxr-xr-x.  2  42407  42407  106 Jul 10 13:37 cinder
drwxr-xr-x.  2  42415  42415   21 Jul 10 13:26 glance
drwxr-xr-x.  2  42416  42416   74 Jul 10 13:37 gnocchi
drwxr-xr-x.  2  42418  42418   73 Jul 10 13:34 heat
drwxr-xr-x.  2 apache apache   25 Jul 10 13:16 horizon
drwxr-xr-x. 13 root   root    200 Jul 10 13:07 httpd
drwxr-xr-x.  2  42425  42425   57 Jul 10 14:01 keystone
drwxr-xr-x.  2  42434  42434   24 Jul 10 13:18 mysql
drwxr-xr-x.  2  42435  42435   24 Jul 10 13:34 neutron
drwxr-xr-x.  2  42436  42436  215 Jul 10 13:35 nova
drwxr-xr-x.  2 root   root    108 Jul 10 13:34 openvswitch
drwxr-xr-x.  2  42438  42438   45 Jul 10 13:34 panko
drwxr-xr-x.  2  42439  42439  131 Jul 10 13:16 rabbitmq
drwxr-xr-x.  2  42460  42460   23 Jul 10 13:20 redis
lrwxrwxrwx.  1 root   root     14 Jul 10 13:07 swift -> /var/log/swift

/var/log/containers/httpd:
total 0
drwxr-xr-x. 13 root root 200 Jul 10 13:07 .
drwxr-xr-x. 18 root root 249 Jul 10 13:07 ..
drwxr-xr-x.  2 root root  78 Jul 10 13:34 aodh-api
drwxr-xr-x.  2 root root  82 Jul 10 13:34 cinder-api
drwxr-xr-x.  2 root root  84 Jul 10 13:37 gnocchi-api
drwxr-xr-x.  2 root root  86 Jul 10 13:34 heat-api
drwxr-xr-x.  2 root root  94 Jul 10 13:34 heat-api-cfn
drwxr-xr-x.  2 root root  74 Jul 10 13:27 horizon
drwxr-xr-x.  2 root root 171 Jul 10 13:29 keystone
drwxr-xr-x.  2 root root   6 Jul 10 13:07 neutron-api
drwxr-xr-x.  2 root root  86 Jul 10 13:34 nova-api
drwxr-xr-x.  2 root root  88 Jul 10 13:27 nova-placement
drwxr-xr-x.  2 root root  80 Jul 10 13:34 panko-api
```

Note: many of the OpenStack API services run as WSGI services inside httpd. To avoid conflicts, each of these containers has a separate directory beneath /var/log/containers/httpd.

7.2 Note that the OpenStack Nova containers running on the controller have the following log-related bind mounts:

|Container        |Host Directory	                          |Container Directory |   
|-----------------|-----------------------------------------|--------------------|      
|nova_api         |/var/log/containers/nova                 |/var/log/nova       |
|                 |/var/log/containers/httpd/nova-api       |/var/log/httpd      |
|nova_api_cron    |/var/log/containers/nova                 |/var/log/nova       |
|                 |/var/log/containers/httpd/nova-api       |/var/log/httpd      |
|nova_conductor   |/var/log/containers/nova                 |/var/log/nova       |
|nova_consoleauth |/var/log/containers/nova                 |/var/log/nova       |
|nova_metadata    |/var/log/containers/nova                 |/var/log/nova       |
|nova_placement   |/var/log/containers/nova                 |/var/log/nova       |
|                 |/var/log/containers/httpd/nova-placement |/var/log/httpd      |
|nova_scheduler   |/var/log/containers/nova                 |/var/log/nova       |
|nova_vnc_proxy   |/var/log/containers/nova                 |/var/log/nova       |


Not all of the containers in Red Hat OpenStack Platform 13 follow the above convention.
* Most Pacemaker-managed services log to subdirectories under the /var/log/pacemaker/bundles directory.
* The haproxy container logs directly to /dev/log, which is bind-mounted into the container. Its messages appear in the host journal.
* The stdout and stderr output from containerized services can be viewed with the docker logs command. The Ceph mon and osd containers log some useful information in this manner. However, the Ceph containers' logs in /var/log/ceph are not exposed to the host operating system.


8. Explore Example Configuration Files

The OpenStack service containers are based on Dockerfiles and tools developed by the Kolla project.

The Kolla project also provides an Ansible®-based deployment tool, but it is not used in TripleO. Only the container image recipes are used. Almost all of the containers in Red Hat OpenStack Platform 13 use the kolla_set_configs tools to set up configuration files before starting the container’s service.

The basic flow is as follows:

* A directory containing the configuration files is bind-mounted into the container at /var/lib/kolla/config_files/src.
* A JSON configuration file for kolla_set_configs is bind-mounted into the container at /var/lib/kolla/config_files/config.json.
* kolla_set_configs (which is usually called by kolla_start) uses the information in /var/lib/kolla/config_files/config.json to copy configuration files from /var/lib/kolla/config_files/src to their final locations within the container.

8.1 Check the nova_api container:

```
[heat-admin@overcloud-controller-0 ~]$ sudo docker inspect nova_api | jq '.[].HostConfig.Binds' | grep kolla/config_files
```

Expected Output

```
  "/var/lib/kolla/config_files/nova_api.json:/var/lib/kolla/config_files/config.json:ro",
  "/var/lib/config-data/puppet-generated/nova/:/var/lib/kolla/config_files/src:ro",
```

* The config.json file comes from /var/lib/kolla/config_files/nova_api.json on the host operating system.
* The src directory is mapped to /var/lib/config-data/puppet-generated/nova/, which contains various configuration files generated by TripleO Puppet modules.

8.2 Review the contents of the nova_api.json file:

```
[heat-admin@overcloud-controller-0 ~]$ sudo jq . /var/lib/kolla/config_files/nova_api.json
```

Expected Output:

```
{
  "permissions": [
    {
      "recurse": true,
      "path": "/var/log/nova",
      "owner": "nova:nova"
    }
  ],
  "command": "/usr/sbin/httpd -DFOREGROUND",
  "config_files": [
    {
      "merge": true,
      "preserve_properties": true,
      "source": "/var/lib/kolla/config_files/src/*",
      "dest": "/"
    }
  ]
}
```

8.3 Review the files in the /var/lib/config-data/puppet-generated/nova/ directory of the host operating system:

```
[heat-admin@overcloud-controller-0 ~]$ sudo find /var/lib/config-data/puppet-generated/nova -type f -printf '%P\n'
```

Kind Sample Output:

```
etc/httpd/conf.d/10-nova_api_wsgi.conf
etc/httpd/conf.d/ssl.conf
etc/httpd/conf.modules.d/access_compat.load
...
etc/nova/nova.conf
etc/systemd/system/httpd.service.d/httpd.conf
var/spool/cron/nova
var/www/cgi-bin/nova/nova-api
```
