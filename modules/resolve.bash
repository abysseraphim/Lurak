#!/usr/bin/env bash

name_resolution() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<EOF


    ███╗   ██╗ █████╗ ███╗   ███╗███████╗                                            
    ████╗  ██║██╔══██╗████╗ ████║██╔════╝                                            
    ██╔██╗ ██║███████║██╔████╔██║█████╗                                              
    ██║╚██╗██║██╔══██║██║╚██╔╝██║██╔══╝                                              
    ██║ ╚████║██║  ██║██║ ╚═╝ ██║███████╗                                            
    ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝                                            
                                                                                     
    ██████╗ ███████╗███████╗ ██████╗ ██╗     ██╗   ██╗████████╗██╗ ██████╗ ███╗   ██╗
    ██╔══██╗██╔════╝██╔════╝██╔═══██╗██║     ██║   ██║╚══██╔══╝██║██╔═══██╗████╗  ██║
    ██████╔╝█████╗  ███████╗██║   ██║██║     ██║   ██║   ██║   ██║██║   ██║██╔██╗ ██║
    ██╔══██╗██╔══╝  ╚════██║██║   ██║██║     ██║   ██║   ██║   ██║██║   ██║██║╚██╗██║
    ██║  ██║███████╗███████║╚██████╔╝███████╗╚██████╔╝   ██║   ██║╚██████╔╝██║ ╚████║
    ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝    ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
                                                                                 
                                                                                                                                            
EOF

    printf "%b" "$BRIGHT_WHITE"

    printf "%b" "$BRIGHT_PURPLE"

    if ! require_tool dnsx shuffledns jq
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

    if [[ ! -f "$TARGET_DIR/$TARGET.subdomain.discovery.unique" ]] || [[ ! -s "$TARGET_DIR/$TARGET.subdomain.discovery.unique" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No subdomain discovery results found. make sure to run option 7 (subdomain discovery) first..."
        printf "%b" "$BRIGHT_WHITE"
        return 0
    fi

    local wc_detection
    read -r -p "    Enable Wildcard Detection? (y/N)> " wc_detection

    local INPUT_FILE="$TARGET_DIR/$TARGET.subdomain.discovery.unique"
    local OUTPUT_FILE=$(mktemp) || return 12

    if [[ "${wc_detection,,}" != "y" ]]
    then
        dnsx -silent -l "$INPUT_FILE" 2>/dev/null 1> "$OUTPUT_FILE" &
        local dnsx_pid=$!

        printf "%b" "$BRIGHT_MAGENTA"
        print_info "[*] Process PID: $dnsx_pid"
        echo
        printf "%b" "$BRIGHT_WHITE"

        show_spinner "$dnsx_pid"
        printf "%b" "$BRIGHT_WHITE"
        echo
        wait "$dnsx_pid"

        if [[ $? -ne 0 ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] dnsx failed."
            echo
            printf "%b" "$BRIGHT_WHITE"
            return 12
        fi

        if [[ ! -s "$OUTPUT_FILE" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] No subdomains resolved."
            printf "%b" "$BRIGHT_WHITE"
            return 12
        fi

    else
        shuffledns -list "$INPUT_FILE" -d "$TARGET" -r "$WORDLISTS_DIR/resolvers.txt" -m "$(command -v massdns)" -mode resolve -silent > "$OUTPUT_FILE" &
        local shuffle_pid=$!

        printf "%b" "$BRIGHT_MAGENTA"
        print_info "[*] Process PID: $shuffle_pid"
        echo
        printf "%b" "$BRIGHT_WHITE"

        show_spinner "$shuffle_pid"
        printf "%b" "$BRIGHT_WHITE"
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

        if [[ ! -s "$OUTPUT_FILE" ]]
        then
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] No subdomains resolved."
            printf "%b" "$BRIGHT_WHITE"
            return 12
        fi
    fi

    sort -u "$OUTPUT_FILE" -o "$OUTPUT_FILE"

    local total
    total=$(wc -l < "$OUTPUT_FILE")

    echo
    print_info "[+] Name Resolution Summary:"
    echo
    printf "%b" "$BRIGHT_GREEN"
    print_info "    Total resolved subdomains : $total"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local file_name
    file_name="$TARGET.name.resolution.result"

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
}' total="$total" "$OUTPUT_FILE")
    ]
}
EOF
    )

    save_output "$file_data" "$file_name"

    rm -f "$OUTPUT_FILE"

    echo
    print_info "[*] Results saved."
    sleep 2
    echo

    print_info "[*] Creating unique resolved subs file...."
    sleep 2

    jq -r '.results[].subdomain' "$TARGET_DIR/$file_name" | sort -u > "$TARGET_DIR/$TARGET.name.resolution.unique"
    printf "%b" "$BRIGHT_CYAN"
    print_info "[!!] If you want a unique list of resolved subdomains to pipe into other tools, you can find it here:"
    printf "%b" "$BRIGHT_YELLOW"
    print_info "[>] $TARGET_DIR/$TARGET.name.resolution.unique"
    printf "%b" "$RESET"

}
