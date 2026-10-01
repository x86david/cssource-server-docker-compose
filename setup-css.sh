#!/usr/bin/env bash
set -e

CLEAN_INSTALL=false

# Check if --clean argument was passed
for arg in "$@"; do
    if [ "$arg" == "--clean" ]; then
        CLEAN_INSTALL=true
        break
    fi
done

echo "===================================================="
echo "    CS:Source Server Deployment Script              "
echo "===================================================="

if [ "$CLEAN_INSTALL" = true ]; then
    echo "[!] Clean flag detected (--clean). Nuking old containers, volumes, and game data..."
    docker compose down -v || true
    rm -rf server-data cstrike-cfg Dockerfile docker-compose.yml
else
    echo "[*] Preservation mode: Keeping existing server data (pass --clean to wipe)."
    docker compose down || true
fi

# 1. Recreate workspace folders if missing
echo "[1/5] Initializing workspace directories..."
mkdir -p server-data cstrike-cfg

# 2. Create the Dockerfile
echo "[2/5] Generating Dockerfile..."
cat << 'EOF' > Dockerfile
FROM debian:bookworm-slim

LABEL maintainer="css-server-admin"

ENV DEBIAN_FRONTEND=noninteractive

# Install all system prerequisites, 32-bit libs, curl, and tar
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    lib32gcc-s1 \
    lib32stdc++6 \
    libssl-dev \
    libtinfo5:i386 \
    libcurl4 \
    libcurl4:i386 \
    zlib1g:i386 \
    && rm -rf /var/lib/apt/lists/*

# Create steam user
RUN useradd -ms /bin/bash steam
USER steam
WORKDIR /home/steam

# Download SteamCMD
RUN mkdir -p /home/steam/steamcmd && \
    cd /home/steam/steamcmd && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Expose CS:Source default port
EXPOSE 27015/udp
EXPOSE 27015/tcp
EOF

# 3. Create docker-compose.yml with host networking mode enabled
echo "[3/5] Generating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
services:
  css-server:
    build:
      context: .
    container_name: css_server_instance
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./server-data:/home/steam/css-server
      - ./cstrike-cfg:/home/steam/custom-cfg
    command:
      - bash
      - -c
      - |
        if [ ! -f /home/steam/css-server/srcds_run ]; then
          echo "Installing CS:Source Dedicated Server via SteamCMD (This may take a few minutes)..."
          /home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/css-server +login anonymous +app_update 232330 validate +quit
        else
          echo "Existing installation found. Checking for updates..."
          /home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/css-server +login anonymous +app_update 232330 +quit
        fi

        mkdir -p /home/steam/css-server/cstrike/cfg
        if [ -d /home/steam/custom-cfg ]; then
          cp -rn /home/steam/custom-cfg/* /home/steam/css-server/cstrike/cfg/ || true
        fi

        echo "Starting Counter-Strike: Source Server..."
        cd /home/steam/css-server
        ./srcds_run -console -game cstrike -secure -port 27015 +maxplayers 20 +map de_dust2
EOF

# 4. Create default server configuration if it doesn't already exist
if [ ! -f cstrike-cfg/server.cfg ]; then
    echo "[4/5] Creating default server configuration file with Bots & RCON..."
    cat << 'EOF' > cstrike-cfg/server.cfg
// --- Counter-Strike: Source Server Config ---
hostname "My Community CS:Source Server"
rcon_password "change_this_rcon_password"
sv_password ""

// --- Bot Configuration ---
bot_quota 10
bot_quota_mode fill
bot_difficulty 1
bot_chatter normal
bot_join_after_player 0
bot_defer_to_human 1

// Gameplay Settings
mp_timelimit 25
mp_roundtime 3
mp_freezetime 4
mp_buytime 0.25
mp_c4timer 35
mp_autokick 0
mp_teamplay 0
mp_friendlyfire 0

// Rates & Network
sv_minrate 25000
sv_maxrate 60000
sv_minupdaterate 33
sv_maxupdaterate 66
sv_mincmdrate 33
sv_maxcmdrate 66

// Server Logs
log on
sv_logbans 1
sv_logecho 1
sv_logfile 1
EOF
else
    echo "[4/5] Preserving existing server.cfg..."
fi

# 5. Build and launch container
echo "[5/5] Building image and starting container..."
docker compose build --no-cache
docker compose up -d

echo "==================================================+"
echo " Deployment Complete (Host Networking Active)!   "
echo "==================================================+"
echo " To monitor logs, run:"
echo "   docker compose logs -f"
echo "---------------------------------------------------"
