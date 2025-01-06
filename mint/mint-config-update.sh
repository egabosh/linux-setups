#!/bin/bash

if whoami | grep -q ^root$
then
  # lockfile for systemd-service
  trap "rm -f /run/mint-config-update.sh.lock" EXIT
  echo $$ >/run/mint-config-update.sh.lock
  #if find /var/log/mint-config-update.sh.log -mmin -60 | grep -q /var/log/mint-config-update.sh.log
  #then
  #  echo "$0 was running already in the last 60 minutes"
  #  rm -f /run/mint-config-update.sh.lock
  #  sleep 60
  #  exit 0
  #fi
fi

# download and run
until wget mint.sh -O /tmp/mint.sh
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
