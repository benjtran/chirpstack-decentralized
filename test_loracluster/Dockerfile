FROM ubuntu:22.04

RUN apt-get update \
    && apt-get install -y openssh-server sudo dos2unix \
    && rm -rf /var/lib/apt/lists/*

# SSH Setup

# Username:Password
# root:root

RUN mkdir /var/run/sshd \
 && echo 'root:root' | chpasswd \
 && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && echo "root ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/root-nopasswd

RUN ssh-keygen -A

EXPOSE 22
EXPOSE 8080

WORKDIR /loracluster

COPY loracluster/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]