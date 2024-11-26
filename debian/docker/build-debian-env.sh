#!/bin/bash -xe

# install ansible
apt-get update
apt-get -y install ansible curl
#pip install ansible

cd /root
rm -rf $(hostname -s)-git
mkdir $(hostname -s)-git
cd $(hostname -s)-git

curl https://github/olli/basics/basics.yml >basics.yml
ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) basics.yml
