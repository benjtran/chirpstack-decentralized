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

def connect_all_nodes() -> list:
    results = []
    for section in config.sections():
        if section != 'settings':
            gw_connection_status = [section, connect_ssh(config[section]["host"], config[section]["username"], config[section]["password"])]
            results.append(gw_connection_status)
    return results

def print_connect_results(results) -> None:
    success = 0
    failed = 0
    for result in results:
        if result[1]:
            print(result[0] + " successfully connected")
            success+=1
        else:
            print(result[0] + " failed to connect")
            failed+=1
    print(f"{success}/{success + failed} successfully connected")

    
 
def main() -> int:
    """
    Main Function.
    """
    print("Testing connect SSH")
    connect_ssh('102.199.1.20', 'ben', 'password123')
    print("Testing looping nodes")
    print_connect_results(connect_all_nodes())
    continue_status = input("Would you like to continue? (Y/N)")
    if continue_status == "N":
        return 0
    print("Running future scripts...")
    return 0

if __name__ == "__main__":
    result_main = main()
    if result_main != 0:
        print(f"ERROR: Status code: {result_main}")

    print("Done!")
