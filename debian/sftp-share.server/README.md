# Client

## Install sshfs
`sudo apt install sshfs`

## edit /etc/fstab:
only add the following line. Do not change something else. Can damage your system. Change myserveruser myserver and myclientuser
`myserveruser@myserver:/share/Media /share/Media fuse.sshfs  port=28,x-systemd.automount,_netdev,users,idmap=user,IdentityFile=/home/myclientuser/.ssh/id_ed25519,allow_other,reconnect 0 0`

## create ed25519 ssh key as user if not exists
`ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -P ""`

## get pubkey
`cat ~/.ssh/id_ed25519.pub`
and put to authorized_keys on server

## mount-Verzeichnis erstellen

`mkdir -p /share/Media`
`chown -R deinuser /share/Media`

## reload systemd
`sudo systemctl daemon-reload`

## mount
`sudo mount -a`

