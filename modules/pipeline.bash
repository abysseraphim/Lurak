#!/usr/bin/env bash

smart_pipeline() {

    clear
    printf "%b" "$BRIGHT_PURPLE"
    cat <<BANNER


    ██████╗ ██╗██████╗ ███████╗██╗     ██╗███╗   ██╗███████╗
    ██╔══██╗██║██╔══██╗██╔════╝██║     ██║████╗  ██║██╔════╝
    ██████╔╝██║██████╔╝█████╗  ██║     ██║██╔██╗ ██║█████╗
    ██╔═══╝ ██║██╔═══╝ ██╔══╝  ██║     ██║██║╚██╗██║██╔══╝
    ██║     ██║██║     ███████╗███████╗██║██║ ╚████║███████╗
    ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝

BANNER
    printf "%b" "$BRIGHT_WHITE"

    local PIPELINE_DIR="$TARGET_DIR/pipeline"
    mkdir -p "$PIPELINE_DIR"

    print_info "[*] Target     : $TARGET"
    print_info "[*] Type       : $TARGET_TYPE"
    print_info "[*] Output dir : $PIPELINE_DIR"
    echo

    case "$TARGET_TYPE" in
        DOMAIN) _pipeline_domain "$PIPELINE_DIR" ;;
        IP)     _pipeline_ip     "$PIPELINE_DIR" ;;
        CIDR)   _pipeline_cidr   "$PIPELINE_DIR" ;;
        *)
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Unknown target type: $TARGET_TYPE"
            printf "%b" "$RESET"
            return 1
            ;;
    esac

    printf "%b" "$BRIGHT_GREEN"
    echo
    print_info "[+] Pipeline finished."
    print_info "[+] Results saved in: $PIPELINE_DIR"
    printf "%b" "$RESET"
}

