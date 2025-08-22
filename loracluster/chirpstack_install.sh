#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo $TZ > /etc/timezone

echo "=== Updating system ==="
apt-get update -y && apt-get upgrade -y

echo "=== Installing dependencies ==="
apt-get install -y curl wget gnupg iproute2 software-properties-common apt-transport-https \
    build-essential cmake git sudo unzip

echo "=== Installing Redis and MQTT broker ==="
apt-get install -y redis-server mosquitto mosquitto-clients

# Prepare runtime directories for MQTT
mkdir -p /run/mosquitto
chown mosquitto:mosquitto /run/mosquitto
mkdir -p /etc/mosquitto
cat <<EOF > /etc/mosquitto/mosquitto.conf
listener 1883
allow_anonymous true
EOF

# Start Redis and Mosquitto
service redis-server start
service mosquitto start

echo "=== Installing ChirpStack SQLite ==="
CHIRPSTACK_VERSION="4.14.0"
CHIRPSTACK_TARBALL="chirpstack_${CHIRPSTACK_VERSION}_sqlite_linux_amd64.tar.gz"
CHIRPSTACK_URL="https://artifacts.chirpstack.io/downloads/chirpstack/${CHIRPSTACK_TARBALL}"
CHIRPSTACK_BIN="/usr/local/bin/chirpstack-sqlite"

if [ ! -f "$CHIRPSTACK_BIN" ]; then
    cd /tmp
    wget -O "$CHIRPSTACK_TARBALL" "$CHIRPSTACK_URL"
    tar -xvf "$CHIRPSTACK_TARBALL"
    chmod +x chirpstack
    mv chirpstack "$CHIRPSTACK_BIN"
    rm "$CHIRPSTACK_TARBALL"
fi

mkdir -p /etc/chirpstack /var/lib/chirpstack /var/log/chirpstack

cat <<EOF > /etc/chirpstack/chirpstack.toml
[general]
log_level="info"

[network_server]
bind="0.0.0.0:8000"

[application_server]
bind="0.0.0.0:8080"

[storage]
type="sqlite"
sqlite_path="/var/lib/chirpstack/chirpstack.db"

[redis]
server="localhost:6379"

[mqtt]
server="tcp://localhost:1883"

[gateway]
allow_unknown_gateways=true
EOF

touch /var/lib/chirpstack/chirpstack.db
chown -R nobody:nogroup /var/lib/chirpstack /var/log/chirpstack
chmod 755 /var/lib/chirpstack
chmod 644 /var/lib/chirpstack/chirpstack.db

echo "=== Starting ChirpStack SQLite ==="
nohup "$CHIRPSTACK_BIN" --config /etc/chirpstack > /var/log/chirpstack/chirpstack.log 2>&1 &

echo "=== Installing ChirpStack Gateway Bridge ==="
GWBRIDGE_DEB="/tmp/chirpstack-gateway-bridge_4.0.11_linux_amd64.deb"
GWBRIDGE_URL="https://artifacts.chirpstack.io/downloads/chirpstack-gateway-bridge/chirpstack-gateway-bridge_4.0.11_linux_amd64.deb"

if [ ! -f "/usr/bin/chirpstack-gateway-bridge" ]; then
    wget -O "$GWBRIDGE_DEB" "$GWBRIDGE_URL"
    dpkg -i "$GWBRIDGE_DEB" || apt-get install -f -y
fi

mkdir -p /etc/chirpstack-gateway-bridge /etc/chirpstack-gateway-bridge/configs

# --- router-config.json for Basic Station ---
cat <<EOF > /etc/chirpstack-gateway-bridge/configs/router-config.json
{
  "SX1301_conf": {
    "lorawan_public": true,
    "clksrc": 1,
    "antenna_gain": 0,
    "radio_0": { "freq": 868100000 },
    "radio_1": { "freq": 868300000 },
    "chan_multiSF_0": { "radio": 0, "if": 0 },
    "chan_multiSF_1": { "radio": 0, "if": -200000 },
    "chan_multiSF_2": { "radio": 1, "if": 200000 }
  },
  "gateway_conf": {
    "hwspec": "virtual/0",
    "freq_range": [863000000, 870000000],
    "DRs": [0,1,2,3,4,5]
  }
}
EOF


# --- chirpstack-gateway-bridge.toml ---
cat <<EOF > /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml
[general]
log_level=4

[integration.mqtt]
server="tcp://localhost:1883"

[backend]
type="basic_station"

[backend.basic_station]
enabled=true
bind="0.0.0.0:8888"
server="ws://0.0.0.0:8888"
allow_unknown_gateways=true
stats_interval="30s"
configuration="/etc/chirpstack-gateway-bridge/configs"
EOF

echo "=== Starting Gateway Bridge manually ==="
nohup /usr/bin/chirpstack-gateway-bridge \
    --config /etc/chirpstack-gateway-bridge/chirpstack-gateway-bridge.toml \
    > /var/log/chirpstack-gateway-bridge.log 2>&1 &

# --- Basic Station ---
echo "=== Installing Basic Station ==="
cd /opt
if [ ! -d "basicstation" ]; then
    git clone https://github.com/lorabasics/basicstation.git
fi

cd basicstation
make clean || true
make platform=$1

BUILD_DIR=$(find /opt/basicstation -type d -name 'build-linux-std' | head -n 1)/bin
cd "$BUILD_DIR"

# Configure URI and station.conf
echo "ws://127.0.0.1:8888" > tc.uri
cat <<EOF > station.conf
{
  "radio_conf": {
    "lorawan_public": true,
    "clksrc": 1,
    "antenna_gain": 0
  },
  "chan_Freq": [868100000, 868300000, 868500000],
  "hwspec": "virtual/0"
}
EOF

chmod 644 station.conf tc.uri

# Start Basic Station, taking over if already running
./station -f > /var/log/basicstation.log 2>&1 &

echo "=== Setup complete ==="
echo "ChirpStack Web UI: http://<container-ip>:8080 (default login: admin / admin)"

# Keep container running
tail -f /dev/null
