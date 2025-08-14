# ChirpStack Decentralized

## Project Introduction

This project implements a decentralized ChirpStack solution for LoRaWAN network management. It features a redundant agent system with MQTT brokers for reliable network communication and automatic failover capabilities.

The system includes:
- **LoRa Cluster Management**: Automated installation and configuration of ChirpStack network servers
- **MQTT Brokers**: Multiple MQTT brokers for distributed messaging
- **Redundant Agent**: Master election and failover mechanisms for high availability
- **Network Monitoring**: Keepalive and health monitoring systems

## How to Run

### Prerequisites

Make sure you have Python 3.7+ installed on your system.

### Setup

1. **Create a virtual environment** by running:
   ```bash
   python3 -m venv venv
   ```

2. **Activate the virtual environment** by running:
   ```bash
   source venv/bin/activate
   ```
   
   The shell prompt should change with a prefix that says `(venv) eszymko@MacBook-Pro`

3. **Install dependencies** from requirements.txt by running:
   ```bash
   pip install -r requirements.txt
   ```

### Running the Application

**Important**: Before running the installation, make sure Docker containers are running since the installation process will deploy components to the Docker containers.

1. **Start Docker containers** first:
   ```bash
   docker-compose up -d
   ```

2. **Install decentralized nodes**:
   ```bash
   python3 -m loracluster.ns_nodes_install
   ```

This should resolve any dependency issues and start the LoRa cluster node installation process on the Docker containers.

### Additional Components

- **MQTT Brokers**: Use `./mqtt-brokers/run_mqtt_brokers.sh` to start the MQTT broker cluster
- **Redundant Agent**: Run `python3 -m redundant_agent.redundant_agent` to start the redundancy management system
- **Docker Support**: Use `docker-compose up` for containerized deployment

## Project Structure

```
loracluster/          # LoRaWAN cluster management
mqtt-brokers/         # MQTT broker configurations
redundant_agent/      # High availability and failover system
```