# Base Image
FROM ubuntu/python:3.12-24.04_stable

# Install Packages
COPY ./ubuntu/install_packages.sh /tmp/
RUN bash /tmp/install_packages.sh

# Configuration
COPY ./ubuntu/config.sh /tmp/
RUN bash /tmp/config.sh

# Remove the Scripts we used
RUN rm -rf /tmp/{{install_packages,config}.sh}

# docker run command
CMD ["/sbin/init", "--log-target=journal"]
