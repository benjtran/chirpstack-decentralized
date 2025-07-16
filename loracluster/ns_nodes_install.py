"""
Installing Dependencies on Gateways.
"""

import configparser
import paramiko
import socket

config = configparser.ConfigParser()
config.read('loracluster/config.ini')

def connect_ssh(host, username, password) -> bool:
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy()) # Automatically trust new hosts
        client.connect(hostname=host, username=username, password=password, timeout=5)
        client.close()
        return True
    except socket.timeout:
        print("Connection timed out: The host did not respond")
        return False
    except socket.gaierror:
        print("Get address info error: Invalid IP")
        return False
    except paramiko.AuthenticationException:
        print("Authentication failed: Wrong username or password.")
        return False

def main() -> int:
    """
    Main Function.
    """
    print("Calling the function")
    connect_ssh('102.199.1.20', 'ben', 'password123')
    return 0

if __name__ == "__main__":
    result_main = main()
    if result_main != 0:
        print(f"ERROR: Status code: {result_main}")

    print("Done!")
