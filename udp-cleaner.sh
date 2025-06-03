#!/bin/bash

# Path to the user database
USER_DB="/etc/hysteria/udpusers.db"

# Ensure the DB file exists
if [[ ! -f "$USER_DB" ]]; then
    echo "User database not found at $USER_DB"
    exit 1
fi

# Get today's date in YYYY-MM-DD format
today=$(date +"%Y-%m-%d")

# Remove expired users
sqlite3 "$USER_DB" "DELETE FROM users WHERE expiry < '$today';"
