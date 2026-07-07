#!/usr/bin/env bash

show_spinner() {
    local pid=$1

    local spinner='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null # -0 means send to signal to process, just check if its alive. while is using exitcode and not output.
    do
        i=$(( (i + 1) % 4 ))

        printf "%b" "$BRIGHT_CYAN"
        printf "\r    [%c] Working..." "${spinner:$i:1}"
        printf "%b" "$RESET"
        sleep 0.1
    done

    printf "%b" "$BRIGHT_GREEN"
    printf "\r    [+] Done.        \n"
    printf "%b" "$RESET"
}
