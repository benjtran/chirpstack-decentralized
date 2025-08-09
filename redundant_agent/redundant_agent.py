import threading
from .config import load_agent_config
from .keepalive_sender import send_keepalive
from .mqtt_subscriber import subscribe_to_gateways
from .forwarder import forward_uplinks_to_chirpstack
from redis import Redis
import paho.mqtt.client as mqtt


def run_redundant_agent(simulate_node_name=None):
    # Load config
    config = load_agent_config(simulate_node_name)
    name = config["name"]
    brokers = config["mqtt_brokers"]
    topic = config["uplink_topic"]
    interval = config["keepalive"]
    keepalive_topic = config["keepalive_topic"]

    print(f"[{name}] RedundantAgent starting up...")

    # 1. Start Redis connection
    redis_conn = Redis(host=config["redis_host"], port=6379)

    # 2. Start Keepalive senders for each broker
    for host, port in brokers:
        try:
            mqtt_client = mqtt.Client(protocol=mqtt.MQTTv5)
            mqtt_client.connect(host, port=port)
            mqtt_client.loop_start()
            print(f"[✓] Connected to broker {host}:{port} for keepalive")

            # Thread to publish keepalives
            t = threading.Thread(
                target=send_keepalive,
                args=(name, mqtt_client, keepalive_topic, redis_conn, interval),
                daemon=True
            )
            t.start()
        except Exception as e:
            print(f"[✗] Failed to start keepalive for {host}:{port}: {e}")

    # 3. Start Subscriber to uplinks from all brokers
    print(f"[{name}] Subscribing to uplink topic: {topic}")
    subscribe_to_gateways(brokers, topic)

    # 4. Start Forwarder (blocking, handles master check internally)
    print(f"[{name}] Starting uplink forwarder loop...")
    forward_uplinks_to_chirpstack(config)


if __name__ == "__main__":
    try:
        simulate_node = "gateway-1" # Example: "gateway-1", "gateway-2" for local testing
        run_redundant_agent(simulate_node_name=simulate_node)
    except Exception as e:
        print(f"[ERROR] RedundantAgent failed: {e}")
