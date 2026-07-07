#!/usr/bin/env bash

ip_port_scan() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ██╗██████╗     ██████╗  ██████╗ ██████╗ ████████╗    ███████╗ ██████╗ █████╗ ███╗   ██╗
    ██║██╔══██╗    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝    ██╔════╝██╔════╝██╔══██╗████╗  ██║
    ██║██████╔╝    ██████╔╝██║   ██║██████╔╝   ██║       ███████╗██║     ███████║██╔██╗ ██║
    ██║██╔═══╝     ██╔═══╝ ██║   ██║██╔══██╗   ██║       ╚════██║██║     ██╔══██║██║╚██╗██║
    ██║██║         ██║     ╚██████╔╝██║  ██║   ██║       ███████║╚██████╗██║  ██║██║ ╚████║
    ╚═╝╚═╝         ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝       ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝
                                                                                       

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool nmap dig
    then
        printf "%b" "$RESET"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        print_info "[!] Target type is CIDR, use option 4 (CIDR port scan)"
        return 4
    fi

    if ! resolve_target_to_ip # here another global variable will be declared : TARGET_IP
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] IP cannot be resolved."
        printf "%b" "$RESET"
        return 4
    fi

    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Port Range ━━━━━━━━━━━━━━━━━━━━━━━

    [1]  All ports (1-65535)
    [2]  Common ports (top 1000)
    [3]  Custom range
    [4]  Manual list (comma separated)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Port Range > " SINGLE_IP_SCAN_PORT
    printf "%b" "$RESET"

    local port_flag
    case "$SINGLE_IP_SCAN_PORT" in
        1) port_flag="-p 1-65535" 
            ;;
        2) port_flag="" 
            ;;
        3)
            printf "%b" "$BRIGHT_YELLOW"
            read -rp "    Range (e.g. 20-100) > " port_arg
            printf "%b" "$RESET"
            port_flag="-p $port_arg"
            ;;
        4)
            printf "%b" "$BRIGHT_YELLOW"
            read -rp "    Ports (e.g. 22,80,443) > " port_arg
            printf "%b" "$RESET"
            port_flag="-p $port_arg"
            ;;
        *)
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Invalid option."
            printf "%b" "$RESET"
            return 7
            ;;
    esac

    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Scan Speed ━━━━━━━━━━━━━━━━━━━━━━━

    [1]  T1 - Sneaky
    [2]  T2 - Polite
    [3]  T3 - Normal
    [4]  T4 - Aggressive
    [5]  T5 - Insane

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Scan Speed > " SINGLE_IP_SCAN_SPEED
    printf "%b" "$RESET"

    local timing
    case "$SINGLE_IP_SCAN_SPEED" in
        1) timing="-T1" ;;
        2) timing="-T2" ;;
        3) timing="-T3" ;;
        4) timing="-T4" ;;
        5) timing="-T5" ;;
        *)
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Invalid option."
            printf "%b" "$RESET"
            return 7
            ;;
    esac

    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Scan Type ━━━━━━━━━━━━━━━━━━━━━━━━

    [1]  SYN Stealth
    [2]  TCP Connect
    [3]  Version Detection
    [4]  SYN + Version
    [5]  UDP Scan

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Scan Type > " SINGLE_IP_SCAN_TYPE
    printf "%b" "$RESET"

    local scan_flags
    case "$SINGLE_IP_SCAN_TYPE" in
        1) scan_flags="-sS"     
            ;;
        2) scan_flags="-sT"     
            ;;
        3) scan_flags="-sV"     
            ;;
        4) scan_flags="-sS -sV" 
            ;;
        5) scan_flags="-sU"
            ;;
        *)
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Invalid option."
            printf "%b" "$RESET"
            return 7
            ;;
    esac

    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Decoys ━━━━━━━━━━━━━━━━━━━━━━━

    [1] Disabled
    [2] Enabled (RND:20,ME)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "Decoys > " DECOY_OPTIONS
    printf "%b" "$RESET"

    local decoy_flags
    case "$DECOY_OPTIONS" in
        1) decoy_flags=""
            ;;
        2) decoy_flags="-D RND:20,ME"
            ;;
        *)
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Invalid option."
        printf "%b" "$RESET"
        return 7
            ;;
    esac

    echo
    printf "%b    [*] Enter sudo password: %b" "$BRIGHT_YELLOW" "$RESET"
    sudo -v

    echo
    print_info "[*] Port scanning '$TARGET_IP'..."
    echo

    sudo nmap \
    $decoy_flags \
    $scan_flags \
    $timing \
    $port_flag \
    --open \
    -oG - \
    "$TARGET_IP" > /tmp/nmap_tmp_output &
    local nmap_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $nmap_pid"
    printf "%b" "$RESET"

    show_spinner "$nmap_pid"
    wait "$nmap_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Scan failed."
        printf "%b" "$RESET"

        rm -f /tmp/nmap_tmp_output
        return 8
    fi

    echo

    print_info "[*] Parsing scan results..."

    local open_ports
    open_ports=$(awk -F'Ports: ' '/Ports:/ {print $2}' /tmp/nmap_tmp_output)

    if [[ -z "$open_ports" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No open ports found."
        printf "%b" "$BRIGHT_WHITEs"

        local file_name="$TARGET.ip-portscan.result"

        save_output "{}" "$file_name"

        rm -f /tmp/nmap_tmp_output
        printf "%b" "$RESET"
        return 0
    fi

    local ports_list
    ports_list=$(printf "%s\n" "$open_ports" | tr ',' '\n')

    local open_ports_count
    open_ports_count=$(printf "%s\n" "$ports_list" | sed '/^$/d' | wc -l)

    echo
    print_info "[+] $open_ports_count open port(s) found."
    echo

    printf "%b" "$BRIGHT_GREEN"
    printf "%s\n" "$ports_list" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print "    " $0}'
    printf "%b" "$BRIGHT_WHITE"

    local file_name="$TARGET.ip-portscan.result"
    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "ip": "$TARGET_IP",
    "open_ports_count": $open_ports_count,
    "ports": [
$(printf '%s\n' "$ports_list" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print "        \"" $0 "\""}' | sed '$!s/$/,/')
    ]
}
EOF
    )

    save_output "$file_data" "$file_name"

    echo
    print_info "[*] Results saved."

    rm -f /tmp/nmap_tmp_output

    printf "%b" "$RESET"
}