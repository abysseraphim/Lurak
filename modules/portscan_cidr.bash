#!/usr/bin/env bash

cidr_port_scan() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


     ██████╗██╗██████╗ ██████╗                                              
    ██╔════╝██║██╔══██╗██╔══██╗                                             
    ██║     ██║██║  ██║██████╔╝                                             
    ██║     ██║██║  ██║██╔══██╗                                             
    ╚██████╗██║██████╔╝██║  ██║                                             
     ╚═════╝╚═╝╚═════╝ ╚═╝  ╚═╝                                             
                                                                            
    ██████╗  ██████╗ ██████╗ ████████╗    ███████╗ ██████╗ █████╗ ███╗   ██╗
    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝    ██╔════╝██╔════╝██╔══██╗████╗  ██║
    ██████╔╝██║   ██║██████╔╝   ██║       ███████╗██║     ███████║██╔██╗ ██║
    ██╔═══╝ ██║   ██║██╔══██╗   ██║       ╚════██║██║     ██╔══██║██║╚██╗██║
    ██║     ╚██████╔╝██║  ██║   ██║       ███████║╚██████╗██║  ██║██║ ╚████║
    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝       ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝
                                                                                   

EOF

    resolve_target_to_ip

    print_info "[*] Checking target ownership..."
    echo

    local owner_info
    owner_info=$(whois "$TARGET_IP" | awk -F': ' '
        /^OrgName:|^org-name:|^netname:|^owner:/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); if (!org) org=$2 }
        /^OrgAbuseEmail:|^abuse-mailbox:|^OrgTechEmail:/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); if (!email) email=$2 }
        /^CIDR:|^inetnum:|^route:/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); if (!range) range=$2 }
        END { print org "|" email "|" range }
    ')

    local owner_name email_addr range_info
    IFS='|' read -r owner_name email_addr range_info <<< "$owner_info"

    printf "%b" "$BRIGHT_WHITE"
    print_info "[*] Organization : ${owner_name:-Unknown}"
    print_info "[*] Abuse Email  : ${email_addr:-Unknown}"
    print_info "[*] Range        : ${range_info:-Unknown}"
    printf "%b" "$BRIGHT_PURPLE"

    printf "%b" "$BRIGHT_YELLOW"
    read -rp "    Is this your target? [y/N] > " confirm
    printf "%b" "$BRIGHT_WHITE"

    if [[ "${confirm,,}" != "y" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Scan aborted."
        printf "%b" "$BRIGHT_WHITE"
        return 10
    fi

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool naabu dig whois
    then
        printf "%b" "$BRIGHT_WHITE"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        TARGET_CIDR="$TARGET"
    else
        if ! resolve_target_to_ip
        then
            print_info "[!] IP cannot be resolved."
            return 4
        fi

        print_info "[*] Trying to find target CIDR..."

        TARGET_CIDR=$(whois "$TARGET_IP" | awk '/route:|route6:|CIDR:|origin:/ {print $2; exit}' | xargs)

        if [[ -z "$TARGET_CIDR" ]]
        then
            TARGET_CIDR=$(whois "$TARGET_IP" |
                awk -F: '/^CIDR:/ {print $2; exit}' |
                xargs)
        fi

        if [[ -z "$TARGET_CIDR" ]]
        then
            print_info "[!] CIDR was not found."
            return 6
        fi
    fi


    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Port Range ━━━━━━━━━━━━━━━━━━━━━━━

    [1]  All ports (1-65535)
    [2]  Common ports (top 100)
    [3]  Custom range
    [4]  Manual list (comma separated)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Port Range > " CIDR_SCAN_PORT
    printf "%b" "$BRIGHT_WHITE"

    local port_flag
    case "$CIDR_SCAN_PORT" in
        1) port_flag="-p -" 
            ;;
        2) port_flag="" 
            ;;
        3)
            printf "%b" "$BRIGHT_YELLOW"
            read -rp "    Range (e.g. 20-100) > " port_arg
            printf "%b" "$BRIGHT_WHITE"
            port_flag="-p $port_arg"
            ;;
        4)
            printf "%b" "$BRIGHT_YELLOW"
            read -rp "    Ports (e.g. 22,80,443) > " port_arg
            printf "%b" "$BRIGHT_WHITE"
            port_flag="-p $port_arg"
            ;;
        *)
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Invalid option."
            printf "%b" "$BRIGHT_WHITE"
            return 7
            ;;
    esac

    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━ Scan Rate ━━━━━━━━━━━━━━

    [1] Slow    (100 pps)
    [2] Normal  (500 pps)
    [3] Fast    (1000 pps)
    [4] Custom

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Scan Rate > " CIDR_SCAN_RATE
    printf "%b" "$BRIGHT_WHITE"

    local rate_flag
    case "$CIDR_SCAN_RATE" in
    1) rate_flag=100
        ;;
    2) rate_flag=500
        ;;
    3) rate_flag=1000
        ;;
    4)
        printf "%b" "$BRIGHT_YELLOW"
        local scan_arg
        read -rp "    Rate (e.g. 600) > " scan_arg
        printf "%b" "$BRIGHT_WHITE"
        rate_flag="$scan_arg"
        ;;
    *)
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Invalid option."
        printf "%b" "$BRIGHT_WHITE"
        return 7
        ;;
    esac

    print_info "[*] Starting naabu port scan on: $TARGET_CIDR"

    naabu \
    -host "$TARGET_CIDR" \
    -rate "$rate_flag" \
    -retries 1 \
    -timeout 3000 \
    $port_flag \
    -silent > /tmp/naabu_tmp_output &
    local naabu_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $naabu_pid"
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$naabu_pid"
    wait "$naabu_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Scan failed."
        printf "%b" "$BRIGHT_WHITE"

        rm -f /tmp/naabu_tmp_output
        return 8
    fi

    echo
    print_info "[*] Scan completed."
    echo
    print_info "[*] Parsing scan results..."
    echo

    if [[ ! -s /tmp/naabu_tmp_output ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No results returned from scan."
        printf "%b" "$BRIGHT_WHITE"

        save_output "{}" "$TARGET.cidr.portscan.result"
        rm -f /tmp/naabu_tmp_output
        return 0
    fi

    local results
    results=$(awk '{print $1}' /tmp/naabu_tmp_output | sort -u)

    local open_count
    open_count=$(printf "%s\n" "$results" | wc -l)

    local host_count
    host_count=$(printf "%s\n" "$results" | cut -d: -f1 | sort -u | wc -l)

    local port_count
    port_count=$(printf "%s\n" "$results" | cut -d: -f2 | sort -u | wc -l)

    echo
    print_info "[+] Scan Summary:"
    print_info "    - Open services : $open_count"
    print_info "    - Unique hosts  : $host_count"
    print_info "    - Unique ports  : $port_count"
    echo

    printf "%b" "$BRIGHT_GREEN"

    printf "%s\n" "$results" | awk '{print "    " $0}'

    printf "%b" "$BRIGHT_WHITE"

    local file_name
    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        local safe_target="${TARGET//\//_}"
        file_name="$safe_target.cidr.portscan.result"
    else
        file_name="$TARGET.cidr.portscan.result"
    fi

    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "cidr": "$TARGET_CIDR",
    "summary": {
        "open_services": $open_count,
        "unique_hosts": $host_count,
        "unique_ports": $port_count
    },
    "results": [
$(printf '%s\n' "$results" | awk '{print "        \"" $0 "\"" (NR==total ? "" : ",")}' total=$(printf '%s\n' "$results" | wc -l))
    ]
}
EOF
    )
    
    save_output "$file_data" "$file_name"

    echo
    print_info "[*] Results saved."

    rm -f /tmp/naabu_tmp_output

    printf "%b" "$RESET"
}

