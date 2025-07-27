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

echo "Initialize PostgreSQL for ChirpStack
su -l postgres -c "/usr/bin/initdb --pgdata='/var/lib/postgresql/data' --auth='trust'"
systemctl enable postgresql --now

su - postgres -c "psql -c \"CREATE ROLE chirpstack WITH LOGIN PASSWORD 'chirpstack';\""
su - postgres -c "psql -c \"CREATE DATABASE chirpstack WITH OWNER chirpstack;\""
su - postgres -c "psql -d chirpstack -c \"CREATE EXTENSION pg_trgm;\""

echo "Enable ChirpStack"
systemctl enable chirpstack --now

sleep 2

# Optional: Pre-populate a dummy gateway entry (replace with actual EUI64 if needed)
# EUI64="0000000000000001"
# su - postgres -c "psql -d chirpstack -c \"insert into gateway (gateway_id, tenant_id, created_at, updated_at, last_seen_at, name, description, latitude, longitude, altitude, stats_interval_secs, tls_certificate, tags, properties) values (bytea '\x$EUI64', (select id from tenant limit 1), now(), now(), null, 'local gateway', 'self', 0.0, 0.0, 0.0, 30, null, '{}', '{}');\""

echo "Setup Gateway Bridge"

# Edit /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml if needed
systemctl enable chirpstack-gateway-bridge --now

echo "Configure Mosquitto MQTT Broker"

mkdir -p /etc/mosquitto/conf.d/

echo "include_dir /etc/mosquitto/conf.d/" | tee -a /etc/mosquitto/mosquitto.conf

cat > /etc/mosquitto/conf.d/local.conf << EOF
listener 1883 0.0.0.0
allow_anonymous true
EOF

systemctl enable mosquitto --now

echo "SETUP COMPLETE"