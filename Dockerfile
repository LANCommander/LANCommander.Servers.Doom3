# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest

# ----------------------------
# Build the dhewm3 dedicated server (dhewm3ded) and the base/d3xp game libraries from source.
# dhewm3 publishes Windows binaries only, and clients and server must run the same version.
# ----------------------------
FROM debian:bookworm-slim AS build

ARG DHEWM3_VERSION=1.5.2
ARG DHEWM3_SHA256=0652d85bcc470b8535dee0fc6badd57a82a183984f7a02a3fa13937436166eb0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        cmake \
        make \
        g++ \
        libsdl2-dev \
        libopenal-dev \
        libcurl4-openssl-dev \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --retry 3 -o /tmp/dhewm3.tar.gz "https://github.com/dhewm/dhewm3/archive/refs/tags/${DHEWM3_VERSION}.tar.gz" && \
    echo "${DHEWM3_SHA256}  /tmp/dhewm3.tar.gz" | sha256sum -c - && \
    mkdir -p /src && tar -xzf /tmp/dhewm3.tar.gz -C /src --strip-components=1 && \
    cmake -S /src/neo -B /build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCORE=OFF \
        -DDEDICATED=ON \
        -DBASE=ON \
        -DD3XP=ON \
        -DREPRODUCIBLE_BUILD=ON && \
    cmake --build /build -j"$(nproc)" && \
    mkdir -p /opt/dhewm3 && \
    cp /build/dhewm3ded /build/base.so /build/d3xp.so /opt/dhewm3/

# ----------------------------
# Runtime
# ----------------------------
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - Doom 3 needs the retail game data: base/pak000-008.pk4 (and d3xp/pak000-001.pk4 for
#     Resurrection of Evil) in /config/Server. The dhewm3 binaries are in /opt/dhewm3
#   - The D3_* settings are written into <D3_GAME>/lancommander.cfg on every start, which the
#     server execs before +spawnServer. Empty settings are left out
# ----------------------------
ENV D3_GAME="base" \
    D3_PORT="27666" \
    D3_SERVER_NAME="Doom 3 Server" \
    D3_MAP="game/mp/d3dm1" \
    D3_GAME_TYPE="deathmatch" \
    D3_MAX_PLAYERS="4" \
    D3_FRAG_LIMIT="10" \
    D3_TIME_LIMIT="10" \
    D3_PASSWORD="" \
    D3_RCON_PASSWORD="" \
    D3_PURE="1" \
    D3_WARMUP="0" \
    D3_TEAM_DAMAGE="0" \
    D3_SPECTATORS="1" \
    D3_LAN="true" \
    START_EXE="/usr/local/bin/d3-server" \
    START_ARGS=""

# dhewm3ded links SDL2 (threads/timers only), libcurl and zlib
RUN apt-get update && apt-get install -y --no-install-recommends \
        libsdl2-2.0-0 \
        libcurl4 \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/dhewm3/ /opt/dhewm3/

COPY Scripts/d3-server /usr/local/bin/d3-server
RUN chmod +x /usr/local/bin/d3-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27666/udp: game, queries and LAN browser (D3_PORT). The LAN browser broadcasts to 27666-27673
EXPOSE 27666/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
