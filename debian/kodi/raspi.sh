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

wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/debian/install.sh -O /usr/local/sbin/linux_setups_debian_install.sh
chmod 700 /usr/local/sbin/linux_setups_debian_install.sh

export PLAYBOOKS="debian/basics/basics.yml
debian/basics/localization-de.yml
https://raw.githubusercontent.com/egabosh/gtc-rename/refs/heads/main/gtc-rename.yml 
https://raw.githubusercontent.com/egabosh/gtc-crypt/refs/heads/main/gtc-crypt.yml
debian/firewall/firewall.yml
debian/kodi/kodi.yml
debian/autoupdate/autoupdate.yml
debian/docker/docker.yml
debian/traefik.server/traefik.yml
debian/whoogle/whoogle.yml
debian/flatpak/flatpak.yml
debian/firefox/firefox.yml
debian/chromium/chromium.yml"

echo $PLAYBOOKS >/usr/local/etc/playbooks
/usr/local/sbin/linux_setups_debian_install.sh

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

function install_kodi_addon {
  local addon=$1
  [ -d /home/${user}/.kodi/addons ] || mkdir -p /home/${user}/.kodi/addons
  cd /home/${user}/.kodi/addons
  if ! [ -d  "${addon}" ]
  then
     addonvers=$(wget -q https://mirrors.kodi.tv/addons/omega/${addon}/ -O - | egrep "${addon}-.+\.zip" | tail -n1 | cut -d\" -f2)
     wget https://mirrors.kodi.tv/addons/omega/${addon}/${addonvers}
     unzip repository.mediathekview-1.0.0.zip
  fi
}

install_kodi_addon resource.language.de_de
install_kodi_addon plugin.video.invidious
install_kodi_addon plugin.audio.podcasts
install_kodi_addon plugin.video.ctuplinkrss
install_kodi_addon plugin.video.vimeo
install_kodi_addon plugin.video.fosdem

# mediathekview repo
if ! [ -d  repository.mediathekview ]
then
  wget https://kodirepo.mediathekview.de/repo-mv/repository.mediathekview/repository.mediathekview-1.0.0.zip
  unzip repository.mediathekview-1.0.0.zip
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



