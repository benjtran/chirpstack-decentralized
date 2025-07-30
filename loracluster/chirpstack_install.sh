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
sudo apt install --yes chirpstack chirpstack-gateway-bridge \
    postgresql postgresql-client postgresql-contrib \
    mosquitto mosquitto-clients redis \
    git build-essential cmake libpthread-stubs0-dev



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

# Basic Station Gateway Bridge config
echo "Creating Basic Station config for Gateway Bridge..."

mkdir -p /etc/chirpstack-gateway-bridge/

cat > /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge-basicstation.toml << EOF
[general]
log_level="info"

[integration.mqtt.auth.generic]
servers=["tcp://localhost:1883"]

[backend.basic_station]
bind="127.0.0.1:3001"
EOF

# Override systemd service to use this config
mkdir -p /etc/systemd/system/chirpstack-gateway-bridge.service.d/

cat > /etc/systemd/system/chirpstack-gateway-bridge.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/chirpstack-gateway-bridge --config /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge-basicstation.toml
EOF

systemctl daemon-reexec
systemctl daemon-reload
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



# TO DO
echo "Setup Redundant Agent"



echo "Setup Basic Station"

PLATFORM="$1"
CHIRPSTACK_HOST="127.0.0.1"  # Replace if needed
CHIRPSTACK_PORT="3001"
REGION="US915"
BUILD_DIR="build-${PLATFORM}-std"
BASICSTATION_DIR="/home/$(logname)/basicstation"

echo "Cloning or Updating Basic Station repository"
if [ -d "$BASICSTATION_DIR" ]; then
    cd "$BASICSTATION_DIR"
    git pull
else
    git clone https://github.com/lorabasics/basicstation.git "$BASICSTATION_DIR"
    cd "$BASICSTATION_DIR"
fi

make clean || true

echo "Building for platform: $PLATFORM"
CC=gcc AR=ar LD=ld make platform=$PLATFORM

echo "Fixing permissions on build directory..."
sudo chown -R $(logname):$(logname) "$BASICSTATION_DIR/$BUILD_DIR"

cd "$BASICSTATION_DIR/$BUILD_DIR/bin"

echo "Configuring Basic Station..."

echo "ws://${CHIRPSTACK_HOST}:${CHIRPSTACK_PORT}" > tc.uri

cat > station.conf <<EOF
{
  "radio_conf": {
    "lorawan_public": true,
    "clksrc": 1,
    "antenna_gain": 0
  },
  "chan_Freq": [868100000, 868300000, 868500000]
}
EOF

# Remove any TLS files
rm -f tc.trust tc.key tc.crt tc.crl

echo "Starting Basic Station..."
./station &



echo "SETUP COMPLETE"
exit 0
