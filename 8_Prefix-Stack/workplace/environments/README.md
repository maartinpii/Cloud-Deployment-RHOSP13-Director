This directory contains Heat environment file snippets which can
be used to enable features in the Overcloud.

Configuration
-------------

These can be enabled using the -e [path to environment yaml] option with
heatclient.

Below is an example of how to enable the Ceph template using
devtest\_overcloud.sh:

    export OVERCLOUD\_CUSTOM\_HEAT\_ENV=$TRIPLEO\_ROOT/tripleo-heat-templates/environments/ceph_devel.yaml


Services support in OSP
-----------------------

While TripleO provides environment files that can deploy many services, not all of
them are supported by [Red Hat OpenStack Platform](https://www.redhat.com/en/technologies/linux-platforms/openstack-platform).

Before proceeding to an OSP deployment, it's suggested to read
[what services](https://access.redhat.com/articles/1535373) are actually supported.
