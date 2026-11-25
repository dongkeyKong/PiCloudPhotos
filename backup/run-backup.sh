#!/usr/bin/env bash
set -euo pipefail
umask 077
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$REPO_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$REPO_DIR/.env"
    set +a
fi

DB_USER="${DB_USERNAME:-postgres}"

# Prevent concurrent backup runs
LOCK_FILE="/tmp/picloud-backup.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "[!] Backup already running; exiting."; exit 0; }

# DLP safeguard: never rclone sync an unmounted empty directory to remote
if ! mountpoint -q /mnt/nvme; then
    echo "[!] FATAL: /mnt/nvme is not mounted! Aborting backup to protect offsite data." >&2
    if [ -n "${NTFY_TOPIC:-}" ]; then
        curl -s -d "🚨 PiCloud Backup Aborted: /mnt/nvme is not mounted!" "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null || true
    fi
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/mnt/nvme/immich/database_backups"
UPLOAD_DIR="${UPLOAD_LOCATION:-/mnt/nvme/immich/upload}"
REMOTE="gdrive-encrypted:"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "========================================================================"
echo " 📦 PiCloud Photos: Encrypted 2TB Google Drive Backup Job"
echo " Started at: $(date)"
echo "========================================================================"

# 1. Dump PostgreSQL database cleanly (NO -t flag in cron; fail pipeline on dump error)
echo "[1/3] Creating PostgreSQL database dump..."
DUMP_FILE="$BACKUP_DIR/immich_db_${TIMESTAMP}.sql.gz"
TMP_DUMP="${DUMP_FILE}.tmp"
trap 'rm -f "$TMP_DUMP"' EXIT

docker exec -i immich_postgres pg_dumpall --clean --if-exists -U "$DB_USER" | gzip > "$TMP_DUMP"

if [ ! -s "$TMP_DUMP" ]; then
    echo "[!] FATAL: Database dump is empty!" >&2
    exit 1
fi
gzip -t "$TMP_DUMP"
mv "$TMP_DUMP" "$DUMP_FILE"
chmod 600 "$DUMP_FILE"
echo "[✓] Database snapshot created: $DUMP_FILE ($(du -h "$DUMP_FILE" | awk '{print $1}'))"

# Keep only the last 7 daily database backups locally
find "$BACKUP_DIR" -type f -name "immich_db_*.sql.gz" -mtime +7 -delete

# 2. Sync database dumps to Encrypted Google Drive
echo "[2/3] Uploading encrypted database snapshot to Google Drive..."
rclone copy "$BACKUP_DIR" "${REMOTE}database_backups" --transfers=4 --fast-list

# 3. Incremental sync of photo repository (Anti-wipe: archive deleted/modified files instead of instant purging)
echo "[3/3] Syncing photo repository to Encrypted Google Drive (Incremental)..."
PROGRESS_FLAG=""
if [ -t 1 ]; then
    PROGRESS_FLAG="--progress"
else
    PROGRESS_FLAG="--stats-one-line --stats=60s"
fi

rclone sync "$UPLOAD_DIR" "${REMOTE}upload" \
    --backup-dir "${REMOTE}archive/${TIMESTAMP}" \
    --max-delete 100 \
    --transfers=4 \
    --checkers=8 \
    --fast-list \
    $PROGRESS_FLAG \
    --exclude "thumbs/**" \
    --exclude "encoded-video/**"

echo ""
echo "========================================================================"
echo "[✓] Backup Completed Successfully at: $(date)"
echo "========================================================================"

# Optional alert notification via ntfy
if [ -n "${NTFY_TOPIC:-}" ]; then
    curl -s -d "📸 PiCloud Photos backup completed successfully ($(date +%Y-%m-%d))" "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null || true
fi
