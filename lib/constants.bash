#!/usr/bin/env bash

readonly PROGRAM_NAME="Lurak"
readonly VERSION="1.0.0"
readonly WORKSPACE_ROOT="$HOME/LURAK-DATA"
readonly PAGER="less"
readonly DEFAULT_TIMEOUT=10
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly WORDLISTS_DIR="$PROJECT_ROOT/wordlists"

# API KEYS
readonly OTX_API_KEY=""
readonly SECTRAILS_API_KEY=""

# errors
readonly ERR_OUTPUT_NOT_FOUND=1
readonly ERR_EMPTY_TARGET=2
readonly ERR_TOOL_NOT_EXISTS=3
readonly ERR_IP_NOT_RESOLVED=4
readonly ERR_ASN_NOT_FOUND=5
readonly ERR_CIDR_NOT_FOUND=6
readonly ERR_INVALID_OPTION=7
readonly ERR_NO_OPEN_PORTS=8
readonly ERR_SUDO_PW_WRONG=9
readonly ERR_FILE_NOT_FOUND=10
readonly ERR_INVALID_TYPE=11
readonly ERR_COMMAND_FAILED=12
# at this point i dont event know what im doing with all these error variables (function returen codes) but just let them be.
# in future developments and error handlings, you might need them
