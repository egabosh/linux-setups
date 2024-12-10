#!/bin/bash

set -e

# on fresh install remove cdrom-repo and install sudo if not available
[ -s /usr/bin/sudo ] || su -c "sed -i '/cdrom/d' /etc/apt/sources.list ; apt update ; apt -y install sudo"
# add user to sudo group if not
if ! id | grep -q '(sudo)' 
then
  su -c "/usr/sbin/usermod -a -G sudo ${USER}"
  # use sudo group and restart this script 
  exec sg sudo -c "bash $0"
  exit $?
fi

sudo apt-get update
which ansible >/dev/null 2>&1 || sudo apt-get -y install ansible git
sudo ansible-galaxy collection install community.general

cd
rm -rf linux-setups
git clone https://github.com/egabosh/linux-setups.git
cd linux-setups

for playbook in $PLAYBOOKS
do
  echo "=== $playbook"
  if [ -s "$playbook" ]
  then
    sudo ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) "${playbook}" || exit 2
  elif [[ $playbook =~ https:// ]]
  then
    playbookfile=$(basename "$playbook")
    if curl -L "$playbook" >~/"${playbookfile}"
    then
      sudo ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) ~/"${playbookfile}" || exit 2
    else
      echo "Playbook $playbook could not be downloaded"
      exit 1
    fi
  else
    echo "Playbook $playbook not found"
    exit 1
  fi
done

