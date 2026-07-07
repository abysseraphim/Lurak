#!/usr/bin/env bash

require_tool() {
    local tool

    for tool in "$@"
    do
        if ! command -v "$tool" >/dev/null 2>&1
        then
            print_info "[!] Required tool '$tool' is not installed or in PATH."
            return 3
        fi
    done

    return 0
}