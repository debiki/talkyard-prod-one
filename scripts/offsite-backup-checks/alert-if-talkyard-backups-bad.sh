#!/bin/bash

# Configuration
CHECKER_SCRIPT="/root/check_backups.sh"
TARGET_DIR="/root/tyc-backups"
API_URL="http://mail-api.example.com"
TODAY=$(date +%Y-%m-%d)

# Execute checker, send stdout to the void, and capture stderr into a variable
ERROR_PAYLOAD=$("$CHECKER_SCRIPT" "$TARGET_DIR" 2>&1 >/dev/null)
STATUS=$?

# If the script failed with exit code 1 (or any error code)
if [ "$STATUS" -ne 0 ]; then
    
    # If the payload came back empty for some reason, use a fallback message
    if [ -z "$ERROR_PAYLOAD" ]; then
        ERROR_PAYLOAD="Backup check failed with exit code ${STATUS} without explicit output."
    fi

    # Trigger the curl notification alert
    curl -s -X POST \
         -H "Content-Type: application/json" \
         -d "{\"alert\": \"Backup Failure\", \"date\": \"$TODAY\", \"issues\": \"$ERROR_PAYLOAD\"}" \
         "$API_URL"
fi

