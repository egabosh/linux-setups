# DynDNS with dedyn/deSEC (https://desec.io)

This is needed if you want to make services available from the Internet from a changing (dynamic) IP (widely used for private intrnet connections). This may also be needed to validate SSL-ACME-Challenges used by letsencrypt.
deSEC is my preferred DNS provider but there are others too.

# Disclaimer

Use at your own risk.

Please look first at the playbooks downloaded and run by the install.sh to understand whats going on and then decide if it is fine for you to run on your system.

You also should test this on an non-productive Test-System to fit your needs.

# Quick-Install

## 1. Create an account on the https://desec.io/ website

## 2. Create a domain - Click on + in https://desec.io/domains

## 3. Create a CNAME wildcard for your domain 
  - click on your domain
  - click on "+"
  - Record Set Type: CNAME
  - Subname: *
  - Target hostname: choosen-domainname.dedyn.io.  (finalizing "." is important)
  - click on "Save"

## 4. Get an auth Token
  - click on "Token Management"
  - click on "+"
  - optinally give a name
  - click on "Save"
  - copy your "token's secret value"

## 5. SSH into your Server and write the config customized with your data:

```
echo 'dedynpw="TOKENS_SECRET_VALUE_FROM_DESEC"
dedynhosts="choosen-domainname.dedyn.io"
# should IPv6 be done? possible are "yes", "no" or "only"
doipv6="yes"' >/usr/local/etc/dedyn.conf
```

## 6. Download
``` 
wget https://github.com/egabosh/linux-setups/raw/refs/heads/main/debian/install.sh
```

## 7. Run the Script
This runs some other Playbooks needed by this playbook.
```
export PLAYBOOKS="
debian.ansible.basics
debian.ansible.runchecks
debian.ansible.autoupdate
debian.ansible.dedyn.client
"
bash install.sh
```

# After the Installation
- When changing IP, the address should update every half hour
- you can manually or check update with ```sudo dedyn.sh```
- you probably have to create some Portforwardings or IPv6-forwardings in your Internet-Router to be able to access your device from the Internet if you are a private user. Often used ports are 80 and 443 for http and https for example.
