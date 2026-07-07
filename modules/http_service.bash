#!/usr/bin/env bash

http_service_discovery() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ██╗  ██╗████████╗████████╗██████╗     ███████╗███████╗██████╗ ██╗   ██╗██╗ ██████╗███████╗
    ██║  ██║╚══██╔══╝╚══██╔══╝██╔══██╗    ██╔════╝██╔════╝██╔══██╗██║   ██║██║██╔════╝██╔════╝
    ███████║   ██║      ██║   ██████╔╝    ███████╗█████╗  ██████╔╝██║   ██║██║██║     █████╗  
    ██╔══██║   ██║      ██║   ██╔═══╝     ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║     ██╔══╝  
    ██║  ██║   ██║      ██║   ██║         ███████║███████╗██║  ██║ ╚████╔╝ ██║╚██████╗███████╗
    ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝         ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝ ╚═════╝╚══════╝
                                                                                              
    ██████╗ ██╗███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗                    
    ██╔══██╗██║██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝                    
    ██║  ██║██║███████╗██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝                     
    ██║  ██║██║╚════██║██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝                      
    ██████╔╝██║███████║╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║                       
    ╚═════╝ ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝                       
                                                                                          
                                                                                                                                                    
EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool curl jq naabu
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

    local total
    total=$(wc -l < "$INPUT_FILE")

    echo
    print_info "[*] Targets to check : $total"
    echo

    local PORT_SCAN_OUTPUT
    PORT_SCAN_OUTPUT=$(mktemp) || return 12

    print_info "[*] Scanning HTTP ports..."

    naabu -silent -list "$INPUT_FILE" -p 80,81,443,591,593,8000,8008,8080,8081,8088,8443,8888,9000,9090 > "$PORT_SCAN_OUTPUT" &
    local naabu_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $naabu_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$naabu_pid"
    echo

    wait "$naabu_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] naabu failed."
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$INPUT_FILE" "$PORT_SCAN_OUTPUT"
        return 12
    fi

    if [[ ! -s "$PORT_SCAN_OUTPUT" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No HTTP services found."
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$INPUT_FILE" "$PORT_SCAN_OUTPUT"
        return 12
    fi

    total=$(wc -l < "$PORT_SCAN_OUTPUT")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] HTTP ports discovered."
    print_info "    Open services : $total"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local RESULT_FILE
    RESULT_FILE=$(mktemp)
    if [[ $? -ne 0 ]]
    then
        rm -f "$INPUT_FILE" "$PORT_SCAN_OUTPUT"
        return 12
    fi

    print_info "[*] Probing HTTP services..."
    echo

    while IFS=: read -r host port
    do
        if [[ "$port" == "443" || "$port" == "8443" ]]
        then
            scheme="https"
        else
            scheme="http"
        fi

        url="${scheme}://${host}:${port}"

        headers=$(curl \
            -ksSI \
            --connect-timeout 5 \
            --max-time 6 \
            -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36" \
            -H "Accept: */*" \
            -H "Accept-Language: en-US,en;q=0.9" \
            -H "Connection: close" \
            "$url") || continue

        status=$(printf "%s\n" "$headers" |
            awk 'NR==1 {print $2}' |
            tr -d '\r\n')

        server=$(printf "%s\n" "$headers" |
            awk -F': ' 'tolower($1)=="server" {print $2; exit}' |
            tr -d '\r\n')

        [[ -z "$status" ]] && continue

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] $url -> HTTP ($status) ${server:+[$server]}"
        printf "%b" "$BRIGHT_WHITE"

        printf "%s|%s|%s\n" "$url" "$status" "$server" >> "$RESULT_FILE"

    done < "$PORT_SCAN_OUTPUT"

    if [[ ! -s "$RESULT_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No HTTP services detected."
        printf "%b" "$BRIGHT_WHITE"

        rm -f "$INPUT_FILE" "$PORT_SCAN_OUTPUT" "$RESULT_FILE"
        return 12
    fi

    total=$(wc -l < "$RESULT_FILE")

    echo
    print_info "[+] HTTP Service Discovery Summary:"
    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "    HTTP services : $total"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local file_name
    file_name="$TARGET.http.service.discovery.result"

    echo
    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "http_services": $total
    },
    "results": [
$(awk -F'|' '
{
    printf "        {\n"
    printf "            \"url\": \"%s\",\n",$1
    printf "            \"status\": \"%s\",\n",$2
    printf "            \"server\": \"%s\"\n",$3
    printf "        }%s\n",(NR==total?"":",")
}' total="$total" "$RESULT_FILE")
    ]
}
EOF
    )

    save_output "$file_data" "$file_name"

    echo
    print_info "[*] Results saved."
    echo

    print_info "[*] Creating unique HTTP service list..."
    echo

    jq -r '.results[].url' "$TARGET_DIR/$file_name" | sort -u > "$TARGET_DIR/$TARGET.http.service.discovery.unique"

    printf "%b" "$BRIGHT_CYAN"
    print_info "[!!] If you want a unique list of HTTP services to pipe into other tools, you can find it here:"
    printf "%b" "$BRIGHT_YELLOW"
    print_info "[>] $TARGET_DIR/$TARGET.http.service.discovery.unique"
    printf "%b" "$BRIGHT_WHITE"

    rm -f "$INPUT_FILE" "$PORT_SCAN_OUTPUT" "$RESULT_FILE"

    echo
    print_info "[+] HTTP Service Discovery completed."
    printf "%b" "$RESET"

}