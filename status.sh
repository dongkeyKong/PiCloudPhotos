#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}            📸 PiCloud Photos: System & Storage Status                 ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Hardware & System Temp
echo -e "\n${YELLOW}─── 🌡️ System & Thermals ──────────────────────────────────────────────${NC}"
if command -v vcgencmd &>/dev/null; then
    CPU_TEMP=$(vcgencmd measure_temp 2>/dev/null || echo "N/A")
    echo -e "CPU Temperature : ${GREEN}${CPU_TEMP}${NC}"
else
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        MILLI_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
        CPU_C=$(awk "BEGIN {print $MILLI_TEMP/1000}")
        echo -e "CPU Temperature : ${GREEN}${CPU_C}°C${NC}"
    else
        echo -e "CPU Temperature : N/A"
    fi
fi

MODEL=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo "Linux Server")
echo -e "Hardware Model  : $MODEL"
echo -e "Uptime          : $(uptime -p 2>/dev/null || uptime)"

# 2. Memory & Swap
echo -e "\n${YELLOW}─── 🧠 Memory & Swap (OOM Guard) ──────────────────────────────────────${NC}"
free -h

# 3. NVMe Storage & TRIM
echo -e "\n${YELLOW}─── 💾 NVMe Photo Storage ─────────────────────────────────────────────${NC}"
if mountpoint -q /mnt/nvme; then
    df -h /mnt/nvme
    echo -e "Mount Status    : ${GREEN}Mounted & Active at /mnt/nvme${NC}"
else
    echo -e "Mount Status    : ${RED}NOT MOUNTED (/mnt/nvme)${NC}"
fi

# 4. Containers Status
echo -e "\n${YELLOW}─── 🐳 Container Stack ────────────────────────────────────────────────${NC}"
if command -v docker &>/dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "immich|tailscale|redis" || true
else
    echo "Docker is not installed."
fi

# 5. Tailscale Mesh Status
echo -e "\n${YELLOW}─── 🔐 Tailscale Mesh Network ──────────────────────────────────────────${NC}"
if docker ps --format '{{.Names}}' | grep -q 'immich_tailscale'; then
    TS_STAT=$(docker exec immich_tailscale tailscale status 2>&1 || true)
    if echo "$TS_STAT" | grep -qi "Logged out"; then
        echo -e "Tailscale Status: ${RED}Logged Out${NC} (Run: sudo docker exec -it immich_tailscale tailscale up)"
    else
        TS_IP=$(docker exec immich_tailscale tailscale ip -4 2>/dev/null || echo "Unknown")
        echo -e "Tailscale Status: ${GREEN}Connected & Active${NC}"
        echo -e "Tailscale IPv4  : ${GREEN}${TS_IP}${NC}"
        echo -e "Tailscale URL   : ${GREEN}http://picloud-photos:2283${NC}"
    fi
else
    echo "Tailscale container not running."
fi

# 6. Offsite Google Drive Backup Status
echo -e "\n${YELLOW}─── ☁️ Encrypted 2TB Backup Status ────────────────────────────────────${NC}"
BACKUP_DIR="/mnt/nvme/immich/database_backups"
if [ -d "$BACKUP_DIR" ]; then
    LATEST_LOCAL=$(find "$BACKUP_DIR" -type f -name "immich_db_*.sql.gz" 2>/dev/null | sort -r | head -n 1 || true)
    if [ -n "$LATEST_LOCAL" ]; then
        echo -e "Latest DB Backup: $(basename "$LATEST_LOCAL") ($(du -h "$LATEST_LOCAL" | awk '{print $1}'))"
    else
        echo -e "Latest DB Backup: None found yet"
    fi
fi

if [ -f "/mnt/nvme/immich/backup.log" ]; then
    echo -e "\nRecent Backup Log Tail:"
    tail -n 5 /mnt/nvme/immich/backup.log
fi

echo -e "\n${BLUE}======================================================================${NC}\n"
