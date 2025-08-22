import paho.mqtt.client as mqtt
import json

# MQTT broker info (your container)
BROKER = "localhost"
PORT = 1884   # use host-mapped port, not container internal port
TOPIC = "application/60a6251c-16ad-475d-a429-c59c7ace5406/device/TESTDEVICE01/event/up"

# Uplink payload (fixed JSON structure)
payload = {
    "applicationID": "60a6251c-16ad-475d-a429-c59c7ace5406",
    "deviceName": "TESTDEVICE01",
    "devEUI": "0102030405060708",
    "rxInfo": [{
        "gatewayID": "0102030405060708",
        "time": "2025-08-19T03:00:00Z",
        "rssi": -30,
        "loRaSNR": 5
    }],
    "txInfo": {
        "frequency": 868100000,
        "dataRate": "SF7BW125"
    },
    "fCnt": 1,
    "fPort": 1,
    "data": "SGVsbG8="
}

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Connected to MQTT broker")
        client.publish(TOPIC, json.dumps(payload))
        print("📡 Uplink message sent to ChirpStack")
    else:
        print(f"❌ Failed to connect, return code {rc}")

# Create MQTT client
client = mqtt.Client()
client.on_connect = on_connect

# Connect and loop
client.connect(BROKER, PORT, 60)
client.loop_start()

# Keep script alive long enough to send
import time
time.sleep(2)
client.loop_stop()
client.disconnect()
