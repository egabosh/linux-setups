sudo apt -y install x11vnc tmux
sudo wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/debian/x11vnc-ssh/x11vnc-ssh.sh -O /usr/local/bin/x11vnc-ssh.sh
sudo chmod 755 /usr/local/bin/x11vnc-ssh.sh
sudo wget https://raw.githubusercontent.com/egabosh/linux-setups/refs/heads/main/debian/x11vnc-ssh/x11vnc-ssh.desktop -O /usr/share/applications/x11vnc-ssh.desktop
sudo chmod 644 /usr/share/applications/x11vnc-ssh.desktop
echo "sshtunnel@defiant.dedyn.io" | sudo tee /etc/x11vnc-ssh-target
sudo apt -y install git
git clone https://github.com/egabosh/gaboshlib.git
sudo mkdir -p /etc/bash
sudo mv gaboshlib/gaboshlib gaboshlib/gaboshlib.include /etc/bash/
rm -rf gaboshlib
