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
<<<<<<< HEAD
    gzip \
    openssh-server \
    && apt clean
=======
    systemctl \
    && apt clean \
    gzip
>>>>>>> b8a38c5 (main/ log_archive.sh 압축기능 추가, Dockerfile gzip(Run) 추가)

WORKDIR /app

COPY . /app

RUN chmod +x *.sh

CMD ["tail", "-f", "/dev/null"]