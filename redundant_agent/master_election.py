import time
from redis import Redis
from .config import load_agent_config

# Initialize config + Redis
config = load_agent_config("gateway-1")
r = Redis(host=config["redis_host"], port=6379)

def is_master_alive(redis_client, master_name, timeout=600):
    ts = redis_client.get(f"keepalive:{master_name}")
    if not ts:
        return False
    return (time.time() - float(ts)) < timeout

def am_i_master(config):
    """
    Returns True if this node should assume master role.
    - If role is explicitly MASTER, return True.
    - If role is BACKUP and MASTER is unresponsive, return True.
    """
    if config["role"] == "MASTER":
        return True
    return not is_master_alive(r, config["master_name"])

if __name__ == "__main__":
    # Simulate the BACKUP agent for test
    config = load_agent_config(simulate_node_name="gateway-2")  # test mode
    config["master_name"] = "gateway-1"

    # Redis connection
    r = Redis(host=config["redis_host"], port=6379)

    # Check master timestamp
    ts = r.get(f"keepalive:{config['master_name']}")
    if ts:
        print(f"Master ({config['master_name']}) last keepalive: {ts.decode()}")
    else:
        print(f"Master ({config['master_name']}) has never sent keepalive.")

    # Run master election logic
    if am_i_master(config):
        print(f"{config['name']} will assume MASTER role.")
    else:
        print(f"{config['name']} stays BACKUP.")