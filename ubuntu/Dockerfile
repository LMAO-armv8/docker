# Base Image
FROM ubuntu:latest

# User
USER root

# Working Directory
WORKDIR /home/ubuntu

# Install Packages
COPY ./ubuntu/install_packages.sh /tmp/
RUN bash /tmp/install_packages.sh

# Configuration
COPY ./ubuntu/config.sh /tmp/
RUN bash /tmp/config.sh

# Change to Normal User
USER ubuntu

# Setup Conda
COPY ./ubuntu/setup_env.sh /tmp/
RUN bash /tmp/setup_env.sh

# Set PATH for Conda
ENV PATH="/home/ubuntu/miniconda3/bin:$PATH"

# Create and Activate Conda Environment
RUN conda create -n myenv python=3.12 pip wheel && \
    echo "source activate myenv" >> ~/.bashrc

# User
USER root

# Remove the Scripts we used
RUN rm -rf /tmp/install_packages.sh /tmp/config.sh /tmp/setup_env.sh

# Default command
CMD ["/sbin/init", "--log-target=journal"]
