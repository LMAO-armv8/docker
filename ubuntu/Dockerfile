# Base Image
FROM ubuntu:22.04

# User
USER root

# Working Directory
WORKDIR /root

# Remove Files before copying the Rootfs
COPY ./ubuntu/remove /tmp/
RUN rm -rf $(< /tmp/remove)

# Copy Scripts
COPY ./common/rootfs /

# Install Packages
COPY ./ubuntu/install_packages.sh /tmp/
RUN bash /tmp/install_packages.sh

# Configuration
COPY ./ubuntu/config.sh /tmp/
RUN bash /tmp/config.sh

# Remove the Scripts we used
RUN rm -rf /tmp/{{install_packages,config}.sh,remove,packages}

# docker run command
CMD ["/sbin/init", "--log-target=journal"]
