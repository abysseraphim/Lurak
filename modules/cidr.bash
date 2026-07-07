#!/usr/bin/env bash

cidr_discovery() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


     ██████╗██╗██████╗ ██████╗                                            
    ██╔════╝██║██╔══██╗██╔══██╗                                           
    ██║     ██║██║  ██║██████╔╝                                           
    ██║     ██║██║  ██║██╔══██╗                                           
    ╚██████╗██║██████╔╝██║  ██║                                           
     ╚═════╝╚═╝╚═════╝ ╚═╝  ╚═╝                                           
                                                                          
    ██████╗ ██╗███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗
    ██╔══██╗██║██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝
    ██║  ██║██║███████╗██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝ 
    ██║  ██║██║╚════██║██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝  
    ██████╔╝██║███████║╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║   
    ╚═════╝ ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   
                                                                      

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool whois dig
    then
        printf "%b" "$RESET"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    if [[ $TARGET_TYPE == "CIDR" ]]
    then
        print_info "[*] Target Type is already in CIDR"
        TARGET_CIDR="$TARGET"
    fi

    if ! resolve_target_to_ip # here another global variable will be declared : TARGET_IP
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] IP cannot be resolved."
        printf "%b" "$RESET"
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
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] CIDR was NOT found."
        printf "%b" "$RESET"
        return 6
    fi

    echo

    print_info "[*] CIDR discovery was SUCCESSFUL."
    print_info "[*] Target prefix: $TARGET_CIDR"

    echo

    local prefix=${TARGET_CIDR#*/}
    local host_bits=$((32 - $prefix))
    local ip_count=$((1 << $host_bits))

    print_info "[*] Total IPs in this range:"
    print_info "[+] $ip_count"

    echo

    local whois_data
    whois_data=$(whois "$TARGET_IP")

    local registry
    registry=$(echo "$whois_data" | awk -F: '/^(source|Source):/ {print $2; exit}' | xargs)

    local country
    country=$(echo "$whois_data" | awk -F: '/^(country|Country):/ {print $2; exit}' | xargs)

    local organization
    organization=$(echo "$whois_data" | awk -F: '/^(org-name|OrgName|organisation|Organization|owner):/ {print $2; exit}' | xargs)

    local network_address=${TARGET_CIDR%/*}

    IFS='.' read -r o1 o2 o3 o4 <<< "$network_address"

    local last_octet=$((o4 + ip_count - 1))
    local broadcast="$o1.$o2.$o3.$last_octet"

    print_info "[*] Network Address:"
    print_info "[+] $network_address"

    echo

    print_info "[*] Broadcast Address:"
    print_info "[+] $broadcast"

    echo

    if [[ -n "$registry" ]]
    then
        print_info "[*] Registry:"
        print_info "[+] $registry"
    fi

    echo

    if [[ -n "$country" ]]
    then
        print_info "[*] Country:"
        print_info "[+] $country"
    fi

    echo

    if [[ -n "$organization" ]]
    then
        print_info "[*] Organization:"
        print_info "[+] $organization"
    fi
    
    local file_name="$TARGET.cidr.disc.result"
    local asn_res_path="$TARGET_DIR/$file_name"
    print_info "[*] Saving results to: $asn_res_path"

    file_data=`cat <<EOF
{
    "cidr": "$TARGET_CIDR",
    "network": "$network_address",
    "broadcast": "$broadcast",
    "total_ips": "$ip_count",
    "registry": "$registry",
    "country": "$country",
    "organization": "$organization"
}
EOF
`

    save_output "$file_data" "$file_name"
    print_info "[*] Results saved."

    printf "%b" "$RESET"

}
