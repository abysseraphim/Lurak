#!/usr/bin/env bash

declare -a DOMAIN_DISCOVERY_RES

domain_discovery() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗                     
    ██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║                     
    ██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║                     
    ██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║                     
    ██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║                     
    ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝                     
                                                                          
    ██████╗ ██╗███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗
    ██╔══██╗██║██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝
    ██║  ██║██║███████╗██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝ 
    ██║  ██║██║╚════██║██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝  
    ██████╔╝██║███████║╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║   
    ╚═════╝ ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝   
                                                                      

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool curl openssl jq psql
    then
        printf "%b" "$RESET"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"

    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        print_info "[!] This module does not support CIDR targets."
        print_info "[*] Run port scan and service discovery for best results."
        return 10
    fi

    if [[ "$TARGET_TYPE" == "DOMAIN" ]]
    then
        local dot_count="${TARGET//[^.]/}" # remove all characters which aren't dot
        if (( ${#dot_count} >= 2 ))
        then
            print_info "[!] Subdomain detected. This module only supports root domains and IPs."
            return 10
        fi
    fi

    cert_san_lookup_domain
    reverse_ip_lookup_domain
    historical_ip_lookup_domain
    ptr_record_lookup_domain

    local total=${#DOMAIN_DISCOVERY_RES[@]}

    local count_cert_san=0
    local count_reverse_ip=0
    local count_historical_ip=0
    local count_ptr=0

    local json_results=""
    local entry domain method provider

    for entry in "${DOMAIN_DISCOVERY_RES[@]}"
    do
        IFS="|" read -r domain method provider <<< "$entry"

        case "$method" in
            cert_san)     
                (( count_cert_san++ ))
                ;;
            reverse_ip)   
                (( count_reverse_ip++ ))
                ;;
            historical_ip)
                (( count_historical_ip++ ))
                ;;
            ptr)
                (( count_ptr++ ))
                ;;
        esac

        json_results+="    {\"domain\": \"$domain\", \"method\": \"$method\", \"provider\": \"$provider\"},\n"
    done

    local new_file_name="$TARGET.domain.discovery.result"
    
    print_info "[*] Total domains found: $total"
    printf "%b" "$BRIGHT_MAGENTA"
    echo
    print_info "[!!] NOTE THAT THIS MODULE WORKS BASED ON POSSIBILITIES AND MAY INCLUDE INCOMPLETE OR NOISY DATA"
    print_info "[!!] MAKE SURE TO VERIFY RESULTS BEFORE TAKING ANY ACTION"
    print_info "[!!] THIS MODULE IS BASED ON BEST-EFFORT OSINT DATA"
    print_info "[!!] OUTPUT IS INTENTIONALLY LEFT UNFILTERED TO PRESERVE FULL SIGNAL"
    printf "%b" "$BRIGHT_WHITE"
    echo
    print_info "[*] Saving results to: $TARGET_DIR/$new_file_name"
    echo
 
    results_json=$(printf "%b" "$json_results" | sed '$ s/,$//')
 
    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "total": $total,
        "cert_san": $count_cert_san,
        "reverse_ip": $count_reverse_ip,
        "historical_ip": $count_historical_ip,
        "ptr": $count_ptr
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
    printf "%b" "$RESET"
    echo

}

