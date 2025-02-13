# Kodi and Linux Desktop Installation and Configuration
This installs and Configures the following:
- Kodi
- Cinnamon Desktop
- LightDM Autologin
- Specific Raspberry Settings
# Some predefined Kodi settings
- German localization
- Simple IPTV with german TV channels
- Autoupdate Addons
- optional predefined repos for Mediathekview and Jellyfin (asks for activation at first start)
- Some other optional addons (asks for activation at first start
- ...
## Raspberry 4/5
### Install Raspberry Pi OS
- Downlaod/Install/Start Raspberry Pi Imager (https://www.raspberrypi.com/software/)
- Model: Raspberry Pi 4/5
- OS: Raspberry Pi OS (64 Bit) (with the Raspberry Pi Desktop)
- Choose SD-Card (should be \>= 32GB - 16GB may be barely enough)
- Click on "Continue" and edit individual settings
- Define Username "user".
- Optional: Provide WLAN-Keys and/or SSH-Keys
- Let the Imager prepare the SD-Card
### after install
- Boot your Pi with the prepared SD-Card
#### Login
replace \<IP\>with the IP of your pi.
```
ssh user@<IP>
```
Alternative use a Terminal on the Pi
#### sudo to root
```
sudo su -
```
#### Optional: SSH-Keys for root
```
cp -r /home/user/.ssh /root/
chown root: /root/.ssh
```
#### Optional: Set hostname
replace \<myhostname\> with the preferred hostname
```
echo <myhostname> >/etc/hostname
systemctl restart systemd-hostnamed.service
```
#### run installation/configuration (as root)
```
wget https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/kodi/raspi.sh
bash -ex raspi.sh
```
## Reboot and Kodi should start
```
reboot
```
To switch to Linux Desktop Cinnamon simply exit Kodi.
## Kodi Remote Password
Please change the remote password in Kodi "Settings -> Services" (defaults to xxxx).