# DOMAIN
_pipeline_domain() {

    local DIR="$1"

    #Step 1: Passive Subdomain Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 1/7 — Passive Subdomain Discovery"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local SUBS_TMP
    SUBS_TMP=$(mktemp)

    _pipeline_subfinder    "$SUBS_TMP"
    _pipeline_crtsh        "$SUBS_TMP"
    _pipeline_wayback      "$SUBS_TMP"
    _pipeline_gau          "$SUBS_TMP"
    _pipeline_hackertarget "$SUBS_TMP"
    _pipeline_sectrails    "$SUBS_TMP"
    _pipeline_otx          "$SUBS_TMP"

    sort -u "$SUBS_TMP" -o "$SUBS_TMP"
    cp "$SUBS_TMP" "$DIR/subs.txt"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Total unique subdomains: $(wc -l < "$SUBS_TMP")  →  $DIR/subs.txt"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # Step 2: DNS Brute Force (static only)

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 2/7 — DNS Brute Force"
    printf "%b" "$BRIGHT_WHITE"
    echo

    if require_tool shuffledns massdns 2>/dev/null
    then
        local BRUTE_RAW BRUTE_RESOLVED
        BRUTE_RAW=$(mktemp)
        BRUTE_RESOLVED=$(mktemp)

        # generate candidates: wordlist entries appended to target domain
        while IFS= read -r word
        do
            echo "${word}.${TARGET}"
        done < "$WORDLISTS_DIR/subdomains-merged.txt" >> "$BRUTE_RAW"

        # resolve candidates with shuffledns
        shuffledns \
            -list "$BRUTE_RAW" \
            -r "$WORDLISTS_DIR/resolvers.txt" \
            -m "$(command -v massdns)" \
            -mode resolve \
            -silent 2>/dev/null > "$BRUTE_RESOLVED" &

        local brute_pid=$!
        show_spinner "$brute_pid"
        wait "$brute_pid"

        sort -u "$BRUTE_RESOLVED" -o "$BRUTE_RESOLVED"

        local brute_count
        brute_count=$(wc -l < "$BRUTE_RESOLVED")

        # merge into main subs list
        cat "$BRUTE_RESOLVED" >> "$SUBS_TMP"
        sort -u "$SUBS_TMP" -o "$SUBS_TMP"
        cp "$SUBS_TMP" "$DIR/subs.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Brute forced: $brute_count  →  merged into $DIR/subs.txt"
        printf "%b" "$BRIGHT_WHITE"

        rm -f "$BRUTE_RAW" "$BRUTE_RESOLVED"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] shuffledns or massdns not found, skipping brute force"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 3: Name Resolution

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 3/7 — Name Resolution"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local LIVE_TMP
    LIVE_TMP=$(mktemp)

    if require_tool dnsx 2>/dev/null
    then
        dnsx -silent -l "$SUBS_TMP" 2>/dev/null > "$LIVE_TMP" &

        local dnsx_pid=$!
        show_spinner "$dnsx_pid"
        wait "$dnsx_pid"

        sort -u "$LIVE_TMP" -o "$LIVE_TMP"
        cp "$LIVE_TMP" "$DIR/live_subs.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Live subdomains: $(wc -l < "$LIVE_TMP")  →  $DIR/live_subs.txt"
        printf "%b" "$BRIGHT_WHITE"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] dnsx not found, falling back to unresolved list"
        printf "%b" "$BRIGHT_WHITE"
        cp "$SUBS_TMP" "$LIVE_TMP"
        cp "$LIVE_TMP" "$DIR/live_subs.txt"
    fi

    rm -f "$SUBS_TMP"
    echo

    # Step 4: HTTP Service Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 4/7 — HTTP Service Discovery"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local HTTP_OUT="$DIR/http_services.txt"
    : > "$HTTP_OUT"

    if [[ -s "$LIVE_TMP" ]] && require_tool naabu curl 2>/dev/null
    then
        local PORTS_TMP
        PORTS_TMP=$(mktemp)

        naabu \
            -silent \
            -list "$LIVE_TMP" \
            -p 80,81,443,591,593,8000,8008,8080,8081,8088,8443,8888,9000,9090 \
            2>/dev/null > "$PORTS_TMP" &

        local naabu_pid=$!
        show_spinner "$naabu_pid"
        wait "$naabu_pid"

        # validate each host:port with curl — naabu only confirms tcp open
        local entry host port scheme status server
        while IFS= read -r entry
        do
            host="${entry%:*}"
            port="${entry#*:}"

            case "$port" in
                443|8443) scheme="https" ;;
                *)        scheme="http"  ;;
            esac

            status=$(curl -ksSI --max-time 5 "$scheme://$host:$port" 2>/dev/null \
                | awk 'NR==1 {print $2}' | tr -d '\r\n')

            [[ -z "$status" ]] && continue

            server=$(curl -ksSI --max-time 5 "$scheme://$host:$port" 2>/dev/null \
                | awk -F': ' 'tolower($1)=="server" {print $2; exit}' | tr -d '\r\n')

            printf "%b" "$BRIGHT_CYAN"
            print_info "[+] $scheme://$host:$port  [$status]  ${server:+$server}"
            printf "%b" "$BRIGHT_WHITE"
            echo "$scheme://$host:$port  $status  ${server}" >> "$HTTP_OUT"
        done < "$PORTS_TMP"

        rm -f "$PORTS_TMP"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] HTTP services: $(wc -l < "$HTTP_OUT")  →  $HTTP_OUT"
        printf "%b" "$BRIGHT_WHITE"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] naabu or curl not found, or no live subs — skipping"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 5: SSL Certificate Inspection

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 5/7 — SSL Certificate Inspection"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local CERT_OUT="$DIR/certs.txt"
    : > "$CERT_OUT"

    if [[ -s "$LIVE_TMP" ]] && require_tool openssl 2>/dev/null
    then
        local host cert_info
        while IFS= read -r host
        do
            cert_info=$(openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
                | openssl x509 -noout -subject -issuer -dates 2>/dev/null)

            [[ -z "$cert_info" ]] && continue

            printf "%b" "$BRIGHT_CYAN"
            print_info "[+] $host"
            printf "%b" "$BRIGHT_WHITE"
            printf "%s\n%s\n\n" "$host" "$cert_info" >> "$CERT_OUT"
        done < "$LIVE_TMP"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Cert results  →  $CERT_OUT"
        printf "%b" "$BRIGHT_WHITE"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] openssl not found or no live subs — skipping"
        printf "%b" "$BRIGHT_WHITE"
    fi

    rm -f "$LIVE_TMP"
    echo

    # Step 6: Domain Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 6/7 — Domain Discovery"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local DOMAIN_OUT="$DIR/domain_discovery.txt"
    : > "$DOMAIN_OUT"

    _pipeline_cert_san   >> "$DOMAIN_OUT"
    _pipeline_reverse_ip >> "$DOMAIN_OUT"
    _pipeline_ptr        >> "$DOMAIN_OUT"

    sort -u "$DOMAIN_OUT" -o "$DOMAIN_OUT"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Domains discovered: $(wc -l < "$DOMAIN_OUT")  →  $DOMAIN_OUT"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # Step 7: ASN Recon

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 7/7 — ASN Recon"
    printf "%b" "$BRIGHT_WHITE"
    echo

    _pipeline_asn "$DIR/asn.txt"
    echo
}

