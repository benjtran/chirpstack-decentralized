FROM ubuntu:22.04

# Dependencies for building Basic Station + mosquitto + ssh + python
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    git \
    python3 \
    python3-pip \
    mosquitto \
    mosquitto-clients \
    openssh-server \
    sudo \
    curl \
    && rm -rf /var/lib/apt/lists/*

# SSH for root login
RUN mkdir /var/run/sshd \
 && echo 'root:mosqpass' | chpasswd \
 && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config \
 && echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/root-nopasswd

EXPOSE 1883 22

CMD /usr/sbin/sshd && mosquitto -c /mosquitto/config/mosquitto.conf