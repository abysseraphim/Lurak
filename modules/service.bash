#!/usr/bin/env bash

declare -a SERVICE_DISCOVERY_RESULTS


service_discovery() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ███████╗███████╗██████╗ ██╗   ██╗██╗ ██████╗███████╗                  
    ██╔════╝██╔════╝██╔══██╗██║   ██║██║██╔════╝██╔════╝                  
    ███████╗█████╗  ██████╔╝██║   ██║██║██║     █████╗                    
    ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║     ██╔══╝                    
    ███████║███████╗██║  ██║ ╚████╔╝ ██║╚██████╗███████╗                  
    ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝ ╚═════╝╚══════╝                  
                                                                          
    ██████╗ ██╗███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗
    ██╔══██╗██║██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝
    ██║  ██║██║███████╗██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝ 
    ██║  ██║██║╚════██║██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝  
    ██████╔╝██║███████║╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║   
    ╚═════╝ ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   
                                                                      

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool curl nc dig jq
    then
        printf "%b" "$RESET"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    print_info "[*] Checking CIDR result output file existence..."
    echo
    
    local file_name
    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        local safe_target="${TARGET//\//_}"
        file_name="$safe_target.cidr.portscan.result"
    else
        file_name="$TARGET.cidr.portscan.result"
    fi

    if [[ ! -f "$TARGET_DIR/$file_name" ]]; then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] This module requires output result of cidr port scanning."
        print_info "[!] CIDR scan file not found."
        printf "%b" "$BRIGHT_WHITE"
        print_info "[*] Run CIDR port scan first (option 4)."
        return 10
    fi

    print_info "[!] Target locked, starting service discovery..."
    echo

    mapfile -t sd_targets < <(jq -r '.results[]' "$TARGET_DIR/$file_name")

    local host
    for host in "${sd_targets[@]}"
    do
        local ip="${host%:*}" # bash expanstions are much cleaner than cut and ...
        local port="${host#*:}"

        discover_service "$ip" "$port"

    done

    local total=0
    local HTTP=0
    local SSH=0
    local HTTPS=0
    local FTP=0
    local SMTP=0
    local DB=0
    local RDP=0

    local discovered

    for discovered in "${SERVICE_DISCOVERY_RESULTS[@]}"
    do
        (( total++ ))
        IFS='|' read -r endpoint service info1 info2 <<< "$discovered"
        if [[ "$service" == "SSH" ]]
        then 
            (( SSH++ ))
        elif [[ "$service" == "HTTP" ]]
        then
            (( HTTP++ ))
        elif [[ "$service" == "HTTPS" ]]
        then
            (( HTTPS++ ))
        elif [[ "$service" == "FTP" ]]
        then 
            (( FTP++ ))
        elif [[ "$service" == "SMTP" ]]
        then 
            (( SMTP++ ))
        elif [[ "$service" =~ ^(MySQL|PostgreSQL|Redis|MongoDB)$ ]]
        then 
            (( DB++ ))
        elif [[ "$service" == "RDP" ]]
        then 
            (( RDP++ ))
        fi
    done

    echo
    print_info "[*] Quick summary:"
    echo

        printf "%b" "$BRIGHT_PURPLE"
        echo "    Servises:  $(printf "%b" "$BRIGHT_WHITE") $total $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    HTTP:      $(printf "%b" "$BRIGHT_WHITE") $HTTP $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    HTTPS:     $(printf "%b" "$BRIGHT_WHITE") $HTTPS $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    SSH:       $(printf "%b" "$BRIGHT_WHITE") $SSH $(printf "%b" "$RESET")"
        echo "    FTP:       $(printf "%b" "$BRIGHT_WHITE") $FTP $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    SMTP:      $(printf "%b" "$BRIGHT_WHITE") $SMTP $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    Database:  $(printf "%b" "$BRIGHT_WHITE") $DB $(printf "%b" "$BRIGHT_PURPLE")"
        echo "    RDP:       $(printf "%b" "$BRIGHT_WHITE") $RDP $(printf "%b" "$RESET")"
        printf "%b" "$RESET"

    echo

    local results_json=""
    for discovered in "${SERVICE_DISCOVERY_RESULTS[@]}"
    do
        IFS='|' read -r endpoint service info1 info2 <<< "$discovered"
        if [[ "$service" == "SSH" ]]
        then
            results_json+=$(printf '        {\n            "endpoint": "%s",\n            "service": "SSH",\n            "banner": "%s"\n        },' \
                "$endpoint" "$info1")
        else
            results_json+=$(printf '        {\n            "endpoint": "%s",\n            "service": "%s",\n            "status": "%s",\n            "server": "%s"\n        },' \
                "$endpoint" "$service" "$info1" "$info2")
        fi
        results_json+=$'\n'
    done
    
    local new_file_name
    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        local safe_target="${TARGET//\//_}"
        new_file_name="$safe_target.cidr.services.result"
    else
        new_file_name="$TARGET.cidr.services.result"
    fi

    print_info "[*] Saving results to: $TARGET_DIR/$new_file_name"
    echo

    results_json=$(printf "%s" "$results_json" | sed '$ s/,$//') # removing last comma from json
    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "http_services": $HTTP,
        "https_services": $HTTPS,
        "ssh_services": $SSH,
        "ftp_services": $FTP,
        "smtp_services": $SMTP,
        "db_services": $DB,
        "rdp_services": $RDP
    },
    "results": [
$results_json
    ]
}
EOF
    )
    
    save_output "$file_data" "$new_file_name"

    echo
    print_info "[*] Results saved."

}