# IP
_pipeline_ip() {

    local DIR="$1"

    # Step 1: ASN Recon

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 1/5 — ASN Recon"
    printf "%b" "$BRIGHT_WHITE"
    echo

    _pipeline_asn_from_ip "$TARGET" "$DIR/asn.txt"
    echo

    # Step 2: CIDR Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 2/5 — CIDR Discovery"
    printf "%b" "$BRIGHT_WHITE"
    echo

    if require_tool whois 2>/dev/null
    then
        local cidr_range org country
        cidr_range=$(whois "$TARGET" 2>/dev/null \
            | awk '/^(route|CIDR):[[:space:]]/ {print $2; exit}')

        if [[ -n "$cidr_range" ]]
        then
            org=$(whois "$TARGET" 2>/dev/null \
                | awk -F': ' '/^(org-name|OrgName|organisation|owner):/ {print $2; exit}' | xargs)
            country=$(whois "$TARGET" 2>/dev/null \
                | awk -F': ' '/^(country|Country):/ {print $2; exit}' | xargs)

            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] CIDR    : $cidr_range"
            [[ -n "$org" ]]     && print_info "[+] Org     : $org"
            [[ -n "$country" ]] && print_info "[+] Country : $country"
            printf "%b" "$BRIGHT_WHITE"

            {
                echo "CIDR    : $cidr_range"
                [[ -n "$org" ]]     && echo "Org     : $org"
                [[ -n "$country" ]] && echo "Country : $country"
            } > "$DIR/cidr.txt"

            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] CIDR info  →  $DIR/cidr.txt"
            printf "%b" "$BRIGHT_WHITE"
        else
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] Could not determine CIDR range"
            printf "%b" "$BRIGHT_WHITE"
        fi
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] whois not found, skipping CIDR discovery"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 3: Port Scan

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 3/5 — Port Scan"
    printf "%b" "$BRIGHT_WHITE"
    echo

    if require_tool naabu 2>/dev/null
    then
        local PORTS_TMP
        PORTS_TMP=$(mktemp)

        naabu -silent -host "$TARGET" -p - 2>/dev/null > "$PORTS_TMP" &

        local naabu_pid=$!
        show_spinner "$naabu_pid"
        wait "$naabu_pid"

        sort -u "$PORTS_TMP" -o "$PORTS_TMP"
        cp "$PORTS_TMP" "$DIR/open_ports.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Open ports: $(wc -l < "$PORTS_TMP")  →  $DIR/open_ports.txt"
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$PORTS_TMP"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] naabu not found, skipping port scan"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 4: SSL Certificate Inspection

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 4/5 — SSL Certificate Inspection"
    printf "%b" "$BRIGHT_WHITE"
    echo

    if require_tool openssl 2>/dev/null
    then
        local cert_info
        cert_info=$(openssl s_client -connect "$TARGET:443" </dev/null 2>/dev/null \
            | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null)

        if [[ -n "$cert_info" ]]
        then
            echo "$cert_info" > "$DIR/certs.txt"
            printf "%b" "$BRIGHT_GREEN"
            print_info "[+] Cert info  →  $DIR/certs.txt"
            printf "%b" "$BRIGHT_WHITE"
        else
            printf "%b" "$BRIGHT_PURPLE"
            print_info "[!] No certificate found on $TARGET:443"
            printf "%b" "$BRIGHT_WHITE"
        fi
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] openssl not found, skipping"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 5: Domain Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 5/5 — Domain Discovery"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local DOMAIN_OUT="$DIR/domain_discovery.txt"
    : > "$DOMAIN_OUT"

    _pipeline_cert_san   >> "$DOMAIN_OUT"
    _pipeline_reverse_ip >> "$DOMAIN_OUT"
    _pipeline_ptr        >> "$DOMAIN_OUT"

    sort -u "$DOMAIN_OUT" -o "$DOMAIN_OUT"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] Domains discovered: $(wc -l < "$DOMAIN_OUT")  →  $DOMAIN_OUT"
    printf "%b" "$BRIGHT_WHITE"
    echo
}

