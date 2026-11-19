#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${PURPLE}======================================================================${NC}"
echo -e "${GREEN}    🔒 PiCloud Photos: Secure Family Backup with Tailscale VPN        ${NC}"
echo -e "${PURPLE}======================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./install.sh${NC}"
  exit 1
fi

# 1. Verify Docker Engine
echo -e "${GREEN}[1/4] Verifying Docker and Compose engine...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[*] Installing Docker engine...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
fi

if ! docker compose version &> /dev/null; then
    apt-get update && apt-get install -y docker-compose-plugin
fi

# 2. Verify NVMe Mount
echo -e "${GREEN}[2/4] Checking high-speed NVMe storage mount...${NC}"
if [ ! -d "/mnt/nvme/immich/upload" ]; then
    echo -e "${YELLOW}[*] NVMe photo directory not initialized. Running setup-nvme.sh...${NC}"
    chmod +x setup-nvme.sh
    ./setup-nvme.sh
fi

# 3. Security Hardening: Ensure strict permissions on database and photo storage
echo -e "${GREEN}[3/4] Enforcing POSIX security permissions on /mnt/nvme...${NC}"
chown -R 1000:1000 /mnt/nvme/immich/upload 2>/dev/null || true
chmod 700 /mnt/nvme/immich/postgres 2>/dev/null || true

# 4. Pull and Launch Containers
echo -e "${GREEN}[4/4] Launching Immich + Tailscale zero-trust stack...${NC}"
docker compose pull
docker compose up -d

PI_IP=$(hostname -I | awk '{print $1}')
if [ -z "$PI_IP" ]; then
    PI_IP="<your-pi-ip>"
fi

echo -e "\n${PURPLE}======================================================================${NC}"
echo -e "${GREEN}[✓] PiCloud Photo Backup is Running Securely!${NC}"
echo -e "${PURPLE}======================================================================${NC}"
echo -e "  🏠 Local Home Wi-Fi URL:  ${GREEN}http://${PI_IP}:2283${NC}"
echo -e "  🔐 Zero-Trust Tailscale: Connecting to your private mesh VPN..."

# Check if Tailscale needs interactive authorization
sleep 3
if docker exec immich_tailscale tailscale status | grep -q "Logged out"; then
    echo -e "\n${YELLOW}[!] Tailscale Login Required:${NC}"
    echo -e "    Run this command on your Pi to link it to your free Tailscale account:"
    echo -e "    ${GREEN}sudo docker exec -it immich_tailscale tailscale up${NC}"
fi

echo -e "\n${PURPLE}======================================================================${NC}"
echo -e "${YELLOW}Family Onboarding Checklist:${NC}"
echo -e "  1. Open http://${PI_IP}:2283 in browser to create your Admin account."
echo -e "  2. Go to 'Administration' ➔ 'Users' and create accounts for your family."
echo -e "  3. Install the 'Immich' and 'Tailscale' apps on your family's phones."
echo -e "  4. Set the Immich app server URL to: ${GREEN}http://picloud-photos:2283/api${NC}"
echo -e "     (Photos will now back up automatically anywhere in the world!)"
echo -e "${PURPLE}======================================================================${NC}\n"
