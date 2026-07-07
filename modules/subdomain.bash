#!/usr/bin/env bash

subdomain_discovery() {
SUB_DISCOVERY_TMPFILE=$(mktemp)

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ███████╗██╗   ██╗██████╗ ██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗
    ██╔════╝██║   ██║██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║
    ███████╗██║   ██║██████╔╝██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║
    ╚════██║██║   ██║██╔══██╗██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║
    ███████║╚██████╔╝██████╔╝██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║
    ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
                                                                              
    ██████╗ ██╗███████╗ ██████╗ ██████╗ ██╗   ██╗███████╗██████╗ ██╗   ██╗    
    ██╔══██╗██║██╔════╝██╔════╝██╔═══██╗██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝    
    ██║  ██║██║███████╗██║     ██║   ██║██║   ██║█████╗  ██████╔╝ ╚████╔╝     
    ██║  ██║██║╚════██║██║     ██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗  ╚██╔╝      
    ██████╔╝██║███████║╚██████╗╚██████╔╝ ╚████╔╝ ███████╗██║  ██║   ██║       
    ╚═════╝ ╚═╝╚══════╝ ╚═════╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝   ╚═╝       
                                                                          

EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool subfinder psql waybackurls gau unfurl curl jq
    then
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$SUB_DISCOVERY_TMPFILE"
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

    subfinder_function
    crtsh_function
    wayback_function
    gau_function
    hacker_target_function
    security_trails_function
    otx_function

    # dont forget to sort subs.
    sort -u "$SUB_DISCOVERY_TMPFILE" -o "$SUB_DISCOVERY_TMPFILE"

    local results
    results=$(cat "$SUB_DISCOVERY_TMPFILE")

    local unique_subdomains
    unique_subdomains=$(printf "%s\n" "$results" | cut -d'|' -f1 | sort -u | wc -l)

    local subfinder_count
    subfinder_count=$(grep -c '|subfinder$' "$SUB_DISCOVERY_TMPFILE")

    local crtsh_count
    crtsh_count=$(grep -c '|crtsh$' "$SUB_DISCOVERY_TMPFILE")

    local wayback_count
    wayback_count=$(grep -c '|wayback$' "$SUB_DISCOVERY_TMPFILE")

    local gau_count
    gau_count=$(grep -c '|gau$' "$SUB_DISCOVERY_TMPFILE")

    local hackertarget_count
    hackertarget_count=$(grep -c '|hackertarget$' "$SUB_DISCOVERY_TMPFILE")

    local otx_count
    otx_count=$(grep -c '|otx$' "$SUB_DISCOVERY_TMPFILE")

    local securitytrails_count
    securitytrails_count=$(grep -c '|securitytrails$' "$SUB_DISCOVERY_TMPFILE")

    echo
    print_info "[+] Discovery Summary:"
    echo
    print_info "    Total unique records : $unique_subdomains"
    echo
    print_info "    Subfinder      : $(printf "%b" "$BRIGHT_GREEN") $subfinder_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    crt.sh         : $(printf "%b" "$BRIGHT_GREEN") $crtsh_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    Wayback        : $(printf "%b" "$BRIGHT_GREEN") $wayback_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    GAU            : $(printf "%b" "$BRIGHT_GREEN") $gau_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    HackerTarget   : $(printf "%b" "$BRIGHT_GREEN") $hackertarget_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    OTX            : $(printf "%b" "$BRIGHT_GREEN") $otx_count $(printf "%b" "$BRIGHT_WHITE")"
    print_info "    SecurityTrails : $(printf "%b" "$BRIGHT_GREEN") $securitytrails_count $(printf "%b" "$BRIGHT_WHITE")"
    echo

    local PREVIEW_COUNT=20

    echo
    print_info "[*] Showing first $PREVIEW_COUNT results (sample):"
    echo

    printf "%b" "$BRIGHT_GREEN"
    printf "%s\n" "$results" | head -n "$PREVIEW_COUNT" | awk -F'|' '{printf "    %-50s [%s]\n",$1,$2}'
    printf "%b" "$BRIGHT_WHITE"

    local total
    total=$(printf "%s\n" "$results" | wc -l)

    if [[ "$total" -gt "$PREVIEW_COUNT" ]]
    then
        echo
        print_info "[*] Showing $PREVIEW_COUNT/$total records only."
        print_info "[*] Full results are saved in JSON."
        echo
    fi

    local file_name
    file_name="$TARGET.subdomain.discovery.result"

    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "unique_subdomains": $unique_subdomains,
        "subfinder": $subfinder_count,
        "crtsh": $crtsh_count,
        "wayback": $wayback_count,
        "gau": $gau_count,
        "hackertarget": $hackertarget_count,
        "otx": $otx_count,
        "securitytrails": $securitytrails_count
    },
    "results": [
$(printf '%s\n' "$results" | awk -F'|' '
{
    printf "        {\n"
    printf "            \"subdomain\": \"%s\",\n", $1
    printf "            \"provider\": \"%s\"\n", $2
    printf "        }%s\n", (NR==total ? "" : ",")
}' total=$(printf "%s\n" "$results" | wc -l))
    ]
}
EOF
)

    save_output "$file_data" "$file_name"
    print_info "[*] Results saved."
    echo
    print_info "[*] Creating unique subs file...."
    sleep 2

    jq -r '.results[].subdomain' "$TARGET_DIR/$file_name" | sort -u > "$TARGET_DIR/$TARGET.subdomain.discovery.unique"
    printf "%b" "$BRIGHT_CYAN"
    print_info "[!!] If you want completely unique subdomains to pipe to somewhere, you can find them in:"
    printf "%b" "$BRIGHT_YELLOW"
    print_info "[>] $TARGET_DIR/$TARGET.subdomain.discovery.unique"
    printf "%b" "$BRIGHT_CYAN"
    print_info "[!!] The reason that I didn't do only this, is just to keep providers for each subdomain, so you can compare them"
    printf "%b" "$BRIGHT_WHITE"


    rm -f "$SUB_DISCOVERY_TMPFILE"
    printf "%b" "$RESET"
}

