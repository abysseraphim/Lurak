#!/usr/bin/env bash


show_banner() {
    clear

    printf "%b" "$BRIGHT_PURPLE"
    cat "$PROJECT_ROOT/assets/banner.txt"
    printf "%b" "$RESET"
}