# CIDR
_pipeline_cidr() {

    local DIR="$1"

    # Step 1: CIDR Info

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 1/4 — CIDR Info"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # use network address only for whois — not the broadcast/mask
    local network_ip
    network_ip=$(echo "$TARGET" | cut -d'/' -f1)

    if require_tool whois 2>/dev/null
    then
        local org country registry
        org=$(whois "$network_ip" 2>/dev/null \
            | awk -F': ' '/^(org-name|OrgName|organisation|owner):/ {print $2; exit}' | xargs)
        country=$(whois "$network_ip" 2>/dev/null \
            | awk -F': ' '/^(country|Country):/ {print $2; exit}' | xargs)
        registry=$(whois "$network_ip" 2>/dev/null \
            | awk -F': ' '/^(source|Source):/ {print $2; exit}' | xargs)

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] CIDR     : $TARGET"
        [[ -n "$org" ]]      && print_info "[+] Org      : $org"
        [[ -n "$country" ]]  && print_info "[+] Country  : $country"
        [[ -n "$registry" ]] && print_info "[+] Registry : $registry"
        printf "%b" "$BRIGHT_WHITE"

        {
            echo "CIDR     : $TARGET"
            [[ -n "$org" ]]      && echo "Org      : $org"
            [[ -n "$country" ]]  && echo "Country  : $country"
            [[ -n "$registry" ]] && echo "Registry : $registry"
        } > "$DIR/cidr.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] CIDR info  →  $DIR/cidr.txt"
        printf "%b" "$BRIGHT_WHITE"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] whois not found, skipping CIDR info"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 2: ASN Recon

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 2/4 — ASN Recon"
    printf "%b" "$BRIGHT_WHITE"
    echo

    # network_ip is x.x.x.0 — use first usable host (+1 on last octet)
    local first_usable_ip
    local last_octet="${network_ip##*.}"
    local prefix="${network_ip%.*}"
    first_usable_ip="${prefix}.$((last_octet + 1))"

    _pipeline_asn_from_ip "$first_usable_ip" "$DIR/asn.txt"
    echo

    # Step 3: Port Scan
    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 3/4 — CIDR Port Scan"
    printf "%b" "$BRIGHT_WHITE"
    echo

    if require_tool naabu 2>/dev/null
    then
        local PORTS_TMP
        PORTS_TMP=$(mktemp)

        naabu \
            -silent \
            -host "$TARGET" \
            -p 22,80,81,443,8080,8443,8888,9090 \
            2>/dev/null > "$PORTS_TMP" &

        local naabu_pid=$!
        show_spinner "$naabu_pid"
        wait "$naabu_pid"

        sort -u "$PORTS_TMP" -o "$PORTS_TMP"
        cp "$PORTS_TMP" "$DIR/open_ports.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Open ports: $(wc -l < "$PORTS_TMP")  →  $DIR/open_ports.txt"
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$PORTS_TMP"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] naabu not found, skipping port scan"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo

    # Step 4: Service Discovery

    printf "%b" "$BRIGHT_PURPLE"
    print_info "[*] Step 4/4 — Service Discovery (HTTP/HTTPS/SSH)"
    printf "%b" "$BRIGHT_WHITE"
    echo

    local SERVICE_OUT="$DIR/services.txt"
    : > "$SERVICE_OUT"

    if [[ -s "$DIR/open_ports.txt" ]] && require_tool curl nc 2>/dev/null
    then
        local entry ip port
        while IFS= read -r entry
        do
            ip="${entry%:*}"
            port="${entry#*:}"

            case "$port" in
                22)
                    local banner
                    banner=$(nc -nw 3 "$ip" "$port" 2>/dev/null | head -n1 | tr -d '\r\n')
                    [[ "$banner" != SSH-* ]] && continue
                    printf "%b" "$BRIGHT_CYAN"
                    print_info "[+] $ip:$port  SSH  $banner"
                    printf "%b" "$BRIGHT_WHITE"
                    echo "$ip:$port  SSH  $banner" >> "$SERVICE_OUT"
                    ;;
                443|8443)
                    local status server
                    status=$(curl -ksSI --max-time 5 "https://$ip:$port" 2>/dev/null \
                        | awk 'NR==1 {print $2}' | tr -d '\r\n')
                    [[ -z "$status" ]] && continue
                    server=$(curl -ksSI --max-time 5 "https://$ip:$port" 2>/dev/null \
                        | awk -F': ' 'tolower($1)=="server" {print $2; exit}' | tr -d '\r\n')
                    printf "%b" "$BRIGHT_CYAN"
                    print_info "[+] $ip:$port  HTTPS  $status  ${server:+[$server]}"
                    printf "%b" "$BRIGHT_WHITE"
                    echo "$ip:$port  HTTPS  $status  ${server:+[$server]}" >> "$SERVICE_OUT"
                    ;;
                *)
                    local status server
                    status=$(curl -sSI --max-time 5 "http://$ip:$port" 2>/dev/null \
                        | awk 'NR==1 {print $2}' | tr -d '\r\n')
                    [[ -z "$status" ]] && continue
                    server=$(curl -sSI --max-time 5 "http://$ip:$port" 2>/dev/null \
                        | awk -F': ' 'tolower($1)=="server" {print $2; exit}' | tr -d '\r\n')
                    printf "%b" "$BRIGHT_CYAN"
                    print_info "[+] $ip:$port  HTTP  $status  ${server:+[$server]}"
                    printf "%b" "$BRIGHT_WHITE"
                    echo "$ip:$port  HTTP  $status  ${server:+[$server]}" >> "$SERVICE_OUT"
                    ;;
            esac
        done < "$DIR/open_ports.txt"

        printf "%b" "$BRIGHT_GREEN"
        print_info "[+] Services found: $(wc -l < "$SERVICE_OUT")  →  $SERVICE_OUT"
        printf "%b" "$BRIGHT_WHITE"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] No open ports or curl/nc missing, skipping service discovery"
        printf "%b" "$BRIGHT_WHITE"
    fi

    echo
}

