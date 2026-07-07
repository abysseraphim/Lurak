#!/usr/bin/env bash

show_status(){
    printf "%b" "$BRIGHT_PURPLE"
    echo "    version:   $(printf "%b" "$BRIGHT_WHITE") $VERSION $(printf "%b" "$BRIGHT_PURPLE")"
    echo "    Target:    $(printf "%b" "$BRIGHT_WHITE") $TARGET $(printf "%b" "$BRIGHT_PURPLE")"
    echo "    Type:      $(printf "%b" "$BRIGHT_WHITE") $TARGET_TYPE $(printf "%b" "$BRIGHT_PURPLE")"
    echo "    WorkSpace: $(printf "%b" "$BRIGHT_WHITE") $WORKSPACE_ROOT $(printf "%b" "$RESET")"
    printf "%b" "$RESET"
}