#!/bin/bash

# Invokes the Swift install process that is based on
# https://github.com/Open-I-Beam/swift-install
# with appropriate pre install preparations
# This is a dev oriented Swift installation that
# uses Keystone and a single device for all rings.
# TODO: Move swift ansible scripts pull from here
# to the swift-install module 

# The script takes a block device name as an optional parameter
# The device name can be either 'loop0' or any block device under /dev
# that can be formatted and mounted as a Swift device.
# The script assume it 'can sudo'

SWIFT_IP='127.0.0.1'
DEVICE='loop0'

if [ "$#" -gt 2 ]; then
    echo "Usage: $0 [ip_of_machine] [device-name]";
    exit
fi

if [ "$#" -ge 1 ]; then
    SWIFT_IP=$1
fi

if [ "$#" -eq 2 ]; then
    DEVICE=$2
    if [ $DEVICE != 'loop0' ] &&  [ ! -b "/dev/$DEVICE" ]; then
        echo "$DEVICE is not a block device"
        exit
    fi
fi

REPODIR='/tmp'
REPODIR_REPLACE='\/tmp'

echo "$DEVICE will be used as a block device for Swift"
if [ ! -e vars.yml ]; then
    cp vars.yml-sample vars.yml
    sudo sed -i 's/<set device!>/'$DEVICE'/g' vars.yml
    sudo sed -i 's/<set dir!>/'$REPODIR_REPLACE'/g' vars.yml
fi

if [ $SWIFT_IP != '127.0.0.1' ]; then
    sed -i 's/127.0.0.1/'$SWIFT_IP'/g' hosts
    cat >> hosts <<EOF

[s2aio:vars]
ansible_ssh_user=root
EOF
fi

ansible-playbook -i hosts prepare_swift_install.yml

if [ $SWIFT_IP == '127.0.0.1' ]; then
    cd $REPODIR/swift-install/provisioning
    ansible-playbook -s -i swift_dynamic_inventory.py main-install.yml
else
    ssh root@$SWIFT_IP 'ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ""'
    ssh root@$SWIFT_IP 'cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys'
    ssh root@$SWIFT_IP "bash -c 'cd /tmp/swift-install/provisioning ; ansible-playbook -s -i swift_dynamic_inventory.py main-install.yml'"
fi