# SHARED HELPERS
_pipeline_asn() {

    local OUT="$1"

    if ! require_tool whois 2>/dev/null
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] whois not found, skipping ASN"
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    local ip
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        ip="$TARGET"
    elif resolve_target_to_ip
    then
        ip="$TARGET_IP"
    else
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Could not resolve $TARGET to IP, skipping ASN"
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    _pipeline_asn_from_ip "$ip" "$OUT"
}

_pipeline_asn_from_ip() {

    local ip="$1"
    local OUT="$2"

    if ! require_tool whois 2>/dev/null
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] whois not found, skipping ASN"
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    local asn
    asn=$(whois -h whois.cymru.com " -v $ip" 2>/dev/null | tail -n +2 | awk '{print $1}')

    if [[ -z "$asn" ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] Could not determine ASN for $ip"
        printf "%b" "$BRIGHT_WHITE"
        return
    fi

    local asn_data route_data name des ipv4_count ipv6_count
    asn_data=$(whois -h whois.radb.net "AS$asn" 2>/dev/null)
    route_data=$(whois -h whois.radb.net -i origin "AS$asn" 2>/dev/null)
    name=$(echo "$asn_data" | awk -F: '/^as-name/ {print $2; exit}' | xargs)
    des=$(echo "$asn_data"  | awk -F: '/^descr/   {print $2; exit}' | xargs)
    ipv4_count=$(echo "$route_data" | awk '/^route:/  {print $2}' | sort -u | wc -l)
    ipv6_count=$(echo "$route_data" | awk '/^route6:/ {print $2}' | sort -u | wc -l)

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] ASN  : AS$asn"
    [[ -n "$name" ]] && print_info "[+] Name : $name"
    [[ -n "$des" ]]  && print_info "[+] Descr: $des"
    print_info "[+] IPv4 prefixes: $ipv4_count"
    print_info "[+] IPv6 prefixes: $ipv6_count"
    printf "%b" "$BRIGHT_WHITE"

    {
        echo "ASN            : AS$asn"
        [[ -n "$name" ]] && echo "Name           : $name"
        [[ -n "$des" ]]  && echo "Descr          : $des"
        echo "IPv4 prefixes  : $ipv4_count"
        echo "IPv6 prefixes  : $ipv6_count"
    } > "$OUT"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] ASN info  →  $OUT"
    printf "%b" "$BRIGHT_WHITE"
}

_pipeline_cert_san() {

    require_tool openssl 2>/dev/null || return

    local ip
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        ip="$TARGET"
    elif resolve_target_to_ip
    then
        ip="$TARGET_IP"
    else
        return
    fi

    openssl s_client -connect "$ip:443" </dev/null 2>/dev/null \
        | openssl x509 -noout -text 2>/dev/null \
        | grep -A1 "Subject Alternative Name" \
        | tail -n1 \
        | tr ',' '\n' \
        | sed 's/.*DNS://; s/.*IP Address://' \
        | tr -d ' ' \
        | grep -v '^\*' \
        | grep -v '^[0-9]' \
        | grep -v '^$'
}

