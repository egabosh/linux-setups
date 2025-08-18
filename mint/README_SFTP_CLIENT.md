Install sshfs via application management, or

`sudo apt install sshfs`

Open /etc/fstab with editor for example

`sudo xed /etc/fstab`

Attention - do not change anything or add the following line at the end - replace the "user" with your local username in Mint and "sftp-server" with the hostname of the SFTP-Server:

`user@sftp-server:/ /share fuse.sshfs  port=28,x-systemd.automount,_netdev,users,idmap=user,IdentityFile=/home/user/.ssh/id_ed25519,allow_other,reconnect 0 0`

If you do not yet have an ed25519 keypair (~/.ssh/id\_ed25519 does not exist):

`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -P ""`

Get Public key

`cat ~/.ssh/id_ed25519.pub`

Then write the public-key to /home/user/.ssh/authorized_keys on the server (replace user with yout user on server-side)

create the mount directory:

`sudo mkdir -p /share`

`chown -R user /share`

Reload systemd

`sudo systemctl daemon-reload`

mount:

`sudo mount -a`

The targets should then be reached and the data should be mounted under /share if accessible from the network.
