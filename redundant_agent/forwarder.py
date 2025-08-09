import time
import paho.mqtt.client as mqtt
from redis import Redis
from .config import load_agent_config
from .master_election import am_i_master

def forward_uplinks_to_chirpstack(config):
    r = Redis(host=config["redis_host"], port=6379)
    pub = mqtt.Client(protocol=mqtt.MQTTv5)
    pub.connect(config["chirpstack_mqtt"])
    pub.loop_start()

    print(f"[{config['name']}] Forwarder started. Listening to Redis stream 'uplinks'...")

    last_id = "0"
    while True:
        entries = r.xread({"uplinks": last_id}, block=1000, count=1)
        if entries:
            _, msgs = entries[0]
            for msg_id, data in msgs:
                topic = data[b'topic'].decode()
                payload = data[b'data'].decode()

                if am_i_master(config):
                    pub.publish(topic, payload)
                    print(f"[MASTER] Forwarded uplink → {topic}: {payload}")
                else:
                    print(f"[BACKUP] Skipped uplink → {topic}: {payload}")

                last_id = msg_id


if __name__ == "__main__":
    config = load_agent_config(simulate_node_name="gateway-2")  # or gateway-3, etc.
    forward_uplinks_to_chirpstack(config)