subfinder_function() {
    print_info "[*] Running subfinder..."
    local RAW_TMP=$(mktemp)

    subfinder -silent -d "$TARGET" -all > "$RAW_TMP" 2>/dev/null &
    local subfinder_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $subfinder_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$subfinder_pid"
    echo
    wait "$subfinder_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Subfinder failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|subfinder\n" "$sub"
    done < "$RAW_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$RAW_TMP"
}

crtsh_function() {

    print_info "[*] Querying crt.sh ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    local query
    query=$(cat <<-END
SELECT
    ci.NAME_VALUE
FROM
    certificate_and_identities ci
WHERE
    plainto_tsquery('certwatch', '$TARGET') @@ identities(ci.CERTIFICATE)
END
)

    local attempt
    local crtsh_pid
    local status

    for attempt in 1 2 3
    do
        (
            echo "$query" |
            psql -t -h crt.sh -p 5432 -U guest certwatch 2>/dev/null |
            sed 's/ //g' |
            grep -E ".*\.$TARGET" |
            sed 's/^\*\.//' |
            tr '[:upper:]' '[:lower:]' |
            sort -u > "$RAW_TMP"
        ) &

        crtsh_pid=$!

        printf "%b" "$BRIGHT_MAGENTA"
        print_info "[*] Process PID: $crtsh_pid"
        echo
        printf "%b" "$BRIGHT_WHITE"

        show_spinner "$crtsh_pid"
        printf "%b" "$BRIGHT_WHITE"
        echo
        wait "$crtsh_pid"
        status=$?

        if (( status == 0 )) && [[ -s "$RAW_TMP" ]]
        then
            break
        fi

        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] crt.sh attempt $attempt failed."
        printf "%b" "$BRIGHT_WHITE"

        > "$RAW_TMP"
        sleep 2
    done

    if [[ ! -s "$RAW_TMP" ]]
    then
        rm -f "$RAW_TMP"

        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] crt.sh query failed."
        echo
        printf "%b" "$BRIGHT_WHITE"

        return 12
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|crtsh\n" "$sub"
    done < "$RAW_TMP" >> "$SUB_DISCOVERY_TMPFILE"

    rm -f "$RAW_TMP"
}

wayback_function() {

    print_info "[*] Running waybackurls + unfurl for netlocs only ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    waybackurls "$TARGET" | unfurl domains | sort -u > "$RAW_TMP" 2>/dev/null &
    local wayback_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $wayback_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$wayback_pid"
    printf "%b" "$BRIGHT_WHITE"
    echo
    wait "$wayback_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Wayback machine failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|wayback\n" "$sub"
    done < "$RAW_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$RAW_TMP"
}

