#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}       📸 Raspberry Pi NVMe Auto-Mounter for Family Photos            ${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./setup-nvme.sh <DISK_DEVICE>${NC}"
  echo -e "    Example: sudo ./setup-nvme.sh /dev/nvme0n1"
  exit 1
fi

DISK="$1"
if [ -z "$DISK" ]; then
    echo -e "${YELLOW}[*] Available NVMe / SSD Disks:${NC}"
    lsblk -d -o NAME,SIZE,MODEL | grep -E "nvme|sd" || true
    echo ""
    read -p "Enter your NVMe disk device name (e.g., /dev/nvme0n1 or /dev/sda): " DISK
fi

if [ ! -b "$DISK" ]; then
    echo -e "${RED}[!] Error: Device $DISK not found!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[!] WARNING: This will format $DISK as ext4 for photo storage.${NC}"
read -p "Proceed with formatting $DISK? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "\n${GREEN}[1/4] Formatting NVMe drive to ext4 with write-caching enabled...${NC}"
mkfs.ext4 -F -L "NVME_PHOTOS" "$DISK"

echo -e "${GREEN}[2/4] Creating persistent mount directory /mnt/nvme...${NC}"
mkdir -p /mnt/nvme

echo -e "${GREEN}[3/4] Configuring /etc/fstab for persistent auto-mount on reboot...${NC}"
UUID=$(blkid -s UUID -o value "$DISK")
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID  /mnt/nvme  ext4  defaults,noatime,commit=60  0  2" >> /etc/fstab
fi

mount -a

echo -e "${GREEN}[4/4] Setting up directory structures and permissions...${NC}"
mkdir -p /mnt/nvme/immich/upload /mnt/nvme/immich/postgres
chmod -R 777 /mnt/nvme/immich

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}[✓] NVMe Disk Formatted and Mounted at: /mnt/nvme${NC}"
echo -e "${BLUE}    Free Space: $(df -h /mnt/nvme | awk 'NR==2{print $4}')${NC}"
echo -e "${BLUE}======================================================================${NC}\n"
