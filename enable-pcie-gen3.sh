#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}    ⚡ Raspberry Pi 5 PCIe Gen 3 (850+ MB/s) Speed Optimizer         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./enable-pcie-gen3.sh${NC}"
  exit 1
fi

MODEL=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)
if [[ "$MODEL" != *"Raspberry Pi 5"* ]]; then
    echo -e "${YELLOW}[!] Notice: Device is: '$MODEL'. PCIe Gen 3 toggle is specifically for Raspberry Pi 5.${NC}"
    read -rp "Proceed anyway? (y/N): " FORCE
    if [[ "$FORCE" != "y" && "$FORCE" != "Y" ]]; then
        exit 0
    fi
fi

CONFIG_FILE="/boot/firmware/config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/boot/config.txt"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}[!] Error: Raspberry Pi config.txt not found!${NC}"
    exit 1
fi

echo -e "${GREEN}[*] Configuring $CONFIG_FILE for PCIe Gen 3 mode...${NC}"

# Remove existing pciex entries if any
sed -i '/dtparam=pciex1/d' "$CONFIG_FILE"

# Append PCIe Gen 3 parameters
{
    echo ""
    echo "# PiCloud Photos: NVMe PCIe Gen 3 Speed Optimization"
    echo "dtparam=pciex1"
    echo "dtparam=pciex1_gen=3"
} >> "$CONFIG_FILE"

echo -e "\n${GREEN}[✓] PCIe Gen 3 has been enabled in $CONFIG_FILE!${NC}"
echo -e "${YELLOW}[*] A system reboot is required for PCIe Gen 3 speed to take effect.${NC}"
read -rp "Reboot Raspberry Pi now? (y/N): " REBOOT_NOW
if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
    reboot
else
    echo -e "${BLUE}Remember to reboot when convenient: sudo reboot${NC}"
fi
