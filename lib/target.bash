#/usr/bin/env bash

read_target() {
    local target
    read -rp "    Target> " target
    target="${target#"${target%%[![:space:]]*}"}"
    target="${target%"${target##*[![:space:]]}"}"
    echo "$target"
}

validate_target() {
    local target=$1
    if [[ -z "$target" ]]
    then
        return 2
    fi
}

detect_target_type() {
    local target=$1

    if [[ "$target" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
    then
        echo "IP"

    elif [[ "$target" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]
    then
        echo "CIDR"

    elif [[ "$target" =~ ^(https://|http://)?([[:alnum:]-]+\.)+[[:alpha:]]{2,}(/.*)?$ ]]
    then
        echo "DOMAIN"
    fi
}

resolve_target_to_ip() {
    if [[ "$TARGET_TYPE" == "IP" ]]
    then
        TARGET_IP="$TARGET"
    elif [[ "$TARGET_TYPE" == "DOMAIN" ]]
    then
        TARGET_IP=$(dig +short A "$TARGET" | head -n1)
        if [[ -z "$TARGET_IP" ]]
        then
            return 4
        fi

    elif [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        local network=${TARGET%/*}

        IFS='.' read -r o1 o2 o3 o4 <<< "$network"

        TARGET_IP="$o1.$o2.$o3.$((o4 + 1))"
    fi
}