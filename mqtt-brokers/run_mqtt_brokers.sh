#!/bin/bash

# Exit on error
set -e

echo "Starting Mosquitto Brokers..."

docker run -d \
  --name mosquitto1 \
  -p 1884:1883 \
  -v "$(pwd)/broker1/mosquitto1.conf:/mosquitto/config/mosquitto.conf" \
  eclipse-mosquitto:2

docker run -d \
  --name mosquitto2 \
  -p 1885:1883 \
  -v "$(pwd)/broker2/mosquitto2.conf:/mosquitto/config/mosquitto.conf" \
  eclipse-mosquitto:2

docker run -d \
  --name mosquitto3 \
  -p 1886:1883 \
  -v "$(pwd)/broker3/mosquitto3.conf:/mosquitto/config/mosquitto.conf" \
  eclipse-mosquitto:2
