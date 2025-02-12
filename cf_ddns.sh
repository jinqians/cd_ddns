#!/bin/bash

# author: jinqian 
# 网站: jinqians.com

echo -e "\033[1;31m author:\033[0m \033[1;32m jinqian \033[0m"
echo -e "\033[1;31m website:\033[0m \033[1;32m https://jinqians.com \033[0m"



# Function to log messages
log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $log_file
    fi
}

# Configuration file
config_file="cloudflare_config.txt"

# Function to load configuration
load_config() {
    if [ -f $config_file ]; then
        source $config_file
    else
        echo "Configuration file not found. Please run the script manually to configure."
        exit 1
    fi
}

# Function to save configuration
save_config() {
    cat <<EOL > $config_file
auth_email="$auth_email"
auth_key="$auth_key"
zone_name="$zone_name"
record_name="$record_name"
ip_type="$ip_type"
EOL
}

# Check if configuration file exists
if [ ! -f $config_file ]; then
    # Get user inputs
    read -p "Enter Cloudflare Auth Email: " auth_email
    read -p "Enter Cloudflare Auth Key: " auth_key
    read -p "Enter Zone Name (e.g., example.com): " zone_name
    read -p "Enter Record Name (e.g., www.example.com): " record_name

    # User chooses between IPv4 and IPv6
    echo "Choose IP type to update:"
    echo "1) IPv4"
    echo "2) IPv6"
    read -p "Enter choice [1 or 2]: " ip_choice

    if [ "$ip_choice" != "1" ] && [ "$ip_choice" != "2" ]; then
        echo "Invalid choice."
        exit 1
    fi

    if [ "$ip_choice" == "1" ]; then
        ip_type="A"
    else
        ip_type="AAAA"
    fi

    # Save configuration
    save_config
else
    # Load configuration
    load_config
fi

# Get current IP
if [ "$ip_type" == "A" ]; then
    ip=$(curl -s4 https://api.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$ip" ]; then
        echo -e "${GREEN}$ip${NC}"
    else
        # 备用IPv4获取方法
        ip=$(curl -s4 https://ip.gs)
        if [ $? -eq 0 ] && [ ! -z "$ip" ]; then
            echo -e "${GREEN}$ip${NC}"
        else
            echo -e "${RED}无法获取IPv4地址${NC}"
        fi
    fi
else
    ip=$(curl -s6 https://api64.ipify.org)
    if [ $? -eq 0 ] && [ ! -z "$ip" ]; then
        echo -e "${GREEN}$ip${NC}"
    else
        # 备用IPv6获取方法
        ip=$(curl -s6 https://ip.gs)
        if [ $? -eq 0 ] && [ ! -z "$ip" ]; then
            echo -e "${GREEN}$ip${NC}"
        else
            echo -e "${RED}无法获取IPv6地址或服务器不支持IPv6${NC}"
        fi
    fi
fi

# Define file paths
ip_file="ip.txt"
id_file="cloudflare.ids"
log_file="cloudflare.log"

# Start logging
log "Check Initiated"

# Check if IP has changed
if [ -f $ip_file ]; then
    old_ip=$(cat $ip_file)
    if [ "$ip" == "$old_ip" ]; then
        echo "IP has not changed."
        exit 0
    fi
fi

# Get zone and record identifiers
if [ -f $id_file ] && [ $(wc -l < $id_file) -eq 2 ]; then
    zone_identifier=$(head -1 $id_file)
    record_identifier=$(tail -1 $id_file)
else
    zone_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
                        -H "X-Auth-Email: $auth_email" \
                        -H "X-Auth-Key: $auth_key" \
                        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)
    record_identifier=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" \
                          -H "X-Auth-Email: $auth_email" \
                          -H "X-Auth-Key: $auth_key" \
                          -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')
    echo "$zone_identifier" > $id_file
    echo "$record_identifier" >> $id_file
fi

# Update DNS record
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                -H "X-Auth-Email: $auth_email" \
                -H "X-Auth-Key: $auth_key" \
                -H "Content-Type: application/json" \
                --data "{\"id\":\"$zone_identifier\",\"type\":\"$ip_type\",\"name\":\"$record_name\",\"content\":\"$ip\"}")

# Check update result
if [[ $update == *"\"success\":false"* ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    log "$message"
    echo -e "$message"
    exit 1
else
    message="IP changed to: $ip"
    echo "$ip" > $ip_file
    log "$message"
    echo "$message"
fi
