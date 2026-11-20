#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}    ☁️ Google One / Gemini 2TB Encrypted Backup Setup                 ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# 1. Install Rclone if missing
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}[*] Installing rclone (Universal Cloud Storage Sync tool)...${NC}"
    curl https://rclone.org/install.sh | sudo bash
fi

echo -e "\n${YELLOW}Step 1: Connecting your Google Drive account (2TB Storage)${NC}"
echo -e "We will now launch the interactive rclone configurator."
echo -e "  1. Choose: ${GREEN}'n'${NC} (New remote)"
echo -e "  2. Name:   ${GREEN}'gdrive'${NC}"
echo -e "  3. Type:   ${GREEN}'drive'${NC} (Google Drive)"
echo -e "  4. Leave client_id & client_secret blank (press Enter)."
echo -e "  5. Scope:  ${GREEN}'1'${NC} (Full access to files created by rclone)"
echo -e "  6. Follow the on-screen link to log in to your Google Account."
echo ""
read -p "Press [Enter] to launch rclone config..."
rclone config

echo -e "\n${YELLOW}Step 2: Creating Client-Side Encryption Layer ('gdrive-encrypted')${NC}"
echo -e "This ensures Google CANNOT scan or see your family photos."
echo -e "  1. Choose: ${GREEN}'n'${NC} (New remote)"
echo -e "  2. Name:   ${GREEN}'gdrive-encrypted'${NC}"
echo -e "  3. Type:   ${GREEN}'crypt'${NC}"
echo -e "  4. Remote: ${GREEN}'gdrive:Immich_Encrypted_Backup'${NC}"
echo -e "  5. Filename & Directory Encryption: ${GREEN}'standard'${NC}"
echo -e "  6. Enter a strong master encryption password and SAVE IT IN A SAFE PLACE!"
echo ""
read -p "Press [Enter] to set up encryption..."
rclone config

# Test connection
echo -e "\n${GREEN}[*] Testing connection to your encrypted Google Drive...${NC}"
if rclone lsd gdrive-encrypted: 2>/dev/null; then
    echo -e "${GREEN}[✓] SUCCESS: Connected to Encrypted Google Drive!${NC}"
else
    echo -e "${YELLOW}[!] Warning: Please verify 'gdrive-encrypted' is listed in 'rclone listremotes'.${NC}"
fi

# Add automated nightly cron job at 3:00 AM
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-backup.sh"
chmod +x "$SCRIPT_PATH"

echo -e "\n${GREEN}[*] Scheduling automatic nightly backup at 3:00 AM via cron...${NC}"
(crontab -l 2>/dev/null | grep -v "run-backup.sh" ; echo "0 3 * * * $SCRIPT_PATH >> /mnt/nvme/immich/backup.log 2>&1") | crontab -

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}[✓] Automated 2TB Google Drive Encrypted Backup is Configured!${NC}"
echo -e "  • All photos will be AES-256 encrypted locally before leaving the Pi."
echo -e "  • Runs automatically every night at 3:00 AM."
echo -e "  • You can trigger a manual backup anytime by running:"
echo -e "    ${GREEN}$SCRIPT_PATH${NC}"
echo -e "${BLUE}======================================================================${NC}\n"
