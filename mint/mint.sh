#!/bin/bash

mydomain="$1"
if [ -z "$mydomain" ] 
then
  [ -s "/etc/mydomain" ] && mydomain=$(head -n1 /etc/mydomain)
  [ -z "$mydomain" ] && mydomain=$(hostname)
fi

echo "!!! ACHTUNG !!!

Dieses Skript richtet Linux Mint nach bestimmten Vorgaben (größtenteils über Ansible Playbooks) ein und installiert neue Software
Dies setzt auch die Eingabe des sudo/root-Passwortes voraus. 

Der Code kann hier eingesehen werden:
https://github.com/egabosh/linux-setups/tree/main/mint

Nutzung auf einene Gefahr!!! Nur mit Enter/Return fortfahren wenn dieses Skript wirklich von der oben erwähnten Quelle stammt und Vertrauen besteht.
"

whoami | grep -q ^root$ || read x

## sudo without password
#echo '%adm ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/adm
#sudo chmod 640 /etc/sudoers.d/adm

## admin actions without password
#echo '/* Allow members of the adm group to execute any actions
# * without password authentication, similar to "sudo NOPASSWD:"
# */
#polkit.addRule(function(action, subject) {
#    if (subject.isInGroup("adm")) {
#        return polkit.Result.YES;
#    }
#});' | sudo tee /etc/polkit-1/rules.d/adm.rules
#sudo chmod 644 /etc/polkit-1/rules.d/adm.rules

# Check for using DoHoT
if [ -s /etc/dnscrypt-proxy/blocked-names.txt ]
then
  if [ -s /etc/dontusedohot ]
  then
    if [ -s /etc/systemd/resolved.conf.d/DoHoT.conf ] 
    then
      sudo rm -f /etc/systemd/resolved.conf.d/DoHoT.conf 
      sudo systemctl restart systemd-resolved.service
    fi
  fi
fi

# identify default user
defaultuser=$(getent passwd 1000 | cut -d: -f1)
defaultuserhome=$(getent passwd 1000 | cut -d: -f6)

# move data from element/signal flatpaks to default element/signal
if [ -d "$defaultuserhome/.var/app/org.signal.Signal/config/Signal" ] 
then 
   [ -d "$defaultuserhome/.config/Signal" ] || rsync -av "$defaultuserhome"/.var/app/org.signal.Signal/config/Signal/ "$defaultuserhome"/.config/Signal/
fi
if [ -d "$defaultuserhome/.var/app/im.riot.Riot/config/Element" ] 
then
  [ -d "$defaultuserhome/.config/Element" ] || rsync -av "$defaultuserhome"/.var/app/im.riot.Riot/config/Element/ "$defaultuserhome"/.config/Element/
fi

# hostname
if hostname | grep -q "^${defaultuser}-"
then
  # remove old whoogle path if available
  if [ -f /home/docker/whoogle.$(hostname)/docker-compose.yml ]
  then
    docker-compose -f /home/docker/whoogle.$(hostname)/docker-compose.yml down
    rm -rf /home/docker/whoogle.$(hostname)
  fi
  host=$(cat /etc/hostname | sudo sed "s/^${defaultuser}-//")
  hostnamectl set-hostname ${host}
fi  

# domainname
if ! egrep -q "\.mint.${mydomain}$" /etc/hostname
then
  # remove old whoogle path if available
  if [ -f /home/docker/whoogle.$(hostname)/docker-compose.yml ]
  then
    docker-compose -f /home/docker/whoogle.$(hostname)/docker-compose.yml down
    rm -rf /home/docker/whoogle.$(hostname)
  fi
  host=$(cat /etc/hostname | cut -d. -f1)
  hostnamectl set-hostname ${host}.mint.${mydomain}
fi

# fix for creating notify.sh dir from docker start if file not present
[ -d /usr/local/bin/notify.sh ] && rmdir /usr/local/bin/notify.sh

# remove old updater if exists
[ -f /etc/cron.d/mint-config-update ] && rm /etc/cron.d/mint-config-update 


