#!/bin/bash -xe

# install ansible
apt-get update
apt-get -y install ansible curl

cd /root
rm -rf $(hostname -s)-git
mkdir $(hostname -s)-git
cd $(hostname -s)-git

curl -L https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/basics/basics.yml >basics.yml
ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) -e "ansible_python_interpreter=/usr/bin/python" basics.yml
