import configparser
import socket
from pathlib import Path

def load_agent_config(simulate_node_name=None):
    # Locate config.ini relative to redundant-agent/
    script_dir = Path(__file__).resolve().parent
    config_file = script_dir.parent / "loracluster" / "config.ini"
    if not config_file.exists():
        raise Exception(f"Config file not found at {config_file}")

    # Parse config.ini
    config = configparser.ConfigParser()
    config.read(config_file)

    mqtt_brokers = []
    matched_section = None

    for section in config.sections():
        if section == "settings":
            continue
        mqtt_brokers.append((config[section]["host"].strip(), int(config[section]["port"])))

        # Dynamic matching (real use)
        if not simulate_node_name:
            try:
                local_ip = socket.gethostbyname(socket.gethostname()).strip()
                if config[section]["host"].strip() == local_ip:
                    matched_section = section
            except socket.error:
                continue

        # Simulated override (for testing only)
        if simulate_node_name and config[section]["name"].strip() == simulate_node_name:
            matched_section = section

    if not matched_section:
        raise Exception(f"No matching node found for this host. (simulate_node_name='{simulate_node_name}')")

    node_config = config[matched_section]
    role = node_config["role"].strip().upper()
    name = node_config["name"].strip()
    deveui = node_config["deveui"].strip()
    keepalive = int(config["settings"].get("keepalive", 600))

    chirpstack_mqtt = config["settings"].get("chirpstack_mqtt", "127.0.0.1").strip()
    redis_host = config["settings"].get("redis_host", "127.0.0.1").strip()
    uplink_topic = config["settings"].get("uplink_topic", "application/+/device/+/event/up").strip()

    result = {
        "name": name,
        "role": role,
        "deveui": deveui,
        "keepalive": keepalive,
        "mqtt_brokers": mqtt_brokers,
        "chirpstack_mqtt": chirpstack_mqtt,
        "redis_host": redis_host,
        "uplink_topic": uplink_topic,
        "keepalive_topic": f"agent/keepalive/{name}"
    }

    if role == "BACKUP":
        result["master_name"] = node_config.get("master_name", "").strip()
        if not result["master_name"]:
            raise Exception(f"BACKUP node '{name}' must define 'master_name' in config.ini")
    
    return result

# Example usage: for testing, override the detection
if __name__ == "__main__":
    try:
        cfg = load_agent_config(simulate_node_name="gateway-2")  # override for local test only
        print("Config loaded successfully:")
        for k, v in cfg.items():
            print(f"{k}: {v}")
    except Exception as e:
        print(f"Failed to load config: {e}")
