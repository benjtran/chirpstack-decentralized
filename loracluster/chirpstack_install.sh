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

echo "=== Installing ChirpStack MQTT Forwarder ==="
MQTT_FWD_VER="4.4.0"
MQTT_FWD_TAR="chirpstack-mqtt-forwarder_${MQTT_FWD_VER}_linux_amd64.tar.gz"
MQTT_FWD_URL="https://artifacts.chirpstack.io/downloads/chirpstack-mqtt-forwarder/${MQTT_FWD_TAR}"

cd /tmp
wget -O "$MQTT_FWD_TAR" "$MQTT_FWD_URL"
tar -xvf "$MQTT_FWD_TAR"
chmod +x chirpstack-mqtt-forwarder
mv chirpstack-mqtt-forwarder /usr/local/bin/
rm "$MQTT_FWD_TAR"

mkdir -p /etc/chirpstack-mqtt-forwarder /var/log/chirpstack-mqtt-forwarder

cat <<EOF > /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml
[general]
log_level="info"

[gateway]
gateway_id="0102030405060708"

[integration.mqtt]
server="tcp://localhost:1883"
topic_prefix="eu868/gateway"

[backend.semtech_udp]
# Forwarder will listen for UDP packets from a Semtech packet-forwarder
bind="0.0.0.0:1700"
EOF

echo "=== Starting MQTT Forwarder (Semtech UDP backend) ==="
nohup /usr/local/bin/chirpstack-mqtt-forwarder \
    --config /etc/chirpstack-mqtt-forwarder/chirpstack-mqtt-forwarder.toml \
    > /var/log/chirpstack-mqtt-forwarder.log 2>&1 &

echo "=== Setup complete ==="
echo "ChirpStack Web UI: http://<container-ip>:8080 (default login: admin / admin)"

# Keep container running
tail -f /dev/null
