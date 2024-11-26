# functional test:
```
apt -y install coturn
. /home/docker/turn.$(hostname)/env
turnutils_uclient -p 5349 -W $TURN_SECRET -v -y turn.$(hostname).
apt remove --purge coturn
```
