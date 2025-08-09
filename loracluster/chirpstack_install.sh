#!/bin/sh
set -euo pipefail

echo "Updating apt repositories"
apt-get update

echo "Installing required packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  bash \
  curl \
  gnupg \
  postgresql-client \
  postgresql \
  mosquitto \
  mosquitto-clients \
  redis-server \
  git \
  build-essential \
  cmake \
  dos2unix \
  wget \
  sudo \
  passwd

echo "Ensure /run/postgresql directory exists and has proper permissions"
mkdir -p /run/postgresql
chown postgres:postgres /run/postgresql

POSTGRES_DATA_DIR="/var/lib/postgresql/data"

POSTGRES_DATA_DIR="/var/lib/postgresql/data"
PG_VERSION_DIR=$(ls /usr/lib/postgresql)
PG_BIN_DIR="/usr/lib/postgresql/${PG_VERSION_DIR}/bin"

echo "Initialize PostgreSQL data directory if needed"
if [ ! -d "$POSTGRES_DATA_DIR" ] || [ -z "$(ls -A "$POSTGRES_DATA_DIR")" ]; then
  echo "Initializing PostgreSQL database cluster..."
  su - postgres -c "${PG_BIN_DIR}/initdb -D $POSTGRES_DATA_DIR --auth=trust"
else
  echo "PostgreSQL data directory already initialized at $POSTGRES_DATA_DIR"
fi

echo "Stop any running PostgreSQL server"
if pgrep -u postgres postgres >/dev/null; then
  echo "PostgreSQL process found, stopping..."
  su - postgres -c "${PG_BIN_DIR}/pg_ctl -D $POSTGRES_DATA_DIR stop -m fast"
else
  echo "No running PostgreSQL process found."
fi

echo "Remove stale lock files if any"
rm -f /run/postgresql/.s.PGSQL.5432.lock

echo "Start PostgreSQL server"
su - postgres -c "${PG_BIN_DIR}/pg_ctl -D $POSTGRES_DATA_DIR -l /tmp/postgres.log start"

echo "Wait a moment for PostgreSQL to start"
sleep 3

echo "Creating ChirpStack database role and database if not exist"
sudo -u postgres bash -c 'cd /tmp && psql -tc "SELECT 1 FROM pg_roles WHERE rolname='\''chirpstack'\''" | grep -q 1 || psql -c "CREATE ROLE chirpstack WITH LOGIN PASSWORD '\''chirpstack'\'';"'
sudo -u postgres bash -c 'cd /tmp && psql -tc "SELECT 1 FROM pg_database WHERE datname='\''chirpstack'\''" | grep -q 1 || psql -c "CREATE DATABASE chirpstack WITH OWNER chirpstack;"'
sudo -u postgres bash -c 'cd /tmp && psql -d chirpstack -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" || echo "pg_trgm extension not available or already installed"'

echo "Starting Redis server"
service redis-server start

echo "Starting Mosquitto server"
mkdir -p /run/mosquitto
chown mosquitto:mosquitto /run/mosquitto
service mosquitto start

echo "Starting ChirpStack (assuming binary available in PATH)"
chirpstack &

echo "Setup Gateway Bridge configuration"
mkdir -p /etc/chirpstack-gateway-bridge/
cat > /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge-basicstation.toml << EOF
[general]
log_level="info"

[integration.mqtt.auth.generic]
servers=["tcp://localhost:1883"]

[backend.basic_station]
bind="127.0.0.1:3001"
EOF

echo "Starting ChirpStack Gateway Bridge"
chirpstack-gateway-bridge --config /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge-basicstation.toml &

echo "Setting up Basic Station"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <platform>"
  exit 1
fi

PLATFORM="$1"
CHIRPSTACK_HOST="127.0.0.1"
CHIRPSTACK_PORT="3001"
BUILD_DIR="build-${PLATFORM}-std"
BASICSTATION_DIR="/root/basicstation"

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
chown -R root:root "$BASICSTATION_DIR/$BUILD_DIR"

cd "$BASICSTATION_DIR/$BUILD_DIR/bin"

echo "Configuring Basic Station..."

echo "ws://${CHIRPSTACK_HOST}:${CHIRPSTACK_PORT}" > tc.uri

cat > station.conf << EOF
{
  "radio_conf": {
    "lorawan_public": true,
    "clksrc": 1,
    "antenna_gain": 0
  },
  "chan_Freq": [868100000, 868300000, 868500000]
}
EOF

rm -f tc.trust tc.key tc.crt tc.crl

echo "Starting Basic Station..."
./station &

echo "SETUP COMPLETE"

wait
