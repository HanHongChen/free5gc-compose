FROM gcc:12-bullseye AS builder

LABEL maintainer="Free5GC <support@free5gc.org>"

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGET_ARCH=x86_64 
# TARGET_ARCH support : x86_64, aarch64(arm64)

# Install dependencies
RUN apt-get update \
    && apt-get install libsctp-dev lksctp-tools iproute2 -y \
    && wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-${TARGET_ARCH}.sh -O cmake_installer.sh \
    && chmod +x cmake_installer.sh \
    && ./cmake_installer.sh --skip-license \
    && git clone -b master -j `nproc` https://github.com/aligungr/UERANSIM \
    && cd ./UERANSIM \
    && make

FROM bitnami/minideb:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies + ping
FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libsctp1 lksctp-tools iproute2 iputils-ping procps psmisc iperf3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
    
WORKDIR /ueransim

RUN mkdir -p config/ binder/

COPY --from=builder /UERANSIM/build/nr-gnb .
COPY --from=builder /UERANSIM/build/nr-ue .
COPY --from=builder /UERANSIM/build/nr-cli .
COPY --from=builder /UERANSIM/build/nr-binder binder/
COPY --from=builder /UERANSIM/build/libdevbnd.so binder/

VOLUME [ "/ueransim/config" ]
