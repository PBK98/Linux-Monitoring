FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    python3 \
    cron \
    sudo \
    procps \
    net-tools \
    iproute2 \
    vim \
    systemctl \
    gzip \
    openssh-server \
    && apt clean \

WORKDIR /app

COPY ./Monitoring/* /app

RUN chmod +x *.sh

CMD ["tail", "-f", "/dev/null"]