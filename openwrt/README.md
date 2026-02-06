# Install (example for Linksys MR8300)

see: https://openwrt.org/toh/linksys/mr8300

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
Download current Factory-Image from 
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

# Usage of playbooks for configuring/installing the router
## Internet Access 
### Provider
with "Deutsche Telekom" or other ISP using the network like partially 1und1 (VLAN7).

Dualstack (IPv4 and IPv6).

Needs FTTH or VDSL Modem on WAN-Port.

Needed variables:
- pppoe_user: Username from yout ISP
- pppoe_pw: Password from your ISP
```
ansible-playbook -i ROUTER_IP_OR_NAME, -u root -e "pppoe_pw=PASSWORD pppoe_user=USERNAME" internet_telekom_ftth.yml
```
Default firewall rules for Internet
```
ansible-playbook -i ROUTER_IP_OR_NAME, -u root firewall_internet_defaults.yml
```

### Or/Alternative: Gateway from other router + DNS
Needed variables:
- gw: IP of your Gateway
- dns: IP of Your DNS Server
```
ansible-playbook -i ROUTER_IP_OR_NAME, -u root -e "gw=192.168.178.1 dns=192.168.178.1" basics-slave.yml
```

## basic settings
basic settings like ipv4/ipv6, timezone, ntp,...

basic software (opkg packages)

Needed variables:
- ip: private IPv4 IP
- mask: IPv4 netmask
- ip6: private IPv6 IP
- ipv6_ula_prefix: ULA Prefix for private IPv6 IPs
- timezone: your timezone
- ntp_server: NTP Server
```
ansible-playbook -i ROUTER_IP_OR_NAME, -u root -e "ip=172.23.0.1 mask=255.255.0.0 ip6=fd12:3456:23::1/64 ipv6_ula_prefix=fd12:3456::/48 timezone=CET-1CEST,M3.5.0,M10.5.0/3 ntp_server=192.168.178.1" basics.yml
```

## log server
define log server (syslog)

Needed variables:
- logserver: IP or Hostname of Log Server 
```
ansible-playbook -i ROUTER_IP_OR_NAME, -u root -e "logserver=172.23.0.42 logserver.yml
```

## firewall

basic firewall policies
```
ansible-playbook -i openwrt-og,$slaves -u root firewall.yml
```
