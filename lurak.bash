#!/usr/bin/env bash

source lib/constants.bash
source lib/workspace.bash
source lib/target.bash
source lib/tools.bash
source lib/utils.bash

source ui/colors.bash
source ui/banner.bash
source ui/menu.bash
source ui/status.bash
source ui/progress.bash

source modules/asn.bash
source modules/cidr.bash
source modules/portscan_ip.bash
source modules/portscan_cidr.bash
source modules/service.bash
source modules/domain.bash
source modules/subdomain.bash
source modules/dns_bruteforce.bash
source modules/resolve.bash
source modules/http_service.bash
source modules/cdn.bash
source modules/ssl.bash
source modules/results.bash
source modules/pipeline.bash

workspace_initializer

# Target Selection Loop
while true
do
    printf "%b" "$BRIGHT_YELLOW"
    echo
    echo "    Enter your target (domain/ip/cidr)"
    TARGET=$(read_target)
    printf "%b" "$RESET"

    if ! validate_target "$TARGET"
    then
        echo "[!] Target cannot be empty."
        continue
    fi

    TARGET_TYPE=$(detect_target_type "$TARGET")

    if [[ "$TARGET_TYPE" != "IP" && \
          "$TARGET_TYPE" != "DOMAIN" && \
          "$TARGET_TYPE" != "CIDR" ]]
    then
        echo "[!] Invalid target format."
        continue
    fi

    target_initializer "$TARGET"

    # Main Framework Loop
    while true
    do
        show_banner
        show_status
        show_menu

        case "$OPTION" in
            1)
                asn_recon
                ;;
            2)
                cidr_discovery
                ;;
            3)
                ip_port_scan
                ;;
            4)
                cidr_port_scan
                ;;
            5)
                service_discovery
                ;;
            6)
                domain_discovery
                ;;
            7)
                subdomain_discovery
                ;;
            8)
                dns_brute_force
                ;;
            9)
                name_resolution
                ;;
            10)
                http_service_discovery
                ;;
            11)
                cdn_detection
                ;;
            12)
                certificate_inspection
                ;;
            13)
                smart_pipeline
                ;;
            14)
                view_results
                ;;
            15)
                break
                ;;
            0)
                echo
                exit 0
                ;;
            *)
                printf "%b" "$BRIGHT_PURPLE"
                print_info "[!] Invalid option."
                printf "%b" "$RESET"
                ;;
        esac

        echo
        printf "%b" "$BRIGHT_YELLOW"
        read -rp "    Press Enter to continue..."
        printf "%b" "$RESET"

    done
done