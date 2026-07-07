#!/usr/bin/env bash

asn_recon() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


     █████╗ ███████╗███╗   ██╗                                            
    ██╔══██╗██╔════╝████╗  ██║                                            
    ███████║███████╗██╔██╗ ██║                                            
    ██╔══██║╚════██║██║╚██╗██║                                            
    ██║  ██║███████║██║ ╚████║                                            
    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝                                            
                                                                          
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

    if ! resolve_target_to_ip # here another global variable will be declared : TARGET_IP
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] IP cannot be resolved."
        printf "%b" "$RESET"
        return 4
    fi

    print_info "[*] Looking up ASN for '$TARGET_IP'..."

    # extracting AS number
    TARGET_ASN=$(whois -h whois.cymru.com " -v $TARGET_IP" | tail -n +2 | awk '{print $1}')

    if [[ -z "$TARGET_ASN" ]]
    then
        print_info "[!] Unable to determine ASN."
        return 5
    fi

    print_info "[*] AS Number resolved: $TARGET_ASN"

    local asn_data=$(whois -h whois.radb.net "AS$TARGET_ASN")

    local route_data=$(whois -h whois.radb.net -i origin "AS$TARGET_ASN")

    print_info "[*] Looking for OWNER name"
    local name=$(echo "$asn_data" | awk -F: '/^as-name/ {print $2; exit}' | xargs) # xargs to trim the output
    if [[ -z "$name" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No Name found"
        printf "%b" "$BRIGHT_WHITE"
    else
        print_info "[*] Name Found: $name"
    fi

    echo

    print_info "[*] Looking for any description"
    local des=$(echo "$asn_data" | awk -F: '/^descr/ {print $2; exit}' | xargs)
    if [[ -z "$des" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No Description found"
        printf "%b" "$BRIGHT_WHITE"
    else
        print_info "[*] Description Found: $des"
    fi

    echo

    print_info "[*] Looking for owner EMAILS"
    local emails=$(echo "$asn_data" | grep -Eoi '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' | sort -u)
    if [[ -z "$emails" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No Emails found"
        printf "%b" "$BRIGHT_WHITE"
    else
        print_info "[*] Emails Found:"
        printf '    %s\n' $emails
    fi

    echo

    print_info "[*] Finding ipv4 prefixes"
    local ipv4_ranges=$(echo "$route_data" | awk '/^route:/ {print $2}' | sort -u)
    local ipv4_count
    ipv4_count=$(printf "%s\n" "$ipv4_ranges" | sed '/^$/d' | wc -l)
    print_info "[+] $ipv4_count IPv4 prefixes found."

    echo

    print_info "[*] Finding ipv6 prefixes"
    local ipv6_ranges=$(echo "$route_data" | awk '/^route6:/ {print $2}' | sort -u)
    local ipv6_count
    ipv6_count=$(printf "%s\n" "$ipv6_ranges" | sed '/^$/d' | wc -l)
    print_info "[+] $ipv6_count IPv6 prefixes found."
    
    local file_name
    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        local safe_target="${TARGET//\//_}"
        file_name="$safe_target.asn.result"
    else
        file_name="$TARGET.asn.result"
    fi
    local asn_res_path="$TARGET_DIR/$file_name"
    print_info "[*] Saving results to: $asn_res_path"
    
    local file_data

    file_data=`cat <<EOF
{
    "asn": "$TARGET_ASN",
    "name": "$name",
    "des": "$des",
    "email": [
    $(printf '    "%s",\n' $emails | sed '$ s/,$//')
    ],
    "ip_ranges": {
    "ipv4": [
        $(printf '      "%s",\n' $ipv4_ranges | sed '$ s/,$//')
    ],
    "ipv6": [
        $(printf '      "%s",\n' $ipv6_ranges | sed '$ s/,$//')
    ]
    }
}
EOF
    `

    save_output "$file_data" "$file_name"
    print_info "[*] Results saved."

    printf "%b" "$RESET"
}
