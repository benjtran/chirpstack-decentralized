import socket

if __name__ == "__main__":
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    print(f"Your IP address is: {ip_address}")
