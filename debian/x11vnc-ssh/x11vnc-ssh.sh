#!/bin/bash
# This starts a VNC-Server with the current users X11-Desktop piped through SSH

. /etc/bash/gaboshlib.include

userathost="$1"
port="$2"

if [ -z "$userathost" ] 
then 
  [ -s "/etc/x11vnc-ssh-target" ] && userathost=$(head -n1 /etc/x11vnc-ssh-target)
  [ -z $userathost ] && userathost=$(hostname)
fi
[ -z "$port" ] && port=8081

# kill existing Session
tmux kill-session -t x11vnc2ssh >/dev/null 2>&1

sshopts="-p $port -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -o PreferredAuthentications=publickey $userathost"

g_echo "Testing SSH-Connection to $userathost:$port"
ssh $sshopts >/dev/null 2>&1
if [ $? == 255 ];then
  g_echo_error "SSH connection could not be established!!"
  if ! [ -e ~/.ssh/id_ed25519.pub  ]
  then
    g_echo "Creating SSH PublicKey pair"
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
  fi
  g_echo "Please provide the admin of the target server with the following PublicKey:"
  cat ~/.ssh/id_ed25519.pub
  echo "Press Enter/Return to exit"
  read x
  exit 255
fi


tmux new -s x11vnc2ssh \
 'echo "Service started! Press Enter/Return to exit"; read x ; tmux kill-session -t x11vnc2ssh' \; select-layout even-vertical\; \
 split-window -d "set -x ; ssh -N -o RemoteForward=\"5900 localhost:5900\" $sshopts; read x"  \; select-layout even-vertical \; \
 split-window -d 'set -x ; x11vnc -q -nopw -auth guess -forever -loop -noxdamage -nomodtweak -noxkb -repeat -rfbport 5900 -shared -localhost ; read x' \; select-layout even-vertical

