#!/bin/bash

# This script deletes Linux system users with expired accounts
# Only targets users with UID >= 1000 (typically non-system accounts)

for user in $(getent passwd {1000..60000} | cut -d: -f1); do
    # Get the expiry date from chage
    expiry=$(chage -l "$user" | awk -F: '/Account expires/ {print $2}' | xargs)

    # Skip users with no expiry set
    [[ -z "$expiry" || "$expiry" == "never" ]] && continue

    # Convert expiry to epoch
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null) || continue
    now_epoch=$(date +%s)

    if (( expiry_epoch < now_epoch )); then
        echo "Deleting expired user: $user"

        # Remove user cron jobs
        crontab -r -u "$user" 2>/dev/null || true

        # Clean up at jobs owned by the user
        find /var/spool/cron/atjobs -user "$user" -delete 2>/dev/null || true

        # Delete the user and their home directory
        userdel -r "$user"

        echo "User $user deleted."
    fi
done