cert_san_lookup_domain() {

    print_info "[*] Certificate SAN lookup started..."
    echo

    if [[ "$TARGET_TYPE" == "IP" ]]
    then

        print_info "[*] Openssl grab on $TARGET:443"
        echo

        local san_line
        san_line=$(openssl s_client -connect "$TARGET:443" </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -n1)

        if [[ -z "$san_line" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] No response or no cert from $TARGET:443"
            echo
            printf "%b" "$BRIGHT_WHITE"
            return
        fi

        # san line looks like DNS:foo.com, DNS:bar.com, IP Address:1.2.3.4
        local entry
        while IFS= read -r entry
        do
            entry="${entry//DNS:/}" # the general syntax is variable//pattern/replacement
            entry="${entry//IP Address:/}"
            entry="${entry// /}"
            entry="${entry//,/}"
            [[ -z "$entry" ]] && continue

            # skip IP's and wildcards
            [[ "$entry" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
            [[ "$entry" == \** ]] && continue

            # filter subdomain of target
            if [[ "$entry" == *".$TARGET" ]] || [[ "$entry" == "$TARGET" ]]
            then
                continue
            fi

            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] Cert SAN: $entry"
            printf "%b" "$BRIGHT_WHITE"

            DOMAIN_DISCOVERY_RES+=("$entry|cert_san|openssl_no_sni")
        done < <(echo "$san_line" | tr ',' '\n')
        echo

    else
        # DOMAIN -query crt.sh
        print_info "[*] Crt.sh query for $TARGET"

        local response
        local attempt
        local query

        query=$(cat <<EOF
SELECT
    ci.NAME_VALUE
FROM
    certificate_and_identities ci
WHERE
    plainto_tsquery('certwatch', '$TARGET') @@ identities(ci.CERTIFICATE)
EOF
)

        for attempt in 1 2 3
        do
            response=$(
            echo "$query" |
            psql -t -h crt.sh -p 5432 -U guest certwatch 2>/dev/null |
            sed 's/ //g' |
            sed 's/^\*\.//' |
            tr '[:upper:]' '[:lower:]' |
            grep -E '^[[:alnum:]][[:alnum:].-]*\.[[:alpha:]]{2,}$' |
            sort -u
            )

            [[ -n "$response" ]] && break

            print_info "[*] crt.sh attempt $attempt failed, retrying..."
            sleep 2
        done

        if [[ -z "$response" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Crt.sh: no response or timeout"
            printf "%b" "$BRIGHT_WHITE"
            return
        fi

        # extract name_value, one per line, deduplicate
        local -a seen=()
        local name
        while IFS= read -r name
        do
            # strip wildcard prefix
            name="${name//\*./}"
            [[ -z "$name" ]] && continue

            # skip if subdomain of target
            if [[ "$name" == *".$TARGET" ]] || [[ "$name" == "$TARGET" ]]
            then
                continue
            fi

            # dedup
            local already=0
            local s
            for s in "${seen[@]}"
            do
                [[ "$s" == "$name" ]] && already=1 && break
            done
            (( already )) && continue
            seen+=("$name")

            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] Cert SAN: $name"
            printf "%b" "$BRIGHT_WHITE"

            DOMAIN_DISCOVERY_RES+=("$name|cert_san|crt.sh")
        done < <(echo "$response")
        echo
    fi
}

reverse_ip_lookup_domain() {

    print_info "[*] Reverse IP lookup started..."
    echo

    local query_ip

    if resolve_target_to_ip
    then
        query_ip="$TARGET_IP"
        print_info "[*] Resolved to $query_ip"
        echo
    else
        print_info "[!] Could not resolve $TARGET — querying with domain directly"
        echo
        query_ip="$TARGET"
    fi

    local response
    response=$(curl -sf --max-time 15 "https://api.hackertarget.com/reverseiplookup/?q=${query_ip}")

    # echo "QUERY_IP=[$query_ip]"
    # echo "RESPONSE=[$response]"

    if [[ -z "$response" ]] || [[ "$response" == *"error"* ]] || [[ "$response" == *"API count"* ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] HackerTarget reverse IP: no response or API limit reached"
        echo
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    local name
    while IFS= read -r name
    do
        name="${name// /}"
        [[ -z "$name" ]] && continue

        if [[ "$TARGET_TYPE" == "DOMAIN" ]]
        then
            if [[ "$name" == *".$TARGET" ]] || [[ "$name" == "$TARGET" ]]
            then
                continue
            fi
        fi

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Reverse IP: $name"
        printf "%b" "$BRIGHT_WHITE"

        DOMAIN_DISCOVERY_RES+=("$name|reverse_ip|hackertarget")
    done < <(echo "$response")
    echo
}

historical_ip_lookup_domain() {

    print_info "[*] Historical IP lookup started..."
    echo

    local -a seen=()

    robtex_query() {
        local ip="$1"

        print_info "[*] Robtex passive DNS query for $ip"
        echo

        local response
        response=$(curl -sf --max-time 15 "https://freeapi.robtex.com/ipquery/$ip")

        if [[ -z "$response" ]] || [[ "$response" == *'"status":"nok"'* ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Robtex: no response for $ip"
            echo
            printf "%b" "$BRIGHT_WHITE"
            return
        fi

        local name
        while IFS= read -r name
        do
            name="${name// /}"
            [[ -z "$name" ]] && continue

            if [[ "$TARGET_TYPE" == "DOMAIN" ]]
            then
                if [[ "$name" == *".$TARGET" ]] || [[ "$name" == "$TARGET" ]]
                then
                    continue
                fi
            fi

            local already=0
            local s
            for s in "${seen[@]}"
            do
                [[ "$s" == "$name" ]] && already=1 && break
            done
            (( already )) && continue
            seen+=("$name")

            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] Historical IP ($ip): $name"
            printf "%b" "$BRIGHT_WHITE"

            DOMAIN_DISCOVERY_RES+=("$name|historical_ip|robtex")
        done < <(echo "$response" | jq -r '.pas[].o // empty' 2>/dev/null)
        echo
    }

    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        robtex_query "$TARGET"
        return
    fi

    # DOMAIN resolve to IP then query robtex
    if resolve_target_to_ip
    then
        robtex_query "$TARGET_IP"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Could not resolve $TARGET"
        echo
        printf "%b" "$BRIGHT_WHITE"
    fi
}

ptr_record_lookup_domain() {

    print_info "[*] PTR record lookup started..."
    echo

    if ! resolve_target_to_ip
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Could not resolve $TARGET to IP"
        echo
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    local ptr
    ptr=$(dig +short -x "$TARGET_IP" 2>/dev/null | head -n1)
    ptr="${ptr%.}" # drop trailing dot

    if [[ -z "$ptr" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No PTR record found for $TARGET_IP"
        echo
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] PTR: $ptr"
    printf "%b" "$BRIGHT_WHITE"
    echo

    DOMAIN_DISCOVERY_RES+=("$ptr|ptr|dig")
}