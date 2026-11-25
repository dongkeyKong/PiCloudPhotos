#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}       📸 Raspberry Pi NVMe Auto-Mounter for Family Photos            ${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./setup-nvme.sh [DISK_DEVICE]${NC}"
  echo -e "    Example: sudo ./setup-nvme.sh /dev/nvme0n1"
  exit 1
fi

DISK="${1:-}"
if [ -z "$DISK" ]; then
    echo -e "${YELLOW}[*] Available Block Devices:${NC}"
    lsblk -e 7,11 -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL
    echo ""
    read -rp "Enter target disk for photo storage (e.g., /dev/nvme0n1 or /dev/sda): " DISK
fi

if [ ! -b "$DISK" ]; then
    echo -e "${RED}[!] Error: Device '$DISK' not found!${NC}"
    exit 1
fi

# CRITICAL SAFETY CHECK: Prevent formatting disk holding root or boot partition!
ROOT_SOURCE=$(findmnt -n -o SOURCE / 2>/dev/null || true)
BOOT_SOURCE=$(findmnt -n -o SOURCE /boot/firmware 2>/dev/null || findmnt -n -o SOURCE /boot 2>/dev/null || true)

if [[ -n "$ROOT_SOURCE" && "$ROOT_SOURCE" == *"${DISK#/dev/}"* ]] || [[ -n "$BOOT_SOURCE" && "$BOOT_SOURCE" == *"${DISK#/dev/}"* ]]; then
    echo -e "${RED}[FATAL ERROR] Refusing to format: '$DISK' contains active OS or boot partitions!${NC}"
    echo -e "Root partition: $ROOT_SOURCE"
    echo -e "Boot partition: $BOOT_SOURCE"
    exit 1
fi

# Check if disk or any of its partitions are currently mounted
MOUNTED_PARTS=$(lsblk -rn -o MOUNTPOINT "$DISK" | grep -v '^$' || true)
if [ -n "$MOUNTED_PARTS" ]; then
    echo -e "${RED}[!] Warning: Device '$DISK' or its partitions are mounted at:${NC}"
    echo "$MOUNTED_PARTS"
    echo -e "${RED}Please unmount them first before running this setup script.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[!] WARNING: This will format $DISK with a GPT partition table and ext4 filesystem.${NC}"
echo -e "${YELLOW}    All data on $DISK will be permanently erased.${NC}"
read -rp "Are you completely sure you want to format $DISK? (type 'yes'): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "\n${GREEN}[1/5] Creating GPT partition table and partition...${NC}"
if command -v parted &>/dev/null; then
    parted -s "$DISK" mklabel gpt
    parted -s -a optimal "$DISK" mkpart primary ext4 0% 100%
else
    apt-get update && apt-get install -y parted
    parted -s "$DISK" mklabel gpt
    parted -s -a optimal "$DISK" mkpart primary ext4 0% 100%
fi

# Determine partition device name (e.g. nvme0n1p1 vs sda1)
sleep 2
partprobe "$DISK" 2>/dev/null || true

if [[ "$DISK" =~ [0-9]$ ]]; then
    PARTITION="${DISK}p1"
else
    PARTITION="${DISK}1"
fi

if [ ! -b "$PARTITION" ]; then
    PARTITION="$DISK"
fi

echo -e "${GREEN}[2/5] Formatting $PARTITION to ext4 (tuned for fast photo writes)...${NC}"
mkfs.ext4 -F -L "NVME_PHOTOS" -m 1 "$PARTITION"

echo -e "${GREEN}[3/5] Setting up persistent mount directory /mnt/nvme...${NC}"
mkdir -p /mnt/nvme

UUID=$(blkid -s UUID -o value "$PARTITION")
if [ -z "$UUID" ]; then
    echo -e "${RED}[!] Error: Could not determine UUID for $PARTITION${NC}"
    exit 1
fi

echo -e "${GREEN}[4/5] Updating /etc/fstab with auto-mount options...${NC}"
# Remove any existing /mnt/nvme entries to avoid duplicates
sed -i '\|/mnt/nvme|d' /etc/fstab
echo "UUID=$UUID  /mnt/nvme  ext4  defaults,noatime,commit=30  0  2" >> /etc/fstab

mount -a

# Enable SSD TRIM timer for NVMe wear leveling and sustained speed
systemctl enable --now fstrim.timer 2>/dev/null || true

echo -e "${GREEN}[5/5] Enforcing POSIX security permissions on /mnt/nvme/immich...${NC}"
mkdir -p /mnt/nvme/immich/upload /mnt/nvme/immich/postgres /mnt/nvme/immich/database_backups

# Least-privilege POSIX permissions:
# Postgres strictly requires 0700 permissions
chmod 700 /mnt/nvme/immich/postgres
# Uploads and backups: restricted access
chmod 750 /mnt/nvme/immich/upload /mnt/nvme/immich/database_backups
chown -R 1000:1000 /mnt/nvme/immich/upload /mnt/nvme/immich/database_backups 2>/dev/null || true

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}[✓] NVMe Disk Formatted and Mounted securely at: /mnt/nvme${NC}"
echo -e "${BLUE}    Free Space: $(df -h /mnt/nvme | awk 'NR==2{print $4}')${NC}"
echo -e "${BLUE}    TRIM Timer : Enabled (fstrim.timer)${NC}"
echo -e "${BLUE}======================================================================${NC}\n"
