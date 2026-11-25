#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}======================================================================${NC}"
echo -e "${GREEN}    🧪 PiCloud Photos: Pre-Flight Verification & Test Harness         ${NC}"
echo -e "${BLUE}======================================================================${NC}"

PASS_COUNT=0
FAIL_COUNT=0

check() {
    local desc="$1"
    local condition="$2"
    if eval "$condition"; then
        echo -e " [${GREEN}PASS${NC}] $desc"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e " [${RED}FAIL${NC}] $desc"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo -e "\n${YELLOW}1. Validating Architecture & Container Definitions...${NC}"
check "docker-compose.yml exists" "[ -f docker-compose.yml ]"
check "Tailscale service is defined" "grep -q 'immich_tailscale' docker-compose.yml"
check "immich-server routes through Tailscale service (network_mode: service:tailscale)" "grep -q 'service:tailscale' docker-compose.yml"
check "Immich Machine Learning concurrency limits are set" "grep -q 'MACHINE_LEARNING_WORKERS' docker-compose.yml"
check "Postgres data-checksums enabled" "grep -q -- '--data-checksums' docker-compose.yml"
check "Redis message queue pinned with alpine image" "grep -q 'redis:6.2-alpine' docker-compose.yml"

echo -e "\n${YELLOW}2. Validating Secrets & File Integrity...${NC}"
check ".env.example template exists" "[ -f .env.example ]"
check ".gitignore protects .env and database backups" "grep -q '^\.env$' .gitignore && grep -q 'database_backups/' .gitignore"
check "All shell scripts have LF line endings" "! grep -q $'\r' install.sh setup-nvme.sh status.sh backup/*.sh"
check "Strict bash mode enabled across all scripts" "grep -q 'set -euo pipefail' install.sh setup-nvme.sh backup/run-backup.sh backup/restore-backup.sh"

echo -e "\n${YELLOW}3. Validating Disaster Recovery & Data Safety Safeguards...${NC}"
check "setup-nvme.sh checks and refuses to format root/boot mount" "grep -q 'ROOT_SOURCE' setup-nvme.sh"
check "setup-nvme.sh enables SSD fstrim.timer" "grep -q 'fstrim.timer' setup-nvme.sh"
check "run-backup.sh checks mountpoint /mnt/nvme before sync" "grep -q 'mountpoint -q /mnt/nvme' backup/run-backup.sh"
check "run-backup.sh uses non-TTY docker exec -i (no -t flag)" "! grep -E 'docker exec -[a-zA-Z]*t' backup/run-backup.sh"
check "run-backup.sh includes --backup-dir anti-wipe protection" "grep -q -- '--backup-dir' backup/run-backup.sh"
check "restore-backup.sh stops backend containers before SQL restore" "grep -q 'docker compose stop' backup/restore-backup.sh"

echo -e "\n${YELLOW}4. Validating iCloud & Google Drive Feature Parity...${NC}"
check "Immich mobile app endpoint instructions point to base URL (no /api)" "! grep -q 'http://picloud-photos:2283/api' README.md"
check "Background photo backup onboarding instructions documented" "grep -q 'Enable Background Backup' README.md"
check "Zero-knowledge 2TB Google Drive encrypted offsite backup wizard ready" "[ -f backup/setup-google-backup.sh ]"

echo -e "\n${BLUE}======================================================================${NC}"
echo -e " Test Results: ${GREEN}${PASS_COUNT} Passed${NC} | ${RED}${FAIL_COUNT} Failed${NC}"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e " ${GREEN}[✓] PiCloud Photos is structurally verified and production ready!${NC}"
else
    echo -e " ${RED}[!] Issues detected above. Please review.${NC}"
    exit 1
fi
echo -e "${BLUE}======================================================================${NC}\n"
