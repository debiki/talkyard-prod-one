#!/bin/bash

# Ensure exactly 1 parameter is provided
if [ -z "$1" ]; then
    echo "Error: Backup directory path is required." >&2
    echo "Usage: $0 /path/to/backup/dir" >&2
    exit 2
fi

BACKUP_DIR="$1"

# Verify the directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Directory '$BACKUP_DIR' does not exist." >&2
    exit 2
fi

TODAY=$(date +%Y-%m-%d)
CURRENT_MONTH=$(date +%Y-%m)

AMISS=0
ERRORS=()

# 1. Check if disk utilization is > 90%
DISK_USAGE=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 90 ]; then
    AMISS=1
    ERRORS+=("Disk usage is critically high at ${DISK_USAGE}%.")
fi

# 2. Verify current month's uploads folder exists
UPLOAD_DIR="${BACKUP_DIR}/tyc-gcew1dal25a-uploads-up-to-incl-${CURRENT_MONTH}.d"
if [ ! -d "$UPLOAD_DIR" ]; then
    AMISS=1
    ERRORS+=("Upload directory for ${CURRENT_MONTH} is missing.")
fi

# 3. Define and check the 4 expected daily components
COMPONENTS=("postgres.sql.gz" "redis.rdb.gz" "config.tar.gz" "random-value.txt")

for comp in "${COMPONENTS[@]}"; do
    FILE=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*${TODAY}*${comp}" | head -n 1)

    if [ -z "$FILE" ]; then
        AMISS=1
        ERRORS+=("Missing today's backup file for: ${comp}")
    else
        SIZE=$(stat -c %s "$FILE")
        
        # Guard against empty/failed file generations (like the 20-byte postgres file)
        if [ "$comp" == "postgres.sql.gz" ] && [ "$SIZE" -lt 100000 ]; then
            AMISS=1
            ERRORS+=("Postgres backup is suspiciously small (${SIZE} bytes).")
        elif [ "$comp" == "redis.rdb.gz" ] && [ "$SIZE" -lt 10000 ]; then
            AMISS=1
            ERRORS+=("Redis backup is suspiciously small (${SIZE} bytes).")
        elif [ "$comp" == "config.tar.gz" ] && [ "$SIZE" -lt 100000 ]; then
            AMISS=1
            ERRORS+=("Config backup is suspiciously small (${SIZE} bytes).")
        fi
    fi
done

# 4. Handle results
if [ "$AMISS" -eq 1 ]; then
    # Flatten errors into a single string and direct to stderr
    ERROR_MSG=$(printf " | %s" "${ERRORS[@]}")
    echo "${ERROR_MSG:3}" >&2
    exit 1
fi

# Success
exit 0

