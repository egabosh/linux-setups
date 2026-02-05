# Install (example for Linksys MR8300)
## First flash to old Version 22.03.7 for upgrading partition tables
```
wget http://downloads.openwrt.org/releases/22.03.7/targets/ipq40xx/generic/openwrt-22.03.7-ipq40xx-generic-linksys_mr8300-squashfs-factory.bin
```
firefox http://192.168.1.1/fwupdate.html
(alternative maybe http://192.168.1.1:52000/fwupdate.html)
User: admin; PW: admin


Wait until LED is blue (bootup finished). 

## resize partition and reboot
```
# set value
ssh 192.168.1.1 "fw_setenv kernsize 500000"
# check value
ssh 192.168.1.1 "fw_printenv"
# reboot
ssh 192.168.1.1 "reboot"
```

## Flash current version
Download current Sysupgrade-Image from 
https://openwrt.org/toh/hwdata/linksys/linksys_mr8300
"Firmware OpenWrt Install URL"

and install via
firefox http://192.168.1.1/cgi-bin/luci/admin/system/flash
"Flash new firmware image"

# Upgrade
Download Sysupgrade-Image from
https://openwrt.org/toh/hwdata/linksys/linksys_mr8300
"Firmware OpenWrt Upgrade URL"

and istall via
firefox http://192.168.1.1/cgi-bin/luci/admin/system/flash
"Flash new firmware image"


# Initial Manual Steps via WebUI or SSH
defaults: IP=192.168.1.1; dhcp=enabled
- set password (System -> Administration)
```
passwd
```
- add SSH-Keys (System -> Administration -> SSH Keys)
```
vim /etc/dropbear/authorized_keys
```
- disable dhcp-server to prevent problems in LAN (System -> Startup -> dnsmasq disable/stop)
```
/etc/init.d/dnsmasq stop
/etc/init.d/dnsmasq disable
```
- enable Network/Internet access (Set IP/Gateway/DNS via Network -> Interfaces -> Edit (lan))
```
# change to your local network needs
uci set network.lan.ipaddr='172.23.0.219'
uci set network.lan.netmask='255.255.0.0'
uci commit
/etc/init.d/network restart
```
