# Dependencies
- debian.ansible.basics
- debian.ansible.docker
- debian.ansible.traefik.server

# Installation
```
ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) matrix.yml
```

# Admin UI
https://matrix-admin.HOSTNAME
Admin User: mx-admin
Initial password: `cat /home/docker/matrix.$(hostname)/env`

# Administration vial CLI
Admin User is created while installation.
Username: mx-admin
Password can be found with 
```
cat /home/docker/matrix.$(hostname)/env
```
Create a new user with
```
docker compose -f /home/docker/matrix.$(hostname)/docker-compose.yml exec -ti matrix.$(hostname)--synapse register_new_matrix_user -c /data/homeserver.yaml --no-admin http://localhost:8008
```
List users
```
. /home/docker/matrix.$(hostname)/env
docker compose -f /home/docker/matrix.$(hostname)/docker-compose.yml exec -ti matrix.$(hostname)--db psql -U $POSTGRES_USER -d synapse -c "SELECT name from users"
```

# Rooms (Groups)
Create room (group)
```
docker compose -f /home/docker/matrix.$(hostname)/docker-compose.yml run -T matrix.$(hostname)--commander --room-create MYRPOOMNAME
```

Invite user to room (group)
```
docker compose -f /home/docker/matrix.$(hostname)/docker-compose.yml run -ti matrix.$(hostname)--commander --room-invite MYROOMNAME --user @USERNAME:matrix.$(hostname)
```

Create pipes for rooms and containers to push messages
```
bash /home/docker/matrix.$(hostname)/pipe-rooms.sh
```

# External Check
https://federationtester.matrix.org

