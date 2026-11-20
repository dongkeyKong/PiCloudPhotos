#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

REMOTE="gdrive-encrypted:"
RESTORE_DIR="/mnt/nvme/immich"

echo -e "${RED}======================================================================${NC}"
echo -e "${YELLOW}   🚨 PiCloud Photos Disaster Recovery: Google Drive Restore         ${NC}"
echo -e "${RED}======================================================================${NC}"

read -p "Are you sure you want to restore photos and database from Google Drive? (y/N): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "\n${GREEN}[1/3] Downloading latest encrypted photo repository...${NC}"
mkdir -p "$RESTORE_DIR/upload" "$RESTORE_DIR/database_backups"
rclone sync "${REMOTE}upload" "$RESTORE_DIR/upload" --progress --transfers=4

echo -e "\n${GREEN}[2/3] Downloading latest database snapshots...${NC}"
rclone sync "${REMOTE}database_backups" "$RESTORE_DIR/database_backups" --progress

LATEST_DB=$(ls -t "$RESTORE_DIR/database_backups"/immich_db_*.sql.gz | head -n 1)

if [ -f "$LATEST_DB" ]; then
    echo -e "\n${GREEN}[3/3] Restoring PostgreSQL database from: $LATEST_DB...${NC}"
    gunzip -c "$LATEST_DB" | docker exec -i immich_postgres psql -U postgres
    echo -e "${GREEN}[✓] Database restored! Restarting Immich services...${NC}"
    docker compose restart
else
    echo -e "${YELLOW}[!] No database snapshot found to restore.${NC}"
fi

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}[✓] Disaster Recovery Restore Complete! All Photos & Albums are back.${NC}"
echo -e "${BLUE}======================================================================${NC}\n"
