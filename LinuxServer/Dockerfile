FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    python3 \
    python3-pip \
    cron \
    sudo \
    procps \
    net-tools \
    iproute2 \
    vim \
    gzip \
    openssh-server \
    && apt clean

WORKDIR /app

COPY ./scripts/*.sh /app
COPY ./app/agent_app.py /app

RUN chmod +x *.sh

CMD ["tail", "-f", "/dev/null"]