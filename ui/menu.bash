#!/usr/bin/env bash

show_menu() {
    printf "%b" "$BRIGHT_PURPLE"
    printf '
    ━━━━━━━━━━━━━━━━━━━━━━━ Menu ━━━━━━━━━━━━━━━━━━━━━━━

    [1]  ASN Recon
    [2]  CIDR Discovery
    [3]  Single IP Port Scan
    [4]  CIDR Port Scan
    [5]  Service Discovery (ON CIDR)
    [6]  Domain Discovery
    [7]  Subdomain Discovery
    [8]  DNS Brute Force
    [9]  Name Resolution
    [10]  HTTP Service Discovery (ON RESOLVED/LIVE SUBDOMAINS)
    [11]  CDN Detection
    [12]  SSL Certificate Search
    [13]  Smart Pipeline
    [14]  View Results

    [15]  Switch Target
    [0]  Quit

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    '
    printf "%b" "$RESET"

    echo
    printf "%b" "$BRIGHT_YELLOW"
    read -rp "    Lurak > " OPTION
    printf "%b" "$RESET"
}