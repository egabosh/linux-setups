#!/bin/bash

[ -s /run/mint-config-update.sh.lock ] && if [ -d "/proc/$(cat /run/mint-config-update.sh.lock)" ]
then
  echo "Lockfile /run/mint-config-update.sh.lock exists"
  exit 0
fi

if whoami | grep -q ^root$
then
  # lockfile for systemd-service
  trap "rm -f /run/mint-config-update.sh.lock" EXIT
  echo $$ >/run/mint-config-update.sh.lock
fi

# download and run
until wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/mint/mint.sh -O /tmp/mint.sh
do
  echo "mint.sh could not be downloaded trying again in 5 seconds"
  sleep 5
done

cd /tmp
dos2unix mint.sh
bash -n mint.sh && bash mint.sh
rm mint.sh

echo "Skript beendet"
whoami | grep -q ^root$ && exit 0
read x
