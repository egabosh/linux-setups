# install mint
- boot from Mint medium
- click on install

## for encrypted disk


# prepare your ENV
```
# domain for the system
echo "subdomain.domain.tld" | sudo tee /etc/mydomain
# host which should be connected with x11vnc over SSH
echo "user@target-ssh-server-for-x11vnc-ssh" | sudo tee /etc/x11vnc-ssh-target
```
