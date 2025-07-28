#!/bin/bash

set -e

echo "Add ChirpStack APT Repository"

cat > /etc/apt/sources.list.d/chirpstack_4.list << EOF
deb https://artifacts.chirpstack.io/packages/4.x/deb stable main
EOF

curl --fail "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1ce2afd36dbcca00" | \
    gpg --dearmor --batch --yes | \
    sudo tee /etc/apt/trusted.gpg.d/chirpstack_4.gpg > /dev/null

sudo apt update

echo "Install Required Packages"
apt install --yes chirpstack chirpstack-gateway-bridge \
    postgresql postgresql-client postgresql-contrib \
    mosquitto mosquitto-clients redis

echo "Initialize PostgreSQL for ChirpStack"
POSTGRES_DATA_DIR="/var/lib/postgresql/17/main"

if [ -d "$POSTGRES_DATA_DIR" ] && [ "$(ls -A $POSTGRES_DATA_DIR)" ]; then
    echo "PostgreSQL data directory already initialized at $POSTGRES_DATA_DIR"
else
    echo "Initializing PostgreSQL database cluster..."
    su -l postgres -c "initdb --pgdata='$POSTGRES_DATA_DIR' --auth='trust'"
fi

echo "Enabling and starting PostgreSQL service..."
systemctl enable postgresql --now

# Create role if not exists
su - postgres -c "psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='chirpstack'\" | grep -q 1 || psql -c \"CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';\""

# Create database if not exists
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='chirpstack'\" | grep -q 1 || psql -c \"CREATE DATABASE chirpstack WITH OWNER chirpstack;\""

# Create extension if not exists
su - postgres -c "psql -d chirpstack -c \"CREATE EXTENSION IF NOT EXISTS pg_trgm;\""

echo "Enable ChirpStack"
systemctl enable chirpstack --now

sleep 2

echo "Setup Gateway Bridge"

systemctl enable chirpstack-gateway-bridge --now

echo "Configure Mosquitto MQTT Broker"

mkdir -p /etc/mosquitto/conf.d/

grep -qxF "include_dir /etc/mosquitto/conf.d/" /etc/mosquitto/mosquitto.conf || \
echo "include_dir /etc/mosquitto/conf.d/" | tee -a /etc/mosquitto/mosquitto.conf

cat > /etc/mosquitto/conf.d/local.conf << EOF
listener 1883 0.0.0.0
allow_anonymous true
EOF

systemctl enable mosquitto --now

echo "SETUP COMPLETE"
exit 0