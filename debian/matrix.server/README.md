# Dependencies
- debian.ansible.basics
- debian.ansible.docker
- debian.ansible.traefik.server

# Installation
```
ansible-playbook --connection=local --inventory $(hostname), --limit $(hostname) matrix.yml
```

# User Administration
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
docker compose -f /home/docker/matrix.$(hostname)/docker-compose.yml exec -ti matrix.defiant.$(hostname)--db psql -U $POSTGRES_USER -d synapse -c "SELECT name from users"
```

# Debugging
https://federationtester.matrix.org