_pipeline_reverse_ip() {

    local ip
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        ip="$TARGET"
    elif resolve_target_to_ip
    then
        ip="$TARGET_IP"
    else
        return
    fi

    local response
    response=$(curl -sf --max-time 15 "https://api.hackertarget.com/reverseiplookup/?q=$ip" 2>/dev/null)

    [[ -z "$response" ]] && return
    [[ "$response" == *"error"*     ]] && return
    [[ "$response" == *"API count"* ]] && return

    echo "$response"
}

_pipeline_ptr() {

    local ip
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        ip="$TARGET"
    elif resolve_target_to_ip
    then
        ip="$TARGET_IP"
    else
        return
    fi

    dig +short -x "$ip" 2>/dev/null | head -n1 | sed 's/\.$//'
}

# PASSIVE SUBDOMAIN SOURCES
_pipeline_subfinder() {

    local OUT="$1"
    require_tool subfinder 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    subfinder -silent -d "$TARGET" -all 2>/dev/null > "$TMP" &
    local pid=$!
    show_spinner "$pid"
    wait "$pid"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] subfinder      : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_crtsh() {

    local OUT="$1"
    require_tool psql 2>/dev/null || return

    local query="SELECT ci.NAME_VALUE FROM certificate_and_identities ci WHERE plainto_tsquery('certwatch', '$TARGET') @@ identities(ci.CERTIFICATE)"
    local TMP
    TMP=$(mktemp)

    local attempt
    for attempt in 1 2 3
    do
        echo "$query" \
            | psql -t -h crt.sh -p 5432 -U guest certwatch 2>/dev/null \
            | sed 's/ //g' \
            | grep -E ".*\.$TARGET" \
            | sed 's/^\*\.//' \
            | tr '[:upper:]' '[:lower:]' \
            | sort -u > "$TMP" &

        local pid=$!
        show_spinner "$pid"
        wait "$pid"

        [[ -s "$TMP" ]] && break

        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] crt.sh attempt $attempt failed, retrying..."
        printf "%b" "$BRIGHT_WHITE"
        sleep 2
    done

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] crt.sh         : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_wayback() {

    local OUT="$1"
    require_tool waybackurls unfurl 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    waybackurls "$TARGET" 2>/dev/null | unfurl domains | sort -u > "$TMP" &
    local pid=$!
    show_spinner "$pid"
    wait "$pid"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] wayback        : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_gau() {

    local OUT="$1"
    require_tool gau unfurl 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    gau "$TARGET" --subs 2>/dev/null | unfurl domains | sort -u > "$TMP" &
    local pid=$!
    show_spinner "$pid"
    wait "$pid"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] gau            : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_hackertarget() {

    local OUT="$1"
    require_tool curl 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    local response
    response=$(curl -s --max-time 15 \
        "https://api.hackertarget.com/hostsearch/?q=$TARGET" 2>/dev/null)

    if [[ "$response" == *"error"* ]] || [[ "$response" == *"API count"* ]]
    then
        printf "%b" "$BRIGHT_PURPLE"
        print_info "[!] hackertarget: API limit or error, skipping"
        printf "%b" "$BRIGHT_WHITE"
        rm -f "$TMP"
        return
    fi

    echo "$response" | cut -d',' -f1 | sort -u > "$TMP"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] hackertarget   : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_sectrails() {

    local OUT="$1"
    [[ -z "$SECTRAILS_API_KEY" ]] && return
    require_tool curl jq 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    curl -s --max-time 20 \
        -H "apikey: $SECTRAILS_API_KEY" \
        "https://api.securitytrails.com/v1/domain/${TARGET}/subdomains" 2>/dev/null \
        | jq -r --arg d "$TARGET" '.subdomains[]? | "\(.).\($d)"' 2>/dev/null \
        | sort -u > "$TMP"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] securitytrails : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}

_pipeline_otx() {

    local OUT="$1"
    [[ -z "$OTX_API_KEY" ]] && return
    require_tool curl jq 2>/dev/null || return

    local TMP
    TMP=$(mktemp)

    curl -s --max-time 20 \
        -H "X-OTX-API-KEY: $OTX_API_KEY" \
        "https://otx.alienvault.com/api/v1/indicators/domain/${TARGET}/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[]?.hostname' 2>/dev/null \
        | sort -u > "$TMP"

    printf "%b" "$BRIGHT_GREEN"
    print_info "[+] otx            : $(wc -l < "$TMP")"
    printf "%b" "$BRIGHT_WHITE"

    cat "$TMP" >> "$OUT"
    rm -f "$TMP"
}
