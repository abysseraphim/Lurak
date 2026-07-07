#!/usr/bin/env bash

workspace_initializer() {
    if [[ ! -d $WORKSPACE_ROOT ]]
    then
        mkdir -p $WORKSPACE_ROOT
    fi
}

target_initializer() {
    local target=$1

    if [[ "$TARGET_TYPE" == "CIDR" ]]
    then
        target="${target//\//_}"
    fi

    if [[ ! -d "$WORKSPACE_ROOT/$target" ]]
    then
        mkdir -p "$WORKSPACE_ROOT/$target/"
    fi

    TARGET_DIR="$WORKSPACE_ROOT/$target"
}

save_output() {
    local data=$1
    local filename=$2

    printf '%s\n' "$data" > "$TARGET_DIR/$filename"
}

read_output() {
    local target=$1
    local filename=$2

    cat "$WORKSPACE_ROOT/$target/$filename"
}

output_exists() {
    local target=$1
    local filename=$2

    if [[ -f "$WORKSPACE_ROOT/$target/$filename" ]]
    then
        return 0
    else
        return 1
    fi
}

list_outputs() {
    :
}