# Cleanup broken installs and packages
sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge
sudo DEBIAN_FRONTEND=noninteractive apt-get -y autoclean
# Removes icaclient and videodownloadhelper aptitude search '~o'
#sudo DEBIAN_FRONTEND=noninteractive apt-get -y purge '~o'
sudo DEBIAN_FRONTEND=noninteractive apt-get -y purge '~o ~M !?reverse-depends(~i) !~E'

# systemupdate
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade

# install ansible
#if grep -q ^RELEASE=22 /etc/linuxmint/info
#then
#  sudo apt-get -y install ansible git
#else
#  sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3-pip git
#  sudo pip install ansible
#fi
which ansible >/dev/null 2>&1 || sudo apt-get -y install ansible git
sudo ansible-galaxy collection install community.general

# install mscore fonts
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install ttf-mscorefonts-installer
# get upstream release vars (needed for docker ubuntu repos)
. /etc/upstream-release/lsb-release

# prepare release update for next reboot
sudo sed -i 's/ vera / virginia /g' /etc/apt/sources.list.d/official-package-repositories.list
sudo sed -i 's/ vanessa / virginia /g' /etc/apt/sources.list.d/official-package-repositories.list
sudo sed -i 's/ victoria / virginia /g' /etc/apt/sources.list.d/official-package-repositories.list

# run ansible playbooks
cd
rm -rf linux-setups
git clone https://github.com/egabosh/linux-setups.git
cd linux-setups

for playbook in debian/basics/basics.yml \
 debian/firewall/firewall.yml \
 debian/runchecks/runchecks.yml \
 debian/backup/backup.yml \
 debian/autoupdate/autoupdate.yml \
 debian/docker/docker.yml \
 debian/traefik.server/traefik.yml \
 debian/whoogle/whoogle.yml \
 debian/tornet.network/tornet.yml \
 debian/vnet.network/vnet.yml \
 https://raw.githubusercontent.com/egabosh/gtc-crypt/refs/heads/main/gtc-crypt.yml \
 https://raw.githubusercontent.com/egabosh/gtc-rename/refs/heads/main/gtc-rename.yml \
 https://raw.githubusercontent.com/egabosh/gtc-media-compress/refs/heads/main/gtc-media-compress.yml \
 x11vnc-ssh/x11vnc-ssh.yml \
 mint/mint.yml \
 debian/firefox/firefox.yml \
 debian/chromium/chromium.yml \
 debian/signal-desktop/signal-desktop.yml \
 debian/element-desktop/element-desktop.yml
