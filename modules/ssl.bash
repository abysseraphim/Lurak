#!/usr/bin/env bash

certificate_inspection() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


     ██████╗███████╗██████╗ ████████╗██╗███████╗██╗ ██████╗ █████╗ ████████╗███████╗
    ██╔════╝██╔════╝██╔══██╗╚══██╔══╝██║██╔════╝██║██╔════╝██╔══██╗╚══██╔══╝██╔════╝
    ██║     █████╗  ██████╔╝   ██║   ██║█████╗  ██║██║     ███████║   ██║   █████╗  
    ██║     ██╔══╝  ██╔══██╗   ██║   ██║██╔══╝  ██║██║     ██╔══██║   ██║   ██╔══╝  
    ╚██████╗███████╗██║  ██║   ██║   ██║██║     ██║╚██████╗██║  ██║   ██║   ███████╗
     ╚═════╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝     ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
                                                                                    
    ██╗███╗   ██╗███████╗██████╗ ███████╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗    
    ██║████╗  ██║██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║    
    ██║██╔██╗ ██║███████╗██████╔╝█████╗  ██║        ██║   ██║██║   ██║██╔██╗ ██║    
    ██║██║╚██╗██║╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██║██║   ██║██║╚██╗██║    
    ██║██║ ╚████║███████║██║     ███████╗╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║    
    ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝    
                                                                                

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool openssl jq
    then
        printf "%b" "$RESET"
        return 3
    fi
    printf "%b" "$BRIGHT_WHITE"
    
    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] This module is only available for IP and DOMAIN types."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi
    
    local INPUT_FILE
    INPUT_FILE=$(mktemp) || return 12

    # IP
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        echo "$TARGET" > "$INPUT_FILE"

    # DOMAIN
    else
        echo "$TARGET" > "$INPUT_FILE"

        local LIVE_SUBS_FILE="$TARGET_DIR/$TARGET.name.resolution.unique"
        local DNS_BRUTE_FILE="$TARGET_DIR/$TARGET.dns.bruteforce.result"

        if [[ -f "$LIVE_SUBS_FILE" && -s "$LIVE_SUBS_FILE" ]]
        then
            echo
            printf "%b" "$BRIGHT_YELLOW"
            local include_subs
            read -r -p "    Include resolved subdomains? (y/N)> " include_subs
            printf "%b" "$BRIGHT_WHITE"

            if [[ "${include_subs,,}" == "y" ]]
            then
                cat "$LIVE_SUBS_FILE" >> "$INPUT_FILE"
            fi
        else
            echo
            printf "%b" "$BRIGHT_MAGENTA"
            print_info "[!] If you want this module to also be applied to subdomains of your domains, run option 7 & 9 (suabdomain discover & name resolution)"
            print_info "[!] And come back again!"
            print_info "[!] Also you can run option 8 (dns brute force)"
            printf "%b" "$BRIGHT_WHITE"
            echo
        fi

        if [[ -f "$DNS_BRUTE_FILE" && -s "$DNS_BRUTE_FILE" ]]
        then
            echo
            printf "%b" "$BRIGHT_YELLOW"
            local include_brute
            read -r -p "    Include DNS brute force results? (y/N)> " include_brute
            printf "%b" "$BRIGHT_WHITE"

            if [[ "${include_brute,,}" == "y" ]]
            then
                jq -r '.results[].subdomain' "$DNS_BRUTE_FILE" >> "$INPUT_FILE"
            fi
        fi

        sort -u "$INPUT_FILE" -o "$INPUT_FILE"
    fi

    local total
    total=$(wc -l < "$INPUT_FILE")

    echo
    print_info "[*] Targets to inspect : $total"
    echo

    # SINGLE TARGET (IP or domain-only, no subs)
    if [[ "$total" -eq 1 ]]
    then
        local host
        host=$(cat "$INPUT_FILE")

        local cert_output
        if [[ "$TARGET_TYPE" == "IP" ]]
        then
            cert_output=$(openssl s_client -connect "$host:443" </dev/null 2>/dev/null \
                | openssl x509 -noout -text 2>/dev/null)
        else
            cert_output=$(openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
                | openssl x509 -noout -text 2>/dev/null)
        fi

        if [[ -z "$cert_output" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Could not retrieve certificate for $host"
            printf "%b" "$RESET"
            rm -f "$INPUT_FILE"
            return 12
        fi

        echo
        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Certificate for $host :"
        echo
        printf "%b" "$BRIGHT_WHITE"
        printf "%s\n" "$cert_output"

        rm -f "$INPUT_FILE"
        printf "%b" "$RESET"
        return 0
    fi

    # MULTIPLE TARGETS (subdomains included)
    local RESULT_FILE
    RESULT_FILE=$(mktemp) || { rm -f "$INPUT_FILE"; return 12; }

    while read -r host
    do
        local cert_output
        cert_output=$(openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
            | openssl x509 -noout -text 2>/dev/null)

        if [[ -z "$cert_output" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] No certificate : $host"
            printf "%b" "$BRIGHT_WHITE"
            continue
        fi

        local subject issuer not_before not_after san
        subject=$(printf "%s" "$cert_output"  | grep "Subject:"  | head -1 | sed 's/.*Subject: //')
        issuer=$(printf "%s"  "$cert_output"  | grep "Issuer:"   | head -1 | sed 's/.*Issuer: //')
        not_before=$(printf "%s" "$cert_output" | grep "Not Before" | sed 's/.*Not Before: //')
        not_after=$(printf "%s"  "$cert_output" | grep "Not After"  | sed 's/.*Not After : //')
        san=$(printf "%s" "$cert_output" | grep -A1 "Subject Alternative Name" | tail -1 | tr ',' '\n' | sed 's/.*DNS://' | sed 's/.*IP Address://' | tr -d ' ' | tr '\n' '|' | sed 's/|$//')

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] $host"
        printf "%b" "$BRIGHT_WHITE"
        print_info "    Subject    : $subject"
        print_info "    Issuer     : $issuer"
        print_info "    Not Before : $not_before"
        print_info "    Not After  : $not_after"
        print_info "    SAN        : $san"
        echo

        san_json=$(printf "%s" "$san" | tr '|' '\n' | awk '{printf "\"%s\",",$0}' | sed 's/,$//')
        printf "%s|%s|%s|%s|%s|%s\n" "$host" "$subject" "$issuer" "$not_before" "$not_after" "$san_json" >> "$RESULT_FILE"

    done < "$INPUT_FILE"

    if [[ ! -s "$RESULT_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No certificates retrieved."
        printf "%b" "$RESET"
        rm -f "$INPUT_FILE" "$RESULT_FILE"
        return 12
    fi

    total=$(wc -l < "$RESULT_FILE")

    local file_name
    file_name="$TARGET.certificate.inspection.result"

    echo
    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "inspected": $total
    },
    "results": [
$(awk -F'|' '
{
    printf "        {\n"
    printf "            \"host\": \"%s\",\n", $1
    printf "            \"subject\": \"%s\",\n", $2
    printf "            \"issuer\": \"%s\",\n", $3
    printf "            \"not_before\": \"%s\",\n", $4
    printf "            \"not_after\": \"%s\",\n", $5
    printf "            \"san\": [%s]\n", $6
    printf "        }%s\n", (NR==total ? "" : ",")
}' total="$total" "$RESULT_FILE")
    ]
}
EOF
    )

    save_output "$file_data" "$file_name"

    rm -f "$INPUT_FILE" "$RESULT_FILE"

    echo
    print_info "[*] Results saved."
    printf "%b" "$RESET"

}