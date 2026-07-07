#!/usr/bin/env bash

print_info() {
    printf "    %s\n" "$1"
}

# require_sudo() {
#     local attempts=0

#     while [[ $attempts -lt 2 ]]
#     do
#         printf "%b" "$BRIGHT_YELLOW"
#         print_info "[*] Enter sudo password: "
#         printf "%b" "$RESET"

#         if sudo -v 2>/dev/null
#         then
#             echo
#             return 0
#         fi

#         attempts=$(( attempts + 1 ))

#         if [[ $attempts -eq 2 ]]
#         then
#             printf "%b" "$BRIGHT_PURPLE"
#             print_info "[!] Authentication failed."
#             printf "%b" "$RESET"
#             return 9
#         fi

#         printf "%b" "$BRIGHT_PURPLE"
#         print_info "[!] Wrong password, try again."
#         printf "%b" "$RESET"
#     done
# }