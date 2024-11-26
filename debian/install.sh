#!/bin/bash

set -e

# on fresh install remove cdrom-repo and install sudo if not available
[ -s /usr/bin/sudo ] || su -c "sed -i '/cdrom/d' /etc/apt/sources.list ; apt update ; apt -y install sudo"
# add user to sudo group it not
if ! id | grep -q '(sudo)' 
then
  su -c "/usr/sbin/usermod -a -G sudo ${USER}"
  # use sudo group and restart this script 
  exec sg sudo -c "bash $0"
  exit $?
fi

apt-get update
which ansible >/dev/null 2>&1 || sudo apt-get -y install ansible git
#sudo ansible-galaxy collection list | grep -q community.general || sudo ansible-galaxy collection install community.general
sudo ansible-galaxy collection install community.general

cd
rm -rf $(hostname -s)-git
mkdir $(hostname -s)-git
cd $(hostname -s)-git


for playbook in $PLAYBOOKS
do
  if [ -z "${GITSRVURL}" ]
  then
    git clone https://github/egabosh/linux-setups/debian/${playbook}.git
  else
    git clone ${GITSRVURL}/${playbook}.git
  fi
  [ -s /etc/dohardening ] || rm -f ${playbook}/hardening.yml
  if ls ${playbook}/*ansible*.yml >/dev/null 2>&1
  then
    sudo ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) ${playbook}/*ansible*.yml
  else
    sudo ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) ${playbook}/*.yml
  fi
done
