#!/usr/bin/env bash
set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/mnt/nvme/immich/database_backups"
UPLOAD_DIR="/mnt/nvme/immich/upload"
REMOTE="gdrive-encrypted:"

mkdir -p "$BACKUP_DIR"

echo "========================================================================"
echo " 📦 PiCloud Photos: Encrypted 2TB Google Drive Backup Job"
echo " Started at: $(date)"
echo "========================================================================"

# 1. Dump PostgreSQL database (preserves user accounts, albums, tags, facial metadata)
echo "[1/3] Creating PostgreSQL database dump..."
DUMP_FILE="$BACKUP_DIR/immich_db_${TIMESTAMP}.sql.gz"
docker exec -t immich_postgres pg_dumpall -c -U postgres | gzip > "$DUMP_FILE"
echo "[✓] Database snapshot created: $DUMP_FILE ($(du -h "$DUMP_FILE" | awk '{print $1}'))"

# Keep only the last 7 daily database backups locally
find "$BACKUP_DIR" -type f -name "immich_db_*.sql.gz" -mtime +7 -delete

# 2. Sync database dumps to Encrypted Google Drive
echo "[2/3] Uploading encrypted database snapshot to Google Drive..."
rclone copy "$BACKUP_DIR" "${REMOTE}database_backups" --transfers=4 --fast-list

# 3. Incremental sync of photo & video repository (AES-256 client-side encrypted)
echo "[3/3] Syncing photo repository to Encrypted Google Drive (Incremental)..."
rclone sync "$UPLOAD_DIR" "${REMOTE}upload" \
    --transfers=4 \
    --checkers=8 \
    --fast-list \
    --progress \
    --exclude "thumbs/**" \
    --exclude "encoded-video/**"

echo ""
echo "========================================================================"
echo "[✓] Backup Completed Successfully at: $(date)"
echo "========================================================================"
