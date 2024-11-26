# Ansible Playbook for running/installing Nextcloud via Docker

# Disclaimer
Use at your own risk.

Please look first at the playbooks downloaded and run by the install.sh to understand whats going on and then decide if it is fine for you to run on your system.

You also should test this on an non-productive Test-System to fit your needs.

# Prerequisites
This is needed for Downloading the Software, access to the Server from the Internet and the automatized creation of SSL-Certificates via letsencrypt.
- You need up-to-date Debian System preinstalled. Best with SSH-Connection. Maybe its working on debian-based Systems like Ubuntu too.
- Your System should have a working Internet-Access
- Your Machines hostname and subdomains should be accessible from the internet Port 80/443.
Depending on your local setup you have to define needed IPv4 (Portforwarding) or IPv6 settings on your router and maybe you need a service like dynDNS for example from (deSEC - https://desec.io/) for your dynamic IP.
You can check this for example with the following command:
```
host nextcloud.$(hostname)
```
Change the hostname with the following command for example with dedyn/deSEC to myhost.dedyn.io:
```
su -c "hostnamectl hostname myhost.dedyn.io"
```
More informations can be found here: https://github/olli/debian.ansible.dedyn.client

# Quick-Install
Simply download an run install.sh and run it on you Debian(based) System:

## 1. Download Installation-Script
``` 
wget https://github/olli/debian.ansible.basics/raw/branch/main/install.sh
```

## 2. Run the Script
This runs the defined playbooks.
```
export PLAYBOOKS="
debian.ansible.basics
debian.ansible.runchecks
debian.ansible.backup
debian.ansible.autoupdate
debian.ansible.dedyn.client
debian.ansible.docker
debian.ansible.traefik.server
debian.ansible.firewall
debian.ansible.turn.server
debian.ansible.nextcloud.server
"
bash install.sh
```

# After the Installation
- Your Admin-User is "ncadmin".
- Password can be found with the command: ``` sudo cat /home/docker/nextcloud.$(hostname)/env ```
- Login with your Webbroser as ncadmin https://nextcloud.$(hostname) and first change the password.
