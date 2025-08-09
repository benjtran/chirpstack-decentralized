from redis import Redis

if __name__ == "__main__":
    r = Redis(host="localhost", port=6379)

# Simulate an uplink message
    r.xadd("uplinks", {
        "topic": "application/1/device/abc123/up",
        "data": '{"fCnt": 42, "data": "0A1B2C3D"}'
    })