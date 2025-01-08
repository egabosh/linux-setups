#!/bin/bash

# https://www.raspberrypi.com/documentation/computers/configuration.html
raspi-config nonint do_ssh 0
raspi-config nonint do_vnc 0
raspi-config nonint do_change_locale de_DE.UTF-8
raspi-config nonint do_boot_splash 1
raspi-config nonint do_boot_behaviour B4
raspi-config nonint do_blanking 1
raspi-config nonint do_serial_hw 1
raspi-config nonint do_onewire 0
raspi-config nonint do_rgpio 1
raspi-config nonint do_audioconf 2
raspi-config nonint do_wayland W1

#apt -y install flatpak
#flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo 'en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
de_DE.UTF-8 UTF-8' >/etc/locale.gen
locale-gen

echo 'LANG=de_DE.UTF-8
LANGUAGE=de_DE
LC_CTYPE="de_DE.UTF-8"
LC_NUMERIC="de_DE.UTF-8"
LC_TIME="de_DE.UTF-8"
LC_COLLATE="de_DE.UTF-8"
LC_MONETARY="de_DE.UTF-8"
LC_MESSAGES="de_DE.UTF-8"
LC_PAPER="de_DE.UTF-8"
LC_NAME="de_DE.UTF-8"
LC_ADDRESS="de_DE.UTF-8"
LC_TELEPHONE="de_DE.UTF-8"
LC_MEASUREMENT="de_DE.UTF-8"
LC_IDENTIFICATION="de_DE.UTF-8"
LC_ALL="de_DE.UTF-8"
' >/etc/default/locale
update-locale

apt-get update

# autoupdate after startup
echo "@reboot root /usr/local/sbin/autoupdate.sh" >>/etc/crontab

cd /root
rm -f install.sh
wget https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/install.sh


export PLAYBOOKS="debian.ansible.basics
gtc-rename
gtc-crypt
debian.ansible.firewall
debian.ansible.kodi
debian.ansible.autoupdate
debian.ansible.docker
debian.ansible.traefik.server
debian.ansible.whoogle
debian.ansible.flatpak
firefox
chromium"
bash install.sh

# get user
user=$(id -u 1000 -n)

# pi-apps (for signal etc.)
#su - ${user} -c "wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash"

# Signal desktop (over pi-apps GUI)
#https://github.com/dennisameling/Signal-Desktop/releases/download/v7.27.0/signal-desktop-unofficial_7.27.0_arm64.deb
#dpkg -i signal-desktop-unofficial_7.27.0_arm64.deb

# boot in graphic
#systemctl set-default graphical.target

# Personal settings with .xsessionrc
sudo cat <<EOF >/home/${user}/.xsessionrc
#!/bin/bash

# Clean GPU Cache of Element
# https://github.com/vector-im/element-web/issues/25776
rm -rf ~/.var/app/im.riot.Riot/config/Element/GPUCache

# Backup only if autologin deactivated
if ! grep -qr ^autologin-user= /etc/lightdm 
then 
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
fi

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

#gnome-terminal --hide-menubar --title=share.sh --maximize  -- ~/share.sh

EOF

# autostart kodi in desktop
mkdir -p /home/${user}/.config/autostart
cp /usr/share/applications/kodi.desktop /home/${user}/.config/autostart/kodi.desktop

# rights
chmod 700 /home/${user} /home/${user}/.xsessionrc /home/${user}/.config /home/${user}/.config/autostart /home/${user}/.config/autostart/kodi.desktop
chown ${user}: /home/${user} /home/${user}/.xsessionrc /home/${user}/.config /home/${user}/.config/autostart /home/${user}/.config/autostart/kodi.desktop


# install (new) addons
[ -d /home/${user}/.kodi/addons ] || mkdir -p /home/${user}/.kodi/addons
cd /home/${user}/.kodi/addons

# mediathekview repo
if ! [ -d  repository.mediathekview ]
then
  wget https://kodirepo.mediathekview.de/repo-mv/repository.mediathekview/repository.mediathekview-1.0.0.zip
  unzip repository.mediathekview-1.0.0.zip
fi

## officiall addons
# german lang
if ! [ -d resource.language.de_de ]
then
  wget https://mirrors.kodi.tv/addons/omega/resource.language.de_de/resource.language.de_de-11.0.80.zip
  unzip resource.language.de_de-11.0.80.zip
fi

# invidious
if ! [ -d plugin.video.invidious ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.video.invidious/plugin.video.invidious-0.2.7+nexus.0.zip
  unzip plugin.video.invidious-0.2.7+nexus.0.zip
fi
# podcasts
if ! [ -d plugin.audio.podcasts ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.audio.podcasts/plugin.audio.podcasts-2.3.2.zip
  unzip plugin.audio.podcasts-2.3.2.zip
fi
# ct uplink
if ! [ -d plugin.video.ctuplinkrss ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.video.ctuplinkrss/plugin.video.ctuplinkrss-1.3.zip
  unzip plugin.video.ctuplinkrss-1.3.zip
fi
# vimeo
if ! [ -d plugin.video.vimeo ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.video.vimeo/plugin.video.vimeo-6.0.1.zip
  unzip plugin.video.vimeo-6.0.1.zip
fi
# fosdem
if ! [ -d plugin.video.fosdem ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.video.fosdem/plugin.video.fosdem-0.0.8+matrix.1.zip
  unzip plugin.video.fosdem-0.0.8+matrix.1.zip
fi
# ampache
if ! [ -d plugin.audio.ampache ]
then
  wget https://mirrors.kodi.tv/addons/omega/plugin.audio.ampache/plugin.audio.ampache-3.1.0+matrix.1.zip
  unzip plugin.audio.ampache-3.1.0+matrix.1.zip
fi

## create (new) kodi presets
cd /home/${user}
[ -d debian.ansible.kodi ] && rm -r debian.ansible.kodi
git clone https://github.com/egabosh/linux-setups.git
chown -R ${user}: linux-setups
rsync -av --ignore-existing  linux-setups/debian/kodi/kodi-settings/ /home/${user}/.kodi/

# rights kodi
chown -R ${user}: /home/${user}/.kodi

# ssh keys
[ -e /home/${user}/.ssh/id_ed25519.pub ] || su - ${user} -c 'ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q'



