FROM ubuntu:24.04

USER root

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /root

COPY ./ubuntu/install_packages.sh /tmp/
RUN bash /tmp/install_packages.sh

COPY ./ubuntu/config.sh /tmp/
RUN bash /tmp/config.sh

COPY ./ubuntu/setup_node.sh /tmp/
RUN bash /tmp/setup_node.sh

COPY ./ubuntu/setup_security.sh /tmp/
RUN bash /tmp/setup_security.sh

COPY ./ubuntu/setup_swap.sh /tmp/
RUN bash /tmp/setup_swap.sh

COPY ./ubuntu/cleanup.sh /tmp/
RUN bash /tmp/cleanup.sh

CMD ["/bin/bash"]
