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
