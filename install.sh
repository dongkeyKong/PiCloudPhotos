#!/usr/bin/env bash
set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Environment & Password Security Hardening
echo -e "${GREEN}[1/5] Checking configuration and generating secure secrets...${NC}"
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        echo -e "${RED}[!] .env.example not found.${NC}"
        exit 1
    fi
fi

# Auto-generate a strong random password if default or empty
CURRENT_PASS=$(grep '^DB_PASSWORD=' .env | cut -d '=' -f2- || true)
if [[ -z "$CURRENT_PASS" || "$CURRENT_PASS" == "SecureFamilyPass2026!" ]]; then
    NEW_PASS=$(openssl rand -hex 18)
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${NEW_PASS}/" .env
    echo -e "${YELLOW}[*] Generated unique high-entropy database password in .env.${NC}"
fi

# Set proper file permissions on .env
chmod 600 .env

# 2. Swap Space Verification (Crucial for Raspberry Pi stability during ML indexing)
echo -e "${GREEN}[2/5] Verifying system swap space...${NC}"
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')

if [ "$TOTAL_SWAP_MB" -lt 2000 ]; then
    echo -e "${YELLOW}[*] Swap is under 2GB (current: ${TOTAL_SWAP_MB}MB). Creating 4GB swap on NVMe to prevent OOM...${NC}"
    if [ -d "/mnt/nvme" ]; then
        SWAPFILE="/mnt/nvme/picloud_swap"
        if [ ! -f "$SWAPFILE" ]; then
            fallocate -l 4G "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=4096
            chmod 600 "$SWAPFILE"
            mkswap "$SWAPFILE"
            swapon "$SWAPFILE"
            if ! grep -q "$SWAPFILE" /etc/fstab; then
                echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
            fi
            echo -e "${GREEN}[✓] 4GB NVMe swapfile activated.${NC}"
        fi
    fi
fi

# 3. Verify Docker Engine & Compose
echo -e "${GREEN}[3/5] Verifying Docker and Compose engine...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}[*] Installing Docker engine...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
fi

if ! docker compose version &> /dev/null; then
    apt-get update && apt-get install -y docker-compose-plugin
fi

# 4. Verify NVMe Mount
echo -e "${GREEN}[4/5] Checking high-speed NVMe storage mount...${NC}"
if ! mountpoint -q /mnt/nvme && [ ! -d "/mnt/nvme/immich/upload" ]; then
    echo -e "${YELLOW}[*] NVMe photo directory not initialized. Running setup-nvme.sh...${NC}"
    chmod +x setup-nvme.sh
    ./setup-nvme.sh
fi

# Ensure correct POSIX permissions on storage directories
mkdir -p /mnt/nvme/immich/upload /mnt/nvme/immich/postgres /mnt/nvme/immich/database_backups
chmod 700 /mnt/nvme/immich/postgres
chmod 750 /mnt/nvme/immich/upload /mnt/nvme/immich/database_backups
chown -R 1000:1000 /mnt/nvme/immich/upload /mnt/nvme/immich/database_backups 2>/dev/null || true

# 5. Pull and Launch Containers
echo -e "${GREEN}[5/5] Launching Immich + Tailscale zero-trust stack...${NC}"
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
sleep 4
if docker exec immich_tailscale tailscale status 2>&1 | grep -E -q "Logged out|needs login|Stopped"; then
    echo -e "\n${YELLOW}[!] Tailscale Login Required:${NC}"
    echo -e "    Run this command on your Pi to link it to your free Tailscale account:"
    echo -e "    ${GREEN}sudo docker exec -it immich_tailscale tailscale up${NC}"
    echo -e "    (Then click the printed URL to authorize 'picloud-photos')"
fi

echo -e "\n${PURPLE}======================================================================${NC}"
echo -e "${YELLOW}Family Onboarding Checklist:${NC}"
echo -e "  1. Open ${GREEN}http://${PI_IP}:2283${NC} in your browser to create the Admin account."
echo -e "  2. Go to 'Administration' ➔ 'Users' and create accounts for your family."
echo -e "  3. Install the 'Immich' and 'Tailscale' apps on family phones."
echo -e "  4. Set the Immich app server URL to: ${GREEN}http://picloud-photos:2283${NC}"
echo -e "     (Note: Do NOT append /api - recent Immich app versions require base URL!)"
echo -e "  5. (Optional) Run ${BLUE}./backup/setup-google-backup.sh${NC} to enable encrypted 2TB cloud backup."
echo -e "${PURPLE}======================================================================${NC}\n"
