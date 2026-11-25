#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

if [ -f "$REPO_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_DIR/.env"
    set +a
fi

DB_USER="${DB_USERNAME:-postgres}"
DB_NAME="${DB_DATABASE_NAME:-immich}"
REMOTE="gdrive-encrypted:"
RESTORE_DIR="/mnt/nvme/immich"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}======================================================================${NC}"
echo -e "${YELLOW}   🚨 PiCloud Photos Disaster Recovery: Google Drive Restore         ${NC}"
echo -e "${RED}======================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root: sudo ./backup/restore-backup.sh${NC}"
  exit 1
fi

if ! mountpoint -q /mnt/nvme; then
    echo -e "${RED}[!] FATAL: /mnt/nvme is not mounted! Please mount your NVMe drive before restoring.${NC}" >&2
    exit 1
fi

read -rp "Are you sure you want to restore photos and database from Google Drive? (type 'yes'): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "\n${GREEN}[1/3] Downloading latest encrypted photo repository...${NC}"
mkdir -p "$RESTORE_DIR/upload" "$RESTORE_DIR/database_backups"
chmod 750 "$RESTORE_DIR/upload"
chmod 700 "$RESTORE_DIR/database_backups"

# Use 'copy' instead of destructive 'sync' to prevent wiping local files
rclone copy "${REMOTE}upload" "$RESTORE_DIR/upload" --progress --transfers=4
chown -R 1000:1000 "$RESTORE_DIR/upload" 2>/dev/null || true

echo -e "\n${GREEN}[2/3] Downloading latest database snapshots...${NC}"
rclone copy "${REMOTE}database_backups" "$RESTORE_DIR/database_backups" --progress

LATEST_DB=$(find "$RESTORE_DIR/database_backups" -maxdepth 1 -type f -name 'immich_db_*.sql.gz' 2>/dev/null | sort -r | head -n 1 || true)

if [ -n "$LATEST_DB" ] && [ -f "$LATEST_DB" ]; then
    echo -e "\n${GREEN}[3/3] Restoring PostgreSQL database from: $LATEST_DB...${NC}"
    echo -e "${YELLOW}[*] Stopping Immich backend containers to release database locks...${NC}"
    docker compose stop immich-server immich-machine-learning || true
    docker compose up -d database

    echo -e "${YELLOW}[*] Waiting for PostgreSQL readiness...${NC}"
    until docker exec immich_postgres pg_isready -U "$DB_USER" -d postgres >/dev/null 2>&1; do sleep 2; done

    # Terminate any lingering sessions on the database
    docker exec immich_postgres psql -U "$DB_USER" -d postgres -c \
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" >/dev/null 2>&1 || true

    gunzip -c "$LATEST_DB" | docker exec -i immich_postgres psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres
    echo -e "${GREEN}[✓] Database restored! Restarting Immich services...${NC}"
    docker compose up -d
else
    echo -e "${YELLOW}[!] No database snapshot found to restore in $RESTORE_DIR/database_backups.${NC}"
fi

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${GREEN}[✓] Disaster Recovery Restore Complete! All Photos & Albums are back.${NC}"
echo -e "${BLUE}======================================================================${NC}\n"
