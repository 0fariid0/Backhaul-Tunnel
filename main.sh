#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${NC} Please run this script as root\n" && exit 1

DVHOST_CLOUD_install_jq() {
    if ! command -v jq &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            apt-get update
            apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

DVHOST_CLOUD_require_command(){
    DVHOST_CLOUD_install_jq
    if ! command -v pv &> /dev/null; then
        echo "pv not found, installing it..."
        apt update
        apt install -y pv
    fi
}

DVHOST_CLOUD_menu(){
    clear
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')
    BACK_CORE=$(DVHOST_CLOUD_check_status)
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo "| ######     ###      ####   ### ###   ##  ##    ###    ##   ##  ####      ######  ##   ##  ##   ##  ##   ##  #######  ####            |"
    echo "|  ##  ##   ## ##    ##  ##   ## ##    ##  ##   ## ##   ##   ##   ##      #### ##  ##   ##  ###  ##  ###  ##   ##   #   ##             |"
    echo "|  ##  ##  ##   ##  ##        ####     ##  ##  ##   ##  ##   ##   ##         ##    ##   ##  #### ##  #### ##   ##       ##             |"
    echo "|  #####   ##   ##  ##        ###      ######  ##   ##  ##   ##   ##         ##    ##   ##  #######  #######   ####     ##             |"
    echo "|  ##  ##  #######  ##        ####     ##  ##  #######  ##   ##   ##         ##    ##   ##  ## ####  ## ####   ##       ##             |"
    echo "|  ##  ##  ##   ##   ##  ##   ## ##    ##  ##  ##   ##  ##   ##   ##  ##     ##    ##   ##  ##  ###  ##  ###   ##   #   ##  ##         |"
    echo "| ######   ##   ##    ####   ### ###   ##  ##  ##   ##   #####   #######    ####    #####   ##   ##  ##   ##  #######  ####### ( 0.4 ) |"
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo -e "|${GREEN}Backhaul Core     |${NC} $BACK_CORE"
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e "|${YELLOW}Please choose an option:${NC}"
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e $1
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e "\033[0m"
}

DVHOST_CLOUD_MAIN(){
    clear
    DVHOST_CLOUD_menu "| 1  - Install Backhaul Core \n| 2  - Setup Tunnel \n| 3  - Uninstall \n| 4  - Remove Completely \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            DVHOST_CLOUD_BACKCORE
        ;;
        2)
            DVHOST_CLOUD_TUNNEL
        ;;
        3)
            rm -rf backhaul config.toml /etc/systemd/system/backhaul.service
            systemctl daemon-reload
            echo -e "${GREEN}Uninstallation successful.${NC}"
        ;;
        4)
            DVHOST_CLOUD_REMOVE_COMPLETELY
        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
            DVHOST_CLOUD_MAIN
        ;;
    esac
}

DVHOST_CLOUD_BACKCORE(){
    wget https://github.com/Musixal/Backhaul/releases/download/v0.1.1/backhaul_linux_amd64.tar.gz
    chmod +x backhaul
    tar -xzvf backhaul_linux_amd64.tar.gz
    mv backhaul /usr/bin/backhaul
    clear
    echo $'\e[32m Starting Backhaul Core in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
        DVHOST_CLOUD_MAIN
    }
}

DVHOST_CLOUD_check_status() {
    if [ -e /usr/bin/backhaul ]; then
        echo -e ${GREEN}"Installed"${NC}
    else
        echo -e ${RED}"Not Installed"${NC}
    fi
}

DVHOST_CLOUD_TUNNEL(){
    clear
    DVHOST_CLOUD_menu "| 1  - IRAN \n| 2  - OUTSIDE \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1 | 2)
            echo "Please choose a protocol (tcp, ws, or tcpmux):"
            read protocol

            if [[ "$protocol" == "tcp" ]] || [[ "$protocol" == "ws" ]] || [[ "$protocol" == "tcpmux" ]]; then
                result=$protocol
            else
                echo "Invalid choice. Please choose between tcp, ws, or tcpmux."
                read -p "Press any key to continue..."
                DVHOST_CLOUD_TUNNEL
            fi

            read -p "Enter Token: " token
            read -p "Do you want nodelay? (true/false): " nodelay
            read -p "How many destinations do you want to configure? " destination_count

            for ((i=1; i<=$destination_count; i++))
            do
                read -p "Enter IP for destination $i: " remote_ip

                cat <<EOL >> config.toml
[client_$i]
remote_addr = "${remote_ip}:3080"
transport = "${protocol}"
token = "${token}"
nodelay = ${nodelay}
keepalive_period = 20
retry_interval = 1
log_level = "info"
mux_session = 1

EOL
            done

            create_backhaul_service
        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
            DVHOST_CLOUD_TUNNEL
        ;;
    esac
}

create_backhaul_service() {
    service_file="/etc/systemd/system/backhaul.service"

    echo "[Unit]" > "$service_file"
    echo "Description=Backhaul Reverse Tunnel Service" >> "$service_file"
    echo "After=network.target" >> "$service_file"
    echo "" >> "$service_file"
    echo "[Service]" >> "$service_file"
    echo "Type=simple" >> "$service_file"
    echo "ExecStart=/usr/bin/backhaul -c /root/config.toml" >> "$service_file"
    echo "Restart=always" >> "$service_file"
    echo "RestartSec=3" >> "$service_file"
    echo "LimitNOFILE=1048576" >> "$service_file"
    echo "" >> "$service_file"
    echo "[Install]" >> "$service_file"
    echo "WantedBy=multi-user.target" >> "$service_file"

    systemctl daemon-reload
    systemctl enable backhaul.service
    systemctl start backhaul.service

    echo -e "${GREEN}backhaul.service created and started.${NC}"
}

DVHOST_CLOUD_REMOVE_COMPLETELY() {
    echo "Removing backhaul, configuration, and all related files..."
    systemctl stop backhaul.service
    systemctl disable backhaul.service
    rm -rf /usr/bin/backhaul /root/config.toml /etc/systemd/system/backhaul.service
    systemctl daemon-reload
    echo -e "${GREEN}All files and services related to Backhaul have been completely removed.${NC}"
}

DVHOST_CLOUD_require_command
DVHOST_CLOUD_MAIN
