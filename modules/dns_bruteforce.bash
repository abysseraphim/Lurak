#!/usr/bin/env bash

dns_brute_force() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ██████╗ ███╗   ██╗███████╗                                                             
    ██╔══██╗████╗  ██║██╔════╝                                                             
    ██║  ██║██╔██╗ ██║███████╗                                                             
    ██║  ██║██║╚██╗██║╚════██║                                                             
    ██████╔╝██║ ╚████║███████║                                                             
    ╚═════╝ ╚═╝  ╚═══╝╚══════╝                                                             
                                                                                           
    ██████╗ ██████╗ ██╗   ██╗████████╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗███████╗
    ██╔══██╗██╔══██╗██║   ██║╚══██╔══╝██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝
    ██████╔╝██████╔╝██║   ██║   ██║   █████╗      █████╗  ██║   ██║██████╔╝██║     █████╗  
    ██╔══██╗██╔══██╗██║   ██║   ██║   ██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║     ██╔══╝  
    ██████╔╝██║  ██║╚██████╔╝   ██║   ███████╗    ██║     ╚██████╔╝██║  ██║╚██████╗███████╗
    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝
                                                                                       

EOF

    print_info "[!] WARNING: DNS brute-force is a long-running process."
    print_info "[!] A large wordlist can make this module run for several hours."
    print_info "[!] Do NOT interrupt the process."
    print_info "[!] Running Lurak inside tmux or screen is strongly recommended."
    echo
    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool shuffledns massdns subfinder dnsx dnsgen anew
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

    mkdir -p "$TARGET_DIR/DnsBruteFiles" || {
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Failed to create working directory."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    }
    local DNS_BRUTE_FOLDER="$TARGET_DIR/DnsBruteFiles"

    # Large static subdomain wordlist used for the initial brute-force pass.
    local STATIC_WORDLIST="$WORDLISTS_DIR/subdomains-merged.txt"

    # Small/short subdomain wordlist (common names, 3-4 chars, etc)
    local CRUNCH_WORDLIST="$WORDLISTS_DIR/subsCRUNCH.txt"

    # Wordlist used by dnsgen to generate permutation candidates. (do not use a large wordlist here or dns bruteforce will last forever.)
    local PERMUTATION_WORDLIST="$WORDLISTS_DIR/words-merged.txt"

    ## DNS resolver list used by shuffledns/massdns. if possible, put company name servers address in this file, otherwise use good resolvers.
    local RESOLVERS="$WORDLISTS_DIR/resolvers.txt"

    for file in "$STATIC_WORDLIST" "$CRUNCH_WORDLIST" "$PERMUTATION_WORDLIST" "$RESOLVERS"
    do
        if [[ ! -f "$file" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Required file not found: $file"
            printf "%b" "$BRIGHT_WHITE"
            return 12
        fi

        if [[ ! -s "$file" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Required file is empty: $file"
            printf "%b" "$BRIGHT_WHITE"
            return 12
        fi
    done

    # Files we are going to create
    local WORDLIST_FILE="$DNS_BRUTE_FOLDER/$TARGET.wordlist"
    local BRUTE_FILE="$DNS_BRUTE_FOLDER/$TARGET.dns_brute"
    local DNSGEN_FILE="$DNS_BRUTE_FOLDER/$TARGET.dns_gen"

    print_info "[*] Cleaning previous files..."
    rm -f "$WORDLIST_FILE" "$BRUTE_FILE" "$DNSGEN_FILE"

    print_info "[*] Generating static wordlist..."

    awk -v domain="$TARGET" '{print $0 "." domain}' "$STATIC_WORDLIST" > "$WORDLIST_FILE"

    print_info "[*] Appending crunch wordlist..."

    awk -v domain="$TARGET" '{print $0 "." domain}' "$CRUNCH_WORDLIST" >> "$WORDLIST_FILE"

    if [[ ! -s "$WORDLIST_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Failed to generate wordlist."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local word_count
    word_count=$(wc -l < "$WORDLIST_FILE")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Wordlist generated."
    print_info "    Total candidates : $word_count"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # static
    print_info "[*] Running shuffledns (static brute-force)..."

    shuffledns -list "$WORDLIST_FILE" -d "$TARGET" -r "$RESOLVERS" -m "$(command -v massdns)" -mode resolve -t 50 -silent > "$BRUTE_FILE" &
    local shuffle_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $shuffle_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$shuffle_pid"
    echo
    wait "$shuffle_pid"
    
    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] shuffledns failed."
        echo
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi
    
    if [[ ! -s "$BRUTE_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No subdomains resolved."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local resolved_count
    resolved_count=$(wc -l < "$BRUTE_FILE")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Static brute-force finished."
    print_info "    Resolved subdomains : $resolved_count"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # subfinder + dnsx
    print_info "[*] Running subfinder + dnsx..."

    subfinder -silent -d "$TARGET" -all 2>/dev/null | dnsx -silent | anew "$BRUTE_FILE" >/dev/null &
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
        print_info "[!] subfinder/dnsx failed."
        echo
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    resolved_count=$(wc -l < "$BRUTE_FILE")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Passive enumeration finished."
    print_info "    Total resolved subdomains : $resolved_count"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # permutation wordlist generation
    print_info "[*] Running dnsgen..."

    dnsgen -w "$PERMUTATION_WORDLIST" "$BRUTE_FILE" > "$DNSGEN_FILE" &
    local dnsgen_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $dnsgen_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$dnsgen_pid"
    echo
    wait "$dnsgen_pid"

    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] dnsgen failed."
        echo
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    if [[ ! -s "$DNSGEN_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] dnsgen generated no candidates."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    local generated_count
    generated_count=$(wc -l < "$DNSGEN_FILE")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] dnsgen finished."
    print_info "    Generated candidates : $generated_count"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # dynamic
    print_info "[*] Running shuffledns on dnsgen permutations..."

    shuffledns -list "$DNSGEN_FILE" -d "$TARGET" -r "$RESOLVERS" -m "$(command -v massdns)" -mode resolve -t 50 -silent >> "$BRUTE_FILE" &
    local brute2_pid=$!

    printf "%b" "$BRIGHT_MAGENTA"
    print_info "[*] Process PID: $brute2_pid"
    echo
    printf "%b" "$BRIGHT_WHITE"

    show_spinner "$brute2_pid"
    echo

    wait "$brute2_pid"
    
    if [[ $? -ne 0 ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Permutation brute-force failed."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    if [[ ! -s "$BRUTE_FILE" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No subdomains resolved."
        printf "%b" "$BRIGHT_WHITE"
        return 12
    fi

    sort -u "$BRUTE_FILE" -o "$BRUTE_FILE"

    resolved_count=$(wc -l < "$BRUTE_FILE")

    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] DNS brute-force completed."
    print_info "    Total resolved subdomains : $resolved_count"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local total
    total=$(wc -l < "$BRUTE_FILE")

    echo
    print_info "[+] DNS Brute Force Summary:"
    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "    Total resolved subdomains : $total"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local PREVIEW_COUNT=20

    print_info "[*] Showing first $PREVIEW_COUNT results:"
    echo
    printf "%b" "$BRIGHT_GREEN"
    head -n "$PREVIEW_COUNT" "$BRUTE_FILE" | awk '{printf "    %s\n",$0}'
    printf "%b" "$BRIGHT_WHITE"

    if [[ "$total" -gt "$PREVIEW_COUNT" ]]
    then
        echo
        print_info "[*] Showing $PREVIEW_COUNT/$total records only."
        print_info "[*] Full results are saved in JSON."
    fi

    local file_name
    file_name="$TARGET.dns.bruteforce.result"

    echo
    print_info "[*] Saving results to: $TARGET_DIR/$file_name"
    echo

    local file_data
    file_data=$(cat <<EOF
{
    "target": "$TARGET",
    "summary": {
        "resolved_subdomains": $total
    },
    "results": [
$(awk '
{
    printf "        {\n"
    printf "            \"subdomain\": \"%s\"\n",$0
    printf "        }%s\n",(NR==total?"":",")
}' total="$total" "$BRUTE_FILE")
    ]
}
EOF
    )

    save_output "$file_data" "$file_name"

    echo
    print_info "[*] Results saved."

}
