FROM ubuntu:18.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bc \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    gcc-aarch64-linux-gnu \
    gcc-5-aarch64-linux-gnu \
    gcc-5-arm-linux-gnueabihf \
    python \
    xz-utils \
    cpio \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