gau_function() {

    print_info "[*] Running gau + unfurl for netlocs only ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    gau $TARGET --subs 2>/dev/null | unfurl domains | sort -u > "$RAW_TMP" &
    local gau_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $gau_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$gau_pid"
    printf "%b" "$BRIGHT_WHITE"
    echo
    wait "$gau_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Gau failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|gau\n" "$sub"
    done < "$RAW_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$RAW_TMP"
}

hacker_target_function() {

    print_info "[*] Sending request to HackerTarget ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    curl -s "https://api.hackertarget.com/hostsearch/?q=$TARGET" > "$RAW_TMP" &
    local ht_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $ht_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$ht_pid"
    printf "%b" "$BRIGHT_WHITE"
    echo
    wait "$ht_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] curl failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local PARSED_TMP
    PARSED_TMP=$(mktemp)

    cut -d',' -f1 "$RAW_TMP" | sort -u > "$PARSED_TMP"

    local response=$(cat "$PARSED_TMP")

    if [[ ! -s "$PARSED_TMP" ]] || [[ "$response" == *"error"* ]] || [[ "$response" == *"API count"* ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] HackerTarget reverse IP: no response or API limit reached"
        echo
        rm -f "$PARSED_TMP"
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|hackertarget\n" "$sub"
    done < "$PARSED_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$PARSED_TMP"
    rm -f "$RAW_TMP"
}

security_trails_function() {
    
    if [[ -z "$SECTRAILS_API_KEY" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[*] Security Trails API key not configured. Skipping..."
        print_info "[*] To provide SecTrails API key: lib/constants.bash -> Add your API key in SECTRAILS_API_KEY variable"
        printf "%b" "$BRIGHT_WHITE"
        return 0
    fi

    print_info "[*] Sending request to Security Trails ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    curl -s --connect-timeout 8 --max-time 20 -H "apikey: $SECTRAILS_API_KEY" "https://api.securitytrails.com/v1/domain/${TARGET}/subdomains" > "$RAW_TMP" &
    local st_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $st_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$st_pid"
    printf "%b" "$BRIGHT_WHITE"
    echo
    wait "$st_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] curl failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    if jq -e '.message' "$RAW_TMP" >/dev/null 2>&1
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Security Trails API returned an error."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local PARSED_TMP
    PARSED_TMP=$(mktemp)

    jq -r --arg d "$TARGET" '.subdomains[]? | "\(.)."+$d' "$RAW_TMP" | sort -u > "$PARSED_TMP"

    if [[ ! -s "$PARSED_TMP" ]]
    then
        print_info "[*] Security Trails returned no passive DNS records."
        rm -f "$PARSED_TMP"
        rm -f "$RAW_TMP"
        return 0
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|securitytrails\n" "$sub"
    done < "$PARSED_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$PARSED_TMP"
    rm -f "$RAW_TMP"
}

otx_function() {

    if [[ -z "$OTX_API_KEY" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[*] OTX API key not configured. Skipping..."
        print_info "[*] To provide OTX API key: lib/constants.bash -> Add your API key in OTX_API_KEY variable"
        printf "%b" "$BRIGHT_WHITE"
        return 0
    fi

    print_info "[*] Sending request to OTX-AlienVault ..."
    local RAW_TMP
    RAW_TMP=$(mktemp)

    curl -s --connect-timeout 8 --max-time 20 -H "X-OTX-API-KEY: $OTX_API_KEY" "https://otx.alienvault.com/api/v1/indicators/domain/${TARGET}/passive_dns" > "$RAW_TMP" &
    local otx_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $otx_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$otx_pid"
    printf "%b" "$BRIGHT_WHITE"
    echo
    wait "$otx_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] curl failed."
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    if grep -qiE '"error"|"detail"|"credentials were not provided"' "$RAW_TMP"
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] OTX: request failed or invalid API key"
        echo
        rm -f "$RAW_TMP"
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local PARSED_TMP
    PARSED_TMP=$(mktemp)

    jq -r '.passive_dns[]?.hostname' "$RAW_TMP" | sort -u > "$PARSED_TMP"

    if [[ ! -s "$PARSED_TMP" ]]
    then
        print_info "[*] OTX returned no passive DNS records."
        rm -f "$PARSED_TMP"
        rm -f "$RAW_TMP"
        return 0
    fi

    while IFS= read -r sub
    do
        [[ -z "$sub" ]] && continue
        printf "%s|otx\n" "$sub"
    done < "$PARSED_TMP" >> "$SUB_DISCOVERY_TMPFILE"
    rm -f "$PARSED_TMP"
    rm -f "$RAW_TMP"
}
