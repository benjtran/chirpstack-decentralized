#!/bin/bash

# Name of the chirpstack docker network
NETWORK_NAME="chirpstack-docker_default"

# List of your broker container names
BROKERS=("mosquitto1" "mosquitto2" "mosquitto3")

echo "Connecting brokers to Docker network: $NETWORK_NAME"

# Loop through each broker and connect
for BROKER in "${BROKERS[@]}"; do
    echo "Connecting $BROKER to $NETWORK_NAME..."
    docker network connect "$NETWORK_NAME" "$BROKER"
done

echo "All brokers connected to $NETWORK_NAME"
