#!/usr/bin/env bash

declare -A CDN_PROVIDERS=(
    [13335]="Cloudflare"
    [16509]="CloudFront"
    [20940]="Akamai"
    [8075]="Azure CDN"
    [15169]="Google Cloud"
    [14061]="DigitalOcean"
    [202468]="ArvanCloud"
    [60068]="CDNetworks"
    [45102]="Alibaba Cloud CDN"
    [36351]="Incapsula"
    [19551]="Imperva"
    [54113]="Fastly"
    [19905]="Bing"
    [209242]="Cloudflare"
    [14618]="Amazon AWS"
    [396982]="Google Cloud"
    [8987]="Fastly"
    [132203]="Tencent Cloud"
    [37963]="Alibaba Cloud"
    [4134]="ChinaNet CDN"
    [16625]="Akamai"
    [17204]="Akamai"
    [18717]="Akamai"
    [23454]="Akamai"
    [23455]="Akamai"
    [24319]="Akamai"
    [35994]="Akamai"
    [35995]="Akamai"
    [202319]="Sotoon CDN"
    [44932]="SABAIDEA"
)

cdn_detection() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


     ██████╗██████╗ ███╗   ██╗                                              
    ██╔════╝██╔══██╗████╗  ██║                                              
    ██║     ██║  ██║██╔██╗ ██║                                              
    ██║     ██║  ██║██║╚██╗██║                                              
    ╚██████╗██████╔╝██║ ╚████║                                              
     ╚═════╝╚═════╝ ╚═╝  ╚═══╝                                              
                                                                            
    ██████╗ ███████╗████████╗███████╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗
    ██╔══██╗██╔════╝╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║
    ██║  ██║█████╗     ██║   █████╗  ██║        ██║   ██║██║   ██║██╔██╗ ██║
    ██║  ██║██╔══╝     ██║   ██╔══╝  ██║        ██║   ██║██║   ██║██║╚██╗██║
    ██████╔╝███████╗   ██║   ███████╗╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║
    ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
                                                                        
            
EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool dig jq whois
    then
        printf "%b" "$BRIGHT_WHITE"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    if [[ ! "$TARGET_TYPE" == "DOMAIN" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] This module is only available for DOMAIN type"
        echo
        printf "%b" "$BRIGHT_WHITE"
        return 11
    fi

    local LIVE_SUBS_FILE="$TARGET_DIR/$TARGET.name.resolution.unique"
    local DNS_BRUTE_FILE="$TARGET_DIR/$TARGET.dns.bruteforce.result"

    if [[ ! -f "$LIVE_SUBS_FILE" ]] || [[ ! -s "$LIVE_SUBS_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] This module needs something to work on."
        echo
        print_info "[!] At minimum, run Subdomain Discovery (option 7)"
        print_info "[!] and then Name Resolution (option 9) to generate"
        print_info "[!] a list of live subdomains."
        echo
        print_info "[!] DNS Brute Force is also recommended, but it"
        print_info "[!] can take a long time depending on the wordlists."
        printf "%b" "$BRIGHT_WHITE"
        return 0
    fi
    echo
    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] The most accurate method would be fetching IP ranges"
    print_info "[*] directly from each provider and comparing against results."
    print_info "[*] For now, this module stays lightweight using ASN lookup only."
    printf "%b" "$BRIGHT_GREEN"
    print_info "[*] Also note that ASNs are changing continuously, so keep the list updated."
    printf "%b" "$BRIGHT_WHITE"

    local INCLUDE_DNS_BRUTE="n"

    if [[ -f "$DNS_BRUTE_FILE" && -s "$DNS_BRUTE_FILE" ]]
    then
        echo
        printf "%b" "$BRIGHT_YELLOW"
        read -r -p "    Include DNS Brute Force results as well? (y/N)> " INCLUDE_DNS_BRUTE
        printf "%b" "$BRIGHT_WHITE"
    fi

    local INPUT_FILE
    INPUT_FILE=$(mktemp) || return 12

    if [[ "${INCLUDE_DNS_BRUTE,,}" == "y" ]]
    then
        jq -r '.results[].subdomain' "$DNS_BRUTE_FILE" >> "$INPUT_FILE"

        cat "$LIVE_SUBS_FILE" >> "$INPUT_FILE"
    else
        cat "$LIVE_SUBS_FILE" > "$INPUT_FILE"
    fi

    sort -u "$INPUT_FILE" -o "$INPUT_FILE"

    # CDN_RESULT=$(mktemp) || return 12
    # NON_CDN_RESULT=$(mktemp) || return 12
    
    local CDN_RESULT="$TARGET_DIR/$TARGET.cdn.detection.result"
    local NON_CDN_RESULT="$TARGET_DIR/$TARGET.non.cdn.result"
    
    # remove previous files (if there are some)
    rm -f "$CDN_RESULT" "$NON_CDN_RESULT"

    touch "$CDN_RESULT" "$NON_CDN_RESULT"
    echo
    print_info "[*] Checking live subdomains against known CDN ASN ranges..."
    print_info "[*] This may take some time depending on the number of targets."

    while read -r sub
    do
        ips=$(resolve_ip "$sub")

        if [[ -z "$ips" ]]
        then
            continue
        fi

        while read -r ip
        do
            asn=$(get_asn "$ip")
            asn=$(echo "$asn" | tr -d '[:space:]')

            if [[ -z "$asn" ]]
            then
                continue
            fi

            provider=${CDN_PROVIDERS[$asn]}

            if [[ -n "$provider" ]]
            then
                printf "%b" "$BRIGHT_GREEN"
                print_info "    [CDN] $sub -> $ip (ASN: $asn | $provider)"
                printf "%b" "$BRIGHT_WHITE"
                echo "$sub|$ip|$asn|$provider" >> "$CDN_RESULT"
            else
                printf "%b" "$BRIGHT_CYAN"
                print_info "    [---] $sub -> $ip (ASN: $asn)"
                printf "%b" "$BRIGHT_WHITE"
                echo "$sub|$ip|$asn|UNKNOWN" >> "$NON_CDN_RESULT"
            fi

        done <<< "$ips"

    done < "$INPUT_FILE"

    sort -u "$CDN_RESULT" -o "$CDN_RESULT"
    sort -u "$NON_CDN_RESULT" -o "$NON_CDN_RESULT"

    cdn_count=$(wc -l < "$CDN_RESULT")
    non_cdn_count=$(wc -l < "$NON_CDN_RESULT")


    print_info "[+] CDN Detection Completed"
    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "    CDN hosts     : $cdn_count"
    print_info "    Non CDN hosts : $non_cdn_count"
    printf "%b" "$BRIGHT_WHITE"

    echo
    print_info "[*] Results saved in files:"
    print_info "[*] $TARGET_DIR/$TARGET.cdn.detection.result  FOR SITES BEHIND A CDN PROVIDER (KNOWN IN MOLUDE)"
    print_info "[*] $TARGET_DIR/$TARGET.non.cdn.result        FOR SITES NOT BEHIND A CDN PROVIDER (UNKNOW IN MODULE)"
    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] You can add specific CDN to this moldule easily."
    printf "%b" "$BRIGHT_WHITE"
    
    printf "%b" "$RESET"

}

get_asn()
{
    local ip="$1"

    whois -h whois.cymru.com " -v $ip" |
    tail -n +2 |
    awk '{print $1}'
}

resolve_ip()
{
    local host="$1"

    dig a +short "$host" |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}