#!/bin/bash

# رنگ‌ها برای خروجی
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # بدون رنگ

# بررسی دسترسی root
[[ $EUID -ne 0 ]] && echo -e "${RED}Fatal error: ${NC} لطفا این اسکریپت را با دسترسی root اجرا کنید \n" && exit 1

# نصب jq در صورت نیاز
DVHOST_CLOUD_install_jq() {
    if ! command -v jq &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq نصب نشده است. در حال نصب...${NC}"
            sleep 1
            apt-get update
            apt-get install -y jq
        else
            echo -e "${RED}خطا: مدیر بسته پشتیبانی نمی‌شود. لطفا jq را دستی نصب کنید.${NC}\n"
            read -p "برای ادامه کلیدی فشار دهید..."
            exit 1
        fi
    fi
}

# نصب pv در صورت نیاز
DVHOST_CLOUD_require_command(){
    DVHOST_CLOUD_install_jq
    if ! command -v pv &> /dev/null; then
        echo "pv یافت نشد، در حال نصب..."
        apt update
        apt install -y pv
    fi
}

# منوی اصلی
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
    echo -e "|${GREEN}کشور سرور        |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}آی‌پی سرور       |${NC} $SERVER_IP"
    echo -e "|${GREEN}ISP سرور        |${NC} $SERVER_ISP"
    echo -e "|${GREEN}Core Backhaul    |${NC} $BACK_CORE"
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e "|${YELLOW}لطفا یک گزینه را انتخاب کنید:${NC}"
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e $1
    echo "+--------------------------------------------------------------------------------------------------------------------------------------+"                                                                                                
    echo -e "\033[0m"
}

# برنامه اصلی
DVHOST_CLOUD_MAIN(){
    clear
    DVHOST_CLOUD_menu "| 1  - نصب Backhaul Core \n| 2  - تنظیم تونل \n| 3  - حذف \n| 0  - خروج"
    read -p "لطفا گزینه خود را وارد کنید: " choice
    
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
            echo -e "${GREEN}حذف موفقیت‌آمیز بود.${NC}"
        ;;
        0)
            echo -e "${GREEN}خروج از برنامه...${NC}"
            exit 0
        ;;
        *)
            echo "انتخاب نامعتبر. لطفا دوباره امتحان کنید."
            read -p "برای ادامه کلیدی فشار دهید..."
            DVHOST_CLOUD_MAIN
        ;;
    esac
}

# نصب و دانلود هسته Backhaul
DVHOST_CLOUD_BACKCORE(){
    ## دانلود از گیت‌هاب
    wget https://github.com/Musixal/Backhaul/releases/download/v0.1.1/backhaul_linux_amd64.tar.gz

    # تنظیم دسترسی فایل
    chmod +x backhaul

    # استخراج فایل
    tar -xzvf backhaul_linux_amd64.tar.gz

    # جابجایی فایل
    mv backhaul /usr/bin/backhaul
    
    # پاک کردن صفحه
    clear

    echo $'\e[32m شروع Backhaul Core در 3 ثانیه... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1 && {
        DVHOST_CLOUD_MAIN
    }
}

# بررسی وضعیت نصب
DVHOST_CLOUD_check_status() {
    if [ -e /usr/bin/backhaul ]; then
        echo -e ${GREEN}"نصب شده"${NC}
    else
        echo -e ${RED}"نصب نشده"${NC}
    fi
}

# تنظیم تونل
DVHOST_CLOUD_TUNNEL(){
    clear
    DVHOST_CLOUD_menu "| 1  - ایران \n| 2  - خارج  \n| 0  - خروج"
    read -p "لطفا گزینه خود را انتخاب کنید: " choice
    
    case $choice in
        1 | 2)
            echo "لطفا پروتکل را انتخاب کنید (tcp, ws, یا tcpmux):"
            read protocol

            if [[ "$protocol" == "tcp" ]] || [[ "$protocol" == "ws" ]] || [[ "$protocol" == "tcpmux" ]]; then
                result=$protocol
            else
                echo "انتخاب نامعتبر. لطفا بین tcp, ws, یا tcpmux انتخاب کنید."
                read -p "برای ادامه کلیدی فشار دهید..."
                DVHOST_CLOUD_TUNNEL
            fi

            read -p "لطفا توکن را وارد کنید: " token
            read -p "آیا nodelay می‌خواهید؟ (true/false): " nodelay

            # دریافت تعداد سرورهای مقصد
            read -p "چند مقصد می‌خواهید تنظیم کنید؟ " destination_count

            # ساخت تنظیمات برای هر سرور مقصد
            for ((i=1; i<=$destination_count; i++))
            do
                read -p "لطفا IP مقصد $i را وارد کنید: " remote_ip

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

            # اجرای سرویس
            create_backhaul_service
        ;;
        0)
            echo -e "${GREEN}خروج از برنامه...${NC}"
            exit 0
        ;;
        *)
            echo "انتخاب نامعتبر. لطفا دوباره امتحان کنید."
            read -p "برای ادامه کلیدی فشار دهید..."
            DVHOST_CLOUD_TUNNEL
        ;;
    esac
}

# ایجاد سرویس backhaul
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

    # بارگذاری مجدد دیمون systemd
    systemctl daemon-reload

    # فعال و شروع سرویس
    systemctl enable backhaul.service
    systemctl start backhaul.service

    echo -e "${GREEN}سرویس backhaul ایجاد و شروع شد.${NC}"
}

# اطمینان از نصب jq و pv
DVHOST_CLOUD_require_command

# شروع منوی اصلی
DVHOST_CLOUD_MAIN
