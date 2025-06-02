#!/bin/bash

CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="$CONFIG_DIR/config.json"
USER_DB="$CONFIG_DIR/udpusers.db"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria-server.service"

mkdir -p "$CONFIG_DIR"
touch "$USER_DB"

fetch_users() {
    if [[ -f "$USER_DB" ]]; then
        sqlite3 "$USER_DB" "SELECT username || ':' || password FROM users;" | paste -sd, -
    fi
}

update_userpass_config() {
    local users=$(fetch_users)
    local user_array=$(echo "$users" | awk -F, '{for(i=1;i<=NF;i++) printf "\"" $i "\"" ((i==NF) ? "" : ",")}')
    jq ".auth.config = [$user_array]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

add_user() {
    echo -e "\n\e[1;34mEnter username:\e[0m"
    read -r username
    echo -e "\e[1;34mEnter password:\e[0m"
    read -r password
    echo -e "\e[1;34mEnter account duration in days:\e[0m"
    read -r days
    expiry_date=$(date -d "+$days days" +"%Y-%m-%d")
    sqlite3 "$USER_DB" "INSERT INTO users (username, password, expiry) VALUES ('$username', '$password', '$expiry_date');"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username added. Expires on $expiry_date.\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to add user $username.\e[0m"
    fi
}

edit_user() {
    echo -e "\n\e[1;34mEnter username to edit:\e[0m"
    read -r username
    echo -e "\e[1;34mEnter new password:\e[0m"
    read -r password
    echo -e "\e[1;34mEnter new duration (in days from today):\e[0m"
    read -r duration

    expiry=$(date -d "+$duration days" +"%Y-%m-%d")

    sqlite3 "$USER_DB" "UPDATE users SET password = '$password', expiry = '$expiry' WHERE username = '$username';"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username updated successfully (expires: $expiry).\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to update user $username.\e[0m"
    fi
}

delete_user() {
    echo -e "\n\e[1;34mEnter username to delete:\e[0m"
    read -r username
    sqlite3 "$USER_DB" "DELETE FROM users WHERE username = '$username';"
    if [[ $? -eq 0 ]]; then
        echo -e "\e[1;32mUser $username deleted successfully.\e[0m"
        update_userpass_config
        restart_server
    else
        echo -e "\e[1;31mError: Failed to delete user $username.\e[0m"
    fi
}

show_users() {
    echo -e "\n\e[1;34mCurrent users and expiry:\e[0m"
    printf "%-20s %-20s %-15s %-10s\n" "Username" "Password" "Expiry Date" "Days Left"
    echo "--------------------------------------------------------------------------"
    sqlite3 "$USER_DB" "SELECT username, password, IFNULL(expiry, 'N/A') FROM users;" | while IFS='|' read -r user pass expiry; do
        if [[ "$expiry" != "N/A" ]]; then
            today_epoch=$(date +%s)
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            if [[ $? -eq 0 && $expiry_epoch -ge $today_epoch ]]; then
                days_left=$(( (expiry_epoch - today_epoch) / 86400 ))
            else
                days_left="Expired"
            fi
        else
            days_left="N/A"
        fi
        printf "%-20s %-20s %-15s %-10s\n" "$user" "$pass" "$expiry" "$days_left"
    done
}

change_domain() {
    echo -e "\n\e[1;34mEnter new domain:\e[0m"
    read -r domain
    jq ".server = \"$domain\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mDomain changed to $domain successfully.\e[0m"
    restart_server
}

change_obfs() {
    echo -e "\n\e[1;34mEnter new obfuscation string:\e[0m"
    read -r obfs
    jq ".obfs.password = \"$obfs\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mObfuscation string changed to $obfs successfully.\e[0m"
    restart_server
}

change_up_speed() {
    echo -e "\n\e[1;34mEnter new upload speed (Mbps):\e[0m"
    read -r up_speed
    jq ".up_mbps = $up_speed" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    jq ".up = \"$up_speed Mbps\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mUpload speed changed to $up_speed Mbps successfully.\e[0m"
    restart_server
}

change_down_speed() {
    echo -e "\n\e[1;34mEnter new download speed (Mbps):\e[0m"
    read -r down_speed
    jq ".down_mbps = $down_speed" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    jq ".down = \"$down_speed Mbps\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "\e[1;32mDownload speed changed to $down_speed Mbps successfully.\e[0m"
    restart_server
}

restart_server() {
    systemctl restart hysteria-server
    echo -e "\e[1;32mServer restarted successfully.\e[0m"
}

uninstall_server() {
    echo -e "\n\e[1;34mUninstalling LOFAQ™ UDP Manager...\e[0m"
    systemctl stop hysteria-server
    systemctl disable hysteria-server
    rm -f "$SYSTEMD_SERVICE"
    systemctl daemon-reload
    rm -rf "$CONFIG_DIR"
    rm -f /usr/local/bin/hysteria
    echo -e "\e[1;32mLOFAQ™ UDP Manager uninstalled successfully.\e[0m"
}

show_banner() {
    echo -e "\e[1;36m---------------------------------------------"
    echo " LOFAQ™ UDP Manager"
    echo " (c) 2025 LOFAQ™"
    echo " Telegram: @lofaqvps"
    echo " Website: vps.lofaq.com/scripts"
    echo "---------------------------------------------\e[0m"
}

show_menu() {
    echo -e "\e[1;36m----------------------------"
    echo " LOFAQ™ UDP Manager"
    echo -e "----------------------------\e[0m"
    echo -e "\e[1;32m1. Add new user"
    echo "2. Edit user password"
    echo "3. Delete user"
    echo "4. Show users"
    echo "5. Change domain"
    echo "6. Change obfuscation string"
    echo "7. Change upload speed"
    echo "8. Change download speed"
    echo "9. Restart server"
    echo "10. Uninstall server"
    echo -e "11. Exit\e[0m"
    echo -e "\e[1;36m----------------------------"
    echo -e "Enter your choice: \e[0m"
}

show_banner
while true; do
    show_menu
    read -r choice
    case $choice in
        1) add_user ;;
        2) edit_user ;;
        3) delete_user ;;
        4) show_users ;;
        5) change_domain ;;
        6) change_obfs ;;
        7) change_up_speed ;;
        8) change_down_speed ;;
        9) restart_server ;;
        10) uninstall_server; exit 0 ;;
        11) exit 0 ;;
        *) echo -e "\e[1;31mInvalid choice. Please try again.\e[0m" ;;
    esac
done