discover_service() {
    local ip="$1"
    local port="$2"

    case "$port" in
        21)
            discover_ftp "$ip" "$port" 
            ;;
        22)
            discover_ssh "$ip" "$port" 
            ;;
        25|587)
            discover_smtp "$ip" "$port" 
            ;;
        80|8080|9090)
            discover_http "$ip" "$port" 
            ;;
        443|8443)
            discover_https "$ip" "$port" 
            ;;
        3306|5432|6379|27017)
            discover_db "$ip" "$port" 
            ;;
        3389)
            discover_rdp "$ip" "$port" 
            ;;
        *)
            : 
            ;;
    esac
}

discover_ssh() {

    local ip="$1"
    local port="$2"

    [[ "$port" != "22" ]] && return

    local banner
    banner=$(nc -nv -w 3 "$ip" "$port" 2>/dev/null | head -n1 | tr -d '\r\n') # do not resolve, use verbose mode, 3 seconds timeout, get line one (ssh banner), clean it

    [[ "$banner" != SSH-* ]] && return
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] $ip:$port -> $banner"
    printf "%b" "$BRIGHT_WHITE"

    SERVICE_DISCOVERY_RESULTS+=("$ip:$port|SSH|$banner")
}

discover_http() {

    local ip="$1"
    local port="$2"

    local headers
    headers=$(curl -sSI --max-time 3 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "http://$ip:$port") || return
    # silent mode, get headers and not body, 3 seconds timeout

    local status
    status=$(printf "%s\n" "$headers" | awk 'NR==1 {print $2}' | tr -d '\r\n') # NR==1 means first line of response

    local server
    server=$(printf "%s\n" "$headers" | awk -F': ' 'tolower($1)=="server" {print $2; exit}' | tr -d '\r\n') # search for server header and get its value, exit after first match
    [[ -z "$status" ]] && return
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] $ip:$port -> HTTP ($status) ${server:+[$server]}"
    printf "%b" "$BRIGHT_WHITE"

    SERVICE_DISCOVERY_RESULTS+=("$ip:$port|HTTP|$status|$server")
}

discover_https() {

    local ip="$1"
    local port="$2"

    local headers
    headers=$(curl -ksSI --max-time 3 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" "https://$ip:$port") || return

    local status
    status=$(printf "%s\n" "$headers" | awk 'NR==1 {print $2}' | tr -d '\r\n')

    local server
    server=$(printf "%s\n" "$headers" | awk -F': ' 'tolower($1)=="server" {print $2; exit}' | tr -d '\r\n')

    [[ -z "$status" ]] && return
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] $ip:$port -> HTTPS ($status) ${server:+[$server]}"
    printf "%b" "$BRIGHT_WHITE"

    SERVICE_DISCOVERY_RESULTS+=("$ip:$port|HTTPS|$status|$server")
}

discover_ftp() {
    local ip="$1"
    local port="$2"

    local banner
    banner=$(nc -nv -w 3 "$ip" "$port" 2>/dev/null | head -n1 | tr -d '\r\n')

    [[ "$banner" != 220* ]] && return
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] $ip:$port -> FTP | $banner"
    printf "%b" "$BRIGHT_WHITE"

    SERVICE_DISCOVERY_RESULTS+=("$ip:$port|FTP|$banner|")
}

discover_smtp() {
    local ip="$1"
    local port="$2"

    local banner
    banner=$(nc -nv -w 3 "$ip" "$port" 2>/dev/null | head -n1 | tr -d '\r\n')

    [[ "$banner" != 220* ]] && return
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] $ip:$port -> SMTP | $banner"
    printf "%b" "$BRIGHT_WHITE"

    SERVICE_DISCOVERY_RESULTS+=("$ip:$port|SMTP|$banner|")
}

discover_db() {
    local ip="$1"
    local port="$2"

    local service
    case "$port" in
        3306)
            service="MySQL" 
            ;;
        5432)
            service="PostgreSQL"
            ;;
        6379)
            service="Redis" 
            ;;
        27017)
            service="MongoDB"
            ;;
        *)
            return 
            ;;
    esac

    local result
    if result=$(nc -nv -w 3 "$ip" "$port" </dev/null 2>/dev/null | head -n1 | tr -d '\r\n') # some databases share no banner, so i decided that successful connection means there is something in there.
    then 
        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] $ip:$port -> $service ${result:+| $result}"
        printf "%b" "$BRIGHT_WHITE"
        SERVICE_DISCOVERY_RESULTS+=("$ip:$port|$service|$result|")
    fi
}

discover_rdp() {
    local ip="$1"
    local port="$2"

    if nc -nv -w 3 "$ip" "$port" </dev/null 2>/dev/null
    then
        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] $ip:$port -> RDP"
        printf "%b" "$BRIGHT_WHITE"
        SERVICE_DISCOVERY_RESULTS+=("$ip:$port|RDP||")
    fi
}

