# Debian Ansible Basics
Basic configuration and software for Debian Systems. 
Most of it is needed for other playbooks. But it also installs software and creates configurations that I find helpful. 
For more informations please look at the yml-files. :-)

# Disclaimer
Use at your own risk.

Please look first at the playbooks downloaded and run by the install.sh to understand whats going on and then decide if it is fine for you to run on your system.

You also should test this on an non-productive Test-System to fit your needs.

# Prerequisites
You need a up-to-date and running Debian Linux system. Maybe some on Debian based Distributions will also work but are not tested.
I testet this in an minimal installation (+SSH Server) of Debian Bookworm which you can download here:

https://www.debian.org/releases/trixie/debian-installer/

https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-12.1.0-amd64-DVD-1.iso

# Quick-Install
Simply download an run install.sh and run it on you Debian(based) System:

## 1. Download Installation-Script
``` 
wget https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/install.sh
```

## 2. Run the Script
This runs the defined playbooks.
```
export PLAYBOOKS="debian/basics/basics.yml"
bash install.sh
```
