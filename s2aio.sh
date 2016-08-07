#!/bin/bash
# s2aio install from scratch an all in one swift with the storlet engine.
# s2aio has two flavors:
# 1. Jenkins job installation, for running the funciotal tests.
# 2. Developer instalation.

if [ "$#" -ne 1 ]; then
    echo "Usage: s2aio.sh <flavour>"
    echo "flavour = jenkins | dev"
    exit 1
fi

FLAVOR="$1"
if [ "$FLAVOR" != "jenkins" ] && [ "$FLAVOR" != "dev" ]; then
    echo "flavour must be either \"jenkins\" or \"dev\""
    exit 1
fi

# Make sure hostname is resolvable
grep -q -F ${HOSTNAME} /etc/hosts || sudo sed -i '1i127.0.0.1\t'"$HOSTNAME"'' /etc/hosts

install/install_ansible.sh

# install docker
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo sh -c "echo deb https://apt.dockerproject.org/repo ubuntu-trusty main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install docker-engine -y

# run the swift docker container
sudo docker run -i -d --privileged=true --name swift -t ubuntu:14.04
export SWIFT_IP=`sudo docker exec swift  ifconfig | grep "inet addr" | head -1 | awk '{print $2}' | awk -F":" '{print $2}'`

sudo docker exec swift apt-get update
sudo docker exec swift apt-get install software-properties-common -y
sudo docker exec swift apt-add-repository -y ppa:ansible/ansible
sudo docker exec swift apt-get update
sudo docker exec swift apt-get install openssh-server git ansible -y
sudo docker exec swift service ssh start

# Allow Ansible to ssh as the current user without a password
# While at it, take care of host key verification.
# This involves:
# 1. Generate an rsa key for the current user if necessary
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ""
fi

# 2. Add the key to the user's authorized keys
sudo docker exec swift mkdir /root/.ssh
sudo docker exec swift bash -c "echo `cat ~/.ssh/id_rsa.pub` > /root/.ssh/authorized_keys"

# 3. Take care of host key verification for the current user
touch ~/.ssh/known_hosts
ssh-keygen -R $SWIFT_IP -f ~/.ssh/known_hosts
ssh-keyscan  -H $SWIFT_IP >> ~/.ssh/known_hosts
ssh-add

# Install Swift
# TODO: move gcc to swift-installation
sudo apt-get install -y gcc
cd install/swift
./install_swift.sh $SWIFT_IP
cd -

install/storlets/prepare_storlets_install.sh "$FLAVOR" "$SWIFT_IP"

# Install Storlets
cd install/storlets
./install_storlets.sh "$FLAVOR"
cd -

# TODO: this is for tests. Deal accordingly.
cp install/storlets/deploy/cluster_config.json .
sudo chown $USER:$USER cluster_config.json

echo "export OS_USERNAME=tester; export OS_PASSWORD=testing;" >> ~/.bashrc
echo "export OS_TENANT_NAME=test; export OS_AUTH_URL=http://"$SWIFT_IP":5000/v2.0" >> ~/.bashrc
