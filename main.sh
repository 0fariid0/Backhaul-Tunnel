
You said:

DVHOST_CLOUD_TUNNEL(){
    clear
    DVHOST_CLOUD_menu "| 1  - IRAN \n| 2  - KHAREJ  \n| 0  - Exit"
    read -p "Enter your choice: " choice
    
    case $choice in
        1)

            echo "Please choose a protocol (tcp, ws, or tcpmux):"
            read protocol

            if [[ "$protocol" == "tcp" ]]; then
                result="tcp"
            elif [[ "$protocol" == "ws" ]]; then
                result="ws"
            elif [[ "$protocol" == "tcpmux" ]]; then
                result="tcpmux"
            else
                result="Invalid choice. Please choose between tcp, ws, or tcpmux."
            fi

            read -p "Enter Port Tunnel : " port_tunnel
            read -p "Enter Token : " token
            read -p "Do you want nodelay (true/false) ? " nodelay

			read -p "How many port mappings do you want to add?" port_count



ports=$(IRAN_PORTS "$port_count")

cat <<EOL > config.toml
[server]# Local, IRAN
bind_addr = "0.0.0.0:${port_tunnel}"
transport = "${protocol}"
token = "${token}"
nodelay = ${nodelay}
keepalive_period = 20
channel_size = 2048
connection_pool = 16
mux_session = 1
log_level = "info"
${ports}
EOL

        # backhaul -c config.toml
        create_backhaul_service
        ;;
        2)

            echo "Please choose a protocol (tcp, ws, or tcpmux):"
            read protocol

            if [[ "$protocol" == "tcp" ]]; then
                result="tcp"
            elif [[ "$protocol" == "ws" ]]; then
                result="ws"
            elif [[ "$protocol" == "tcpmux" ]]; then
                result="tcpmux"
            else
                result="Invalid choice. Please choose between tcp, ws, or tcpmux."
            fi
            read -p "Enter Port Tunnel : " port_tunnel
            read -p "Enter Token : " token
            read -p "Do you want nodelay (true/false) ? " nodelay
			read -p "Please enter Remote IP : " remote_ip

cat <<EOL > config.toml
[client]
remote_addr = "${remote_ip}:${port_tunnel}"
transport = "${protocol}"
token = "${token}"
nodelay = ${nodelay}
keepalive_period = 20
retry_interval = 1
log_level = "info"
mux_session = 1
EOL


        create_backhaul_service

        ;;
        0)
            echo -e "${GREEN}Exiting program...${NC}"
            exit 0
        ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press any key to continue..."
        ;;
    esac
}
