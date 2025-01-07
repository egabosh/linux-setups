# WARNING: All your data will be deleted!!!
# install mint
- boot from Mint medium (https://linuxmint-installation-guide.readthedocs.io/en/latest/burn.html)
- click on install

## for encrypted disk
- at "Installation type" choose "Erase disk and install Linux Mint" and "Advanced features"
- Check "Use LVM with the new Linux Mint installation" and "Encrypt the new Linux Mint installation for security"
- follow further instructions
- possibly use user autologin and home without encryption because the LVM volume underneath is already encrypted.

# after installation (if you want to use my setup)
boot the new installed linux mint system
## set your domainname and your target server if you want to use x11vnc with SSH
```
# domain for the system
echo "subdomain.domain.tld" | sudo tee /etc/mydomain
# host which should be connected with x11vnc over SSH
echo "user@target-ssh-server-for-x11vnc-ssh" | sudo tee /etc/x11vnc-ssh-target
```
## download and run my setup scripts:
```
wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/mint/mint.sh
bash mint.sh
```
better reboot after first run to see more verbose boot progress and load changed Cinnamon design
