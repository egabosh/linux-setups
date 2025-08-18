Install sshfs via application management, or
```
sudo apt install sshfs
```
create the mount directory / mountpoint (replace USER-IN-MINT with your username in mint):
```
sudo mkdir -p /share
```
```
chown -R USER-IN-MINT /share
```
Open /etc/fstab with editor for example
```
sudo xed /etc/fstab
```
Attention - do not change anything, only add the following line at the end - replace "USER-ON-SERVER" with the sftp-user on the server, "SFTP-SERVER-HOST" with the hostname of the SFTP-Server and the "USER-IN-MINT" with your local username in Mint:
```
USER-ON-SERVER@SFTP-SERVER-HOST:/ /share fuse.sshfs  port=28,x-systemd.automount,_netdev,users,idmap=user,IdentityFile=/home/USER_IN_MINT/.ssh/id_ed25519,allow_other,reconnect 0 0
```
If you do not yet have an ed25519 keypair (~/.ssh/id\_ed25519 does not exist):
```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -P ""
```
Get Public key
```
cat ~/.ssh/id_ed25519.pub`
```
Then write the public-key to `/home/USER-ON-SERVER/.ssh/authorized_keys` on the server (replace USER-ON-SERVER with yout user on server-side)

Reload systemd
```
sudo systemctl daemon-reload`
```
mount:
```
sudo mount -a`
```
The targets should then be reached and the data should be mounted under /share if accessible from the network.
