Install sshfs via application management, or
```
sudo apt install sshfs
```
This variant runs completely in user context with `systemd --user`. No `sudo`, no `/etc/fstab`, no `/etc/fuse.conf` change needed. See `README_SFTP_CLIENT.md` for the system-wide variant via fstab.

If you do not yet have an ed25519 keypair (`~/.ssh/id_ed25519` does not exist):
```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -P ""
```
Get public key
```
cat ~/.ssh/id_ed25519.pub
```
Then write the public-key to `/home/USER-ON-SERVER/.ssh/authorized_keys` on the server (replace USER-ON-SERVER with your user on server-side).

Create the user systemd directory (replace USER-IN-MINT with your username in mint, only needed for the path - normally this is just `~/.config/systemd/user`):
```
mkdir -p ~/.config/systemd/user
```
Open `~/.config/systemd/user/netdrive.service` with an editor for example
```
xed ~/.config/systemd/user/netdrive.service
```
with the following content - replace `USER-ON-SERVER` with the sftp-user on the server and `SFTP-SERVER-HOST` with the hostname of the SFTP-Server. `%h` is automatically your home directory, mountpoint is `~/Netdrive` (change both occurrences if you want another name):
```
[Unit]
Description=Netdrive SSHFS mount
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/mkdir -p %h/Netdrive
ExecStartPre=/usr/bin/sleep 3
ExecStart=/usr/bin/sshfs -p 28 -o reconnect,idmap=user,kernel_cache,ConnectTimeout=10,ServerAliveInterval=15,ServerAliveCountMax=3,_netdev USER-ON-SERVER@SFTP-SERVER-HOST:/share %h/Netdrive
ExecStop=/usr/bin/fusermount3 -u %h/Netdrive

[Install]
WantedBy=default.target
```
Concrete example (`user@tor-nas.dedyn.io:/share` mounted to `/home/user/Netdrive`):
```
ExecStart=/usr/bin/sshfs -p 28 -o reconnect,idmap=user,kernel_cache,ConnectTimeout=10,ServerAliveInterval=15,ServerAliveCountMax=3,_netdev user@tor-nas.dedyn.io:/share %h/Netdrive
```

Reload user systemd and enable + start (no sudo):
```
systemctl --user daemon-reload
systemctl --user enable --now netdrive.service
```
Check status and logs:
```
systemctl --user status netdrive.service
journalctl --user -u netdrive.service
ls ~/Netdrive
```
The data should then be mounted under `~/Netdrive` if accessible from the network. The mount comes back automatically after login / reboot (`WantedBy=default.target`).

Manual start / stop:
```
systemctl --user start netdrive.service
systemctl --user stop netdrive.service
```

Optional: enable linger so the user service also stays active without graphical login (e.g. for autostart / headless):
```
loginctl enable-linger $USER
```

Optional: disable / remove again:
```
systemctl --user disable --now netdrive.service
rm ~/.config/systemd/user/netdrive.service
systemctl --user daemon-reload
```
