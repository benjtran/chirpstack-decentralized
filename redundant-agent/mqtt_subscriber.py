import paho.mqtt.client as mqtt
from redis import Redis
from config import load_agent_config

config = load_agent_config(simulate_node_name="gateway-1")

# Connect to Redis
r = Redis(host=config["redis_host"], port=6379)

# Log uplink data to Redis
def log_uplink_to_redis(topic, payload):
    r.xadd("uplinks", {"topic": topic, "data": payload})

# Callback for MQTT uplinks
def on_uplink(client, userdata, msg, properties=None):
    print(f"[UPLINK] {msg.topic}: {msg.payload.decode()}")
    r.xadd("uplinks", {"topic": msg.topic, "data": msg.payload.decode()})

# Subscribe to all gateway brokers from config
def subscribe_to_gateways(brokers, topic):
    clients = []
    for broker in brokers:
        try:
            host, port = broker  # Unpack
            c = mqtt.Client(protocol=mqtt.MQTTv5)
            c.on_message = on_uplink
            c.connect(host, port=port, keepalive=60)
            c.subscribe(topic)
            c.loop_start()
            clients.append(c)
            print(f"[✓] Connected to broker: {host}:{port}")
        except Exception as e:
            print(f"[✗] Failed to connect to broker {broker}: {e}")
    return clients

if __name__ == "__main__":
    config = load_agent_config(simulate_node_name="gateway-1")  # Simulated override for local test

    # Override broker IPs with localhost for testing
    config["mqtt_brokers"] = [
        ("127.0.0.1", 1884),
        ("127.0.0.1", 1885),
        ("127.0.0.1", 1886)
    ]

    brokers = config["mqtt_brokers"]
    topic = config["uplink_topic"]

    print(f"Subscribing to: {brokers}")
    subscribe_to_gateways(brokers, topic)

    input("Listening for uplinks... Press Enter to exit.\n")