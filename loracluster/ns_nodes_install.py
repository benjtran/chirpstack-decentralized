"""
Installing Dependencies on Gateways.
"""

import configparser
import paramiko
import socket

config = configparser.ConfigParser()
config.read('loracluster/config.ini')

def connect_ssh(host, username, password) -> paramiko.SSHClient | None:
    try:
        print("Attempting connection to " + host)
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy()) # Automatically trust new hosts
        client.connect(hostname=host, username=username, password=password, timeout=5)
        return client
    except socket.timeout:
        print("Connection timed out: The host did not respond")
    except socket.gaierror:
        print("Get address info error: Invalid IP")
    except paramiko.AuthenticationException:
        print("Authentication failed: Wrong username or password.")
    return None

def connect_all_nodes() -> list:
    connection_results = []
    for section in config.sections():
        if section != 'settings':
            host = config[section]["host"]
            username = config[section]["username"]
            password = config[section]["password"]
            client = connect_ssh(host, username, password)
            client_result = [host, client]
            connection_results.append(client_result)
    return connection_results

def print_connect_results(results) -> None:
    success = 0
    failed = 0
    for result in results:
        host = result[0]
        client = result[1]
        if client:
            print(host + " successfully connected")
            success+=1
        else:
            print(host + " failed to connect")
            failed+=1
    print(f"{success}/{success + failed} successfully connected")

def install_components(connection_results) -> list:
    for result in connection_results:
        host = result[0]
        client = result[1]
        if client:
            local_script_path = "chirpstack_install.sh"
            remote_script_path = "/tmp/chirpstack_install.sh"

            # Uploading a sh script to a remote server for gw to use
            sftp = ssh.open_sftp()
            sftp.put(local_script_path, remote_script_path)
            sftp.chmod(remote_script_path, 0o755)  # make script executable
            sftp.close()

            stdin, stdout, stderr = client.exec_command(f"bash {remote_script_path}")

            # Print stdout and stderr
            print("STDOUT:")
            for line in stdout:
                print(line, end='')

            print("\nSTDERR:")
            for line in stderr:
                print(line, end='')
 
def main() -> int:
    """
    Main Function.
    """
    print("Testing connect SSH")
    client = connect_ssh('102.199.1.20', 'ben', 'password123')

    print("Testing looping nodes")
    connection_results = connect_all_nodes()
    print_connect_results(connection_results)
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
