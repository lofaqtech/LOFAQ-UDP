#!/bin/bash

CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="$CONFIG_DIR/config.json"
SYSTEMD_SERVICE="/etc/systemd/system/hysteria-server.service"

mkdir -p "$CONFIG_DIR"

fetch_users() {
    local today_epoch
    today_epoch=$(date +%s)
    local users=""
    
    # Filter users with UID >= 1000 (non-system)
    while IFS=: read -r username _ uid _ _ _ _; do
        if (( uid >= 1000 && uid < 60000 )); then
            # Get expiry date in YYYY-MM-DD from chage
            expiry=$(sudo chage -l "$username" | grep "Account expires" | cut -d: -f2- | xargs)
            if [[ "$expiry" == "never" || -z "$expiry" ]]; then
                users+="${username},"
            else
                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
                if [[ "$expiry_epoch" -ge "$today_epoch" ]]; then
                    users+="${username},"
                fi
            fi
        fi
    done < /etc/passwd

    # Remove trailing comma
    echo "${users%,}"
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
    read -s -r password
    echo -e "\e[1;34mEnter account duration in days:\e[0m"
    read -r days

    expiry_date=$(date -d "+$days days" +%s)
    sudo useradd -m "$username"
    echo "$username:$password" | sudo chpasswd

    sudo chage -E "$expiry_date" "$username"
    echo -e "\e[1;32mUser $username added. Expires on $(date -d @$expiry_date).\e[0m"
    restart_server
}

edit_user() {
    echo -e "\n\e[1;34mEnter username to edit:\e[0m"
    read -r username
    echo -e "\e[1;34mEnter new password:\e[0m"
    read -s -r password
    echo "$username:$password" | sudo chpasswd

    echo -e "\e[1;34mEnter new duration (in days):\e[0m"
    read -r days
    expiry_date=$(date -d "+$days days" +%s)
    sudo chage -E "$expiry_date" "$username"
    echo -e "\e[1;32mUser $username updated successfully. New expiry: $(date -d @$expiry_date)\e[0m"
    restart_server
}

delete_user() {
    echo -e "\n\e[1;34mEnter username to delete:\e[0m"
    read -r username
    sudo userdel -r "$username"
    echo -e "\e[1;32mUser $username deleted.\e[0m"
    restart_server
}

show_users() {
    echo -e "\n\e[1;34mSystem Users with Expiry:\e[0m"
    printf "%-20s %-20s\n" "Username" "Account Expiry"
    echo "----------------------------------------"

    getent passwd {1000..60000} | cut -d: -f1 | while read -r user; do
        expiry=$(sudo chage -l "$user" | grep "Account expires" | cut -d: -f2 | xargs)
        printf "%-20s %-20s\n" "$user" "$expiry"
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
