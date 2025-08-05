import time
import paho.mqtt.client as mqtt
from redis import Redis
from config import load_agent_config
from datetime import datetime

def send_keepalive(agent_name, mqtt_client, topic, redis_conn, interval=600):
    while True:
        timestamp = str(time.time())
        redis_conn.set(f"keepalive:{agent_name}", timestamp)
        mqtt_client.publish(topic, "ALIVE")
        print(f"[{agent_name}] Keepalive sent at {datetime.fromtimestamp(float(timestamp))} ({timestamp})")
        time.sleep(interval)

if __name__ == "__main__":
    from threading import Thread

    # Test config override
    config = load_agent_config(simulate_node_name="gateway-1")
    agent_name = config["name"]
    topic = config["keepalive_topic"]
    interval = config["keepalive"]  # in seconds

    # Redis setup
    redis_conn = Redis(host=config["redis_host"], port=6379)

    # Test brokers
    test_brokers = [
        ("127.0.0.1", 1884),
        ("127.0.0.1", 1885),
        ("127.0.0.1", 1886)
    ]

    # Launch a thread for each broker
    for host, port in test_brokers:
        try:
            mqtt_client = mqtt.Client(protocol=mqtt.MQTTv5)
            mqtt_client.connect(host, port=port)
            mqtt_client.loop_start()
            print(f"[✓] Connected to broker {host}:{port}")

            # Run send_keepalive in parallel thread
            t = Thread(
                target=send_keepalive,
                args=(agent_name, mqtt_client, topic, redis_conn, interval),
                daemon=True
            )
            t.start()
        except Exception as e:
            print(f"[✗] Failed to connect to broker {host}:{port}: {e}")

    input("Keepalive test running... Press Enter to exit.\n")
