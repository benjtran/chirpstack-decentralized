"""
Installing Dependencies on Gateways.
"""

import configparser
import paramiko
import socket

from redundant_agent.redundant_agent import run_redundant_agent

config = configparser.ConfigParser()
config.read('loracluster/config.ini')

def connect_ssh(host, username, password, ssh_port) -> paramiko.SSHClient | None:
    try:
        print("Attempting connection to " + host)
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Automatically trust new hosts
        client.connect(hostname=host, port=ssh_port, username=username, password=password, timeout=5)
        print("Success!")
        return client
    except socket.timeout:
        print("Connection timed out: The host did not respond")
    except socket.gaierror:
        print("Get address info error: Invalid IP")
    except paramiko.AuthenticationException:
        print("Authentication failed: Wrong username or password.")
    except paramiko.ssh_exception.NoValidConnectionsError as e:
        print(f"SSH connection failed: {e}")
    return None

def load_nodes_config() -> list:
    connection_results = []
    for section in config.sections():
        if section != 'settings':
            host = config[section]["host"]
            username = config[section]["username"]
            password = config[section]["password"]
            platform = config[section]["platform"]
            role = config[section]["role"]
            name = config[section]["name"]
            ssh_port = config[section]['ssh_port']
            client = connect_ssh(host, username, password, ssh_port)
            client_result = [host, client, password, platform, role, name, ssh_port]
            connection_results.append(client_result)
    return connection_results

def print_connect_results(results) -> None:
    success = 0
    failed = 0
    for result in results:
        name = result[5]
        client = result[1]
        if client:
            print(name + " successfully connected")
            success+=1
        else:
            print(name + " failed to connect")
            failed+=1
    print(f"{success}/{success + failed} successfully connected")

def install_components(connection_results) -> None:
    for result in connection_results:
        host = result[0]
        client = result[1]
        password = result[2]
        platform = result[3]
        ssh_port = result[6]
        if client:
            remote_script_path = "/tmp/chirpstack_install.sh"
            local_script_path = "loracluster/chirpstack_install.sh"

            with open(local_script_path, "rb") as f:
                content = f.read().replace(b"\r\n", b"\n")
            with open(local_script_path, "wb") as f:
                f.write(content)

            # Upload the script
            sftp = client.open_sftp()
            sftp.put(local_script_path, remote_script_path)
            sftp.chmod(remote_script_path, 0o755)
            sftp.close()

            chan = client.invoke_shell()

            # Clear initial welcome text if any
            while not chan.recv_ready():
                pass
            chan.recv(1024)

            chan.send(f"dos2unix {remote_script_path}\n")
            while not chan.recv_ready():
                pass
            chan.recv(1024)

            chan.send(f"bash {remote_script_path} {platform}\n")

            while True:
                if chan.recv_ready():
                    output = chan.recv(4096).decode()
                    print(output, end="")

                    if "password" in output.lower():
                        chan.send(password + "\n")

                    if "setup complete" in output.lower():
                        print(f"\nFinished installing components on {ssh_port}")
                        break

            chan.close()
            client.close()
            
def run_agent_on_master(connection_results) -> None:
    for result in connection_results:
        role = result[4]
        name = result[5]
        if "master" in role.lower():
            run_redundant_agent(name)
 
def main() -> int:
    """
    Main Function.
    """
    print("Begin looping nodes")
    connection_results = load_nodes_config()
    print_connect_results(connection_results)
    continue_status = input("Would you like to continue? (Y/N)")
    if continue_status == "N":
        return 0
    elif continue_status != "Y":
        print("Invalid input, exiting.")
        return 1

    print("Component installation")
    install_components(connection_results)
    
    run_agent_on_master(connection_results)
    
    return 0

if __name__ == "__main__":
    result_main = main()
    if result_main != 0:
        print(f"ERROR: Status code: {result_main}")

    print("Done!")