do
  echo "=== $playbook"
  if [ -s "$playbook" ]
  then
    sudo ansible-playbook -e ansible_distribution=${DISTRIB_ID} -e ansible_distribution_release=${DISTRIB_CODENAME} --connection=local --inventory $(hostname), --limit $(hostname) "${playbook}" || exit 2
  elif [[ $playbook =~ https:// ]]
  then
    playbookfile=$(basename "$playbook")
    if curl -L "$playbook" >~/"${playbookfile}"
    then
      sudo ansible-playbook -e ansible_distribution=${DISTRIB_ID} -e ansible_distribution_release=${DISTRIB_CODENAME} --connection=local --inventory $(hostname), --limit $(hostname) ~/"${playbookfile}" || exit 2
    else
      echo "Playbook $playbook could not be downloaded"
      exit 1
    fi
  else
    echo "Playbook $playbook not found"
    exit 1
  fi
#  sudo rm -rf ${playbook}
#  git clone https://XXXX.${mydomain}/olli/${playbook}.git
#  sudo ansible-playbook -e ansible_distribution=${DISTRIB_ID} -e ansible_distribution_release=${DISTRIB_CODENAME} --connection=local --inventory $(hostname), --limit $(hostname) ${playbook}/*.yml || exit 1
#  sudo rm -rf ${playbook}
done

sudo bash /usr/local/sbin/autoupdate.sh

# Add User to docker group
sudo usermod -aG docker ${defaultuser}

# Add User to vboxusers group
sudo usermod -aG vboxusers ${defaultuser}


# Personal settings with .xsessionrc
sudo cat <<EOF >${defaultuserhome}/.xsessionrc
#!/bin/bash

# Clean GPU Cache of Element
# https://github.com/vector-im/element-web/issues/25776
rm -rf ~/.var/app/im.riot.Riot/config/Element/GPUCache

# Backup #only if autologin deactivated
#if ! grep -qr ^autologin-user= /etc/lightdm 
#then 
  if [ -f ~/Nextcloud/scripts/backup-this-device.sh ]
  then
    gnome-terminal --hide-menubar --title=BACKUP --geometry=120x35 -- bash ~/Nextcloud/scripts/backup-this-device.sh
  elif [ -f ~/scripts/backup-this-device.sh ]
  then
    gnome-terminal --hide-menubar --title=BACKUP --geometry=120x35 -- bash ~/scripts/backup-this-device.sh
  elif [ -f ~/.scripts/backup-this-device.sh ]
  then
    gnome-terminal --hide-menubar --title=BACKUP --geometry=120x35 -- bash ~/.scripts/backup-this-device.sh
  fi
#fi

# Autoupdate flatpak and cinnamon
dconf write /com/linuxmint/updates/auto-update-cinnamon-spices true
dconf write /com/linuxmint/updates/auto-update-flatpaks true

if ! [ -s ~/.initial-mint-config-by-xsessionrc ]
then

  # disable saving recent files
  dconf write /org/cinnamon/desktop/privacy/remember-recent-files false

  # Touchpad Scrolling
  dconf write /org/cinnamon/desktop/peripherals/touchpad/edge-scrolling-enabled true
  dconf write /org/cinnamon/desktop/peripherals/touchpad/two-finger-scrolling-enabled false

  # Terminal font Terminus
  termprofile=\$(dconf dump /org/gnome/terminal/legacy/profiles:/ | grep '^\\[:' | cut -d : -f2 | cut -d] -f1)
  dconf write "/org/gnome/terminal/legacy/profiles:/:\${termprofile}/font" "'Terminus (TTF) Medium 12'"

  # Winkey+l=Locksreen
  dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/command '"cinnamon-screensaver-command --lock"'
  dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/binding "['<Mod4>l']"
  dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/name '"Lockscreen"'
  dconf write /org/cinnamon/desktop/keybindings/custom-list "['__dummy__']"
  
  # dark theme
  dconf write /org/cinnamon/desktop/interface/gtk-theme "'Mint-Y-Dark'"
  dconf write /org/cinnamon/desktop/interface/icon-theme "'Mint-Y'"
  dconf write /org/cinnamon/theme/name "'Mint-Y-Dark'"
  dconf write /org/gnome/desktop/interface/icon-theme "'Mint-Y-Dark'"
  dconf write /org/gnome/desktop/interface/gtk-theme "'Mint-Y-Dark'"
 
  # Nemo Filemanager Settings
  dconf write /org/nemo/preferences/default-folder-viewer "'list-view'"
  dconf write /org/nemo/preferences/show-location-entry true

  # Traditional Cinnamon task bar (https://forums.linuxmint.com/viewtopic.php?t=321872)
  dconf write /org/cinnamon/panels-enabled "['1:0:bottom']"
  dconf write /org/cinnamon/panels-height "['1:27']"
  dconf write /org/cinnamon/panel-zone-icon-sizes '[{"left":0,"center":0,"right":0,"panelId":1}]'
  dconf write /org/cinnamon/enabled-applets "['panel1:left:0:menu@cinnamon.org','panel1:left:1:show-desktop@cinnamon.org','panel1:left:2:panel-launchers@cinnamon.org','panel1:left:3:window-list@cinnamon.org','panel1:right:0:systray@cinnamon.org','panel1:right:1:xapp-status@cinnamon.org','panel1:right:2:keyboard@cinnamon.org','panel1:right:3:notifications@cinnamon.org','panel1:right:4:printers@cinnamon.org','panel1:right:5:removable-drives@cinnamon.org','panel1:right:6:user@cinnamon.org','panel1:right:7:network@cinnamon.org','panel1:right:8:sound@cinnamon.org','panel1:right:9:power@cinnamon.org','panel1:right:10:calendar@cinnamon.org']"

  date >> ~/.initial-mint-config-by-xsessionrc

fi

[ -x ~/.xsessionrc.followup ] && ~/.xsessionrc.followup
EOF

sudo chmod 700 "${defaultuserhome}"/.xsessionrc 
sudo chown ${defaultuser}. "${defaultuserhome}"/.xsessionrc

date
echo done
