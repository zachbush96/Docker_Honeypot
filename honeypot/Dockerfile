# honeypot/Dockerfile

FROM ubuntu:20.04

# Install necessary packages with some common utilities for realism
RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    passwd \
    netcat \
    iputils-ping \
    curl \
    nano \
    vim \
    htop \
    cron \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir /var/run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'PermitEmptyPasswords yes' >> /etc/ssh/sshd_config
RUN echo 'UsePAM no' >> /etc/ssh/sshd_config
#RUN echo 'LogLevel DEBUG3' >> /etc/ssh/sshd_config
# Allow only the 'test' user
RUN echo 'AllowUsers test' >> /etc/ssh/sshd_config  
# Set default shell directly
#RUN echo 'ForceCommand /bin/sh' >> /etc/ssh/sshd_config 
RUN echo 'PermitTTY yes' >> /etc/ssh/sshd_config
# Listen on all interfaces
RUN echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config
RUN echo 'ListenAddress ::' >> /etc/ssh/sshd_config
RUN echo 'PermitTTY yes' >> /etc/ssh/sshd_config



# Create a user with no password
RUN useradd -ms /bin/bash test
RUN passwd -d test
RUN mkdir -p /home/test/Documents /home/test/Downloads /home/test/Projects
RUN echo 'Random text file content' > /home/test/Documents/README.txt
RUN echo '# Sample script' > /home/test/Projects/script.sh
RUN chown -R test:test /home/test
RUN chmod 755 /home/test

# Rename and set up the logging shell
COPY logger.py /usr/local/bin/audit.py
RUN chmod +x /usr/local/bin/audit.py
RUN chsh -s /usr/local/bin/audit.py test

# Set up cron job for added realism
RUN echo '* * * * * root echo "cron job running" >> /var/log/cron.log' > /etc/cron.d/fakecron
RUN chmod 0644 /etc/cron.d/fakecron
RUN crontab /etc/cron.d/fakecron

# Create startup script with proper error handling
RUN echo '#!/bin/bash\n\
rm -f /var/run/sshd.pid\n\
echo "Starting sshd..."\n\
top -b &\n\
/usr/sbin/sshd -D -e' > /startup.sh

RUN chmod +x /startup.sh

#RUN echo '#!/bin/bash echo "testing"' > /startup.sh
#RUN chmod +x /startup.sh

# Expose SSH port
EXPOSE 22

# Start SSH server with verbose logging
CMD ["/startup.sh"]
