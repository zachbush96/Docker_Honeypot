# manager/Dockerfile

FROM ubuntu:20.04

# Set environment variable to suppress interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Docker, SSH server, and netcat
RUN apt-get update && apt-get install -y \
    docker.io \
    openssh-server \
    python3 \
    python3-pip \
    netcat \
    iputils-ping

# Install python flask
RUN pip3 install flask
RUN pip3 install flask_cors


# Configure SSH
RUN mkdir /var/run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
RUN echo 'UsePAM no' >> /etc/ssh/sshd_config
RUN echo 'ForceCommand /usr/local/bin/spawn_honeypot.sh' >> /etc/ssh/sshd_config

# Create user with Docker access
RUN useradd -m -s /bin/bash test && \
    passwd -d test && \
    usermod -aG root test

# Allow TCP forwarding and gateway ports
RUN echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config
RUN echo 'GatewayPorts yes' >> /etc/ssh/sshd_config

# Copy the manager script and the spawn script
COPY manager.py /manager.py
COPY spawn_honeypot.sh /usr/local/bin/spawn_honeypot.sh
RUN chmod +x /usr/local/bin/spawn_honeypot.sh

# Create a folder called templates
RUN mkdir /templates
# Copy the index.html file from /templates to /templates
COPY templates/index.html /templates/index.html
RUN chmod 755 /templates/index.html

# Copy the honeypot image
COPY honeypot_image.tar /honeypot_image.tar

# Ensure proper permissions
RUN chmod 755 /usr/local/bin/spawn_honeypot.sh && \
    chmod 755 /manager.py

# Create a text file to store the command history
RUN touch /command_history.txt && \
    chmod 777 /command_history.txt

# Start SSH server and the manager script
CMD ["sh", "-c", "docker load < /honeypot_image.tar && chmod 666 /var/run/docker.sock && /usr/sbin/sshd -D & python3 /manager.py"]
