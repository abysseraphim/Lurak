#!/usr/bin/env bash

view_results()
{
    local ROOT_DIR="$HOME/LURAK-DATA"
    local CURRENT_DIR="$ROOT_DIR"

    local SELECTED=0


    if [[ ! -d "$ROOT_DIR" ]]
    then
        print_info "[!] LURAK-DATA directory does not exist."
        return 12
    fi


    while true
    do
        clear

        printf "%b" "$BRIGHT_PURPLE"
        print_info "Lurak Result Browser"
        printf "%b" "$BRIGHT_WHITE"

        echo
        print_info "Current: $CURRENT_DIR"
        echo


        mapfile -t ITEMS < <(ls -1 "$CURRENT_DIR" 2>/dev/null)


        if [[ ${#ITEMS[@]} -eq 0 ]]
        then
            echo "    Empty directory"
        fi


        for i in "${!ITEMS[@]}"
        do
            item="${ITEMS[$i]}"

            if [[ "$i" -eq "$SELECTED" ]]
            then
                printf "%b" "$BRIGHT_GREEN"
                printf " > "
            else
                printf "   "
            fi


            if [[ -d "$CURRENT_DIR/$item" ]]
            then
                printf "%b" "$BRIGHT_CYAN"
                echo "[DIR]  $item"
            else
                printf "%b" "$BRIGHT_WHITE"
                echo "[FILE] $item"
            fi


            printf "%b" "$RESET"
        done


        echo
        printf "%b" "$BRIGHT_YELLOW"
        print_info "j/k: move   ENTER: open   b: back   q: quit"
        printf "%b" "$RESET"


        read -rsn1 key


        case "$key" in


            j)
                if [[ "$SELECTED" -lt $((${#ITEMS[@]}-1)) ]]
                then
                    SELECTED=$((SELECTED+1))
                fi
                ;;


            k)
                if [[ "$SELECTED" -gt 0 ]]
                then
                    SELECTED=$((SELECTED-1))
                fi
                ;;


            "")
                selected_item="${ITEMS[$SELECTED]}"
                selected_path="$CURRENT_DIR/$selected_item"


                if [[ -d "$selected_path" ]]
                then
                    CURRENT_DIR="$selected_path"
                    SELECTED=0


                elif [[ -f "$selected_path" ]]
                then

                    case "$selected_path" in

                        *.json)
                            if command -v jq >/dev/null 2>&1
                            then
                                jq . "$selected_path" | less
                            else
                                less "$selected_path"
                            fi
                            ;;

                        *)
                            less "$selected_path"
                            ;;

                    esac

                fi
                ;;


            b)

                if [[ "$CURRENT_DIR" != "$ROOT_DIR" ]]
                then
                    CURRENT_DIR=$(dirname "$CURRENT_DIR")
                    SELECTED=0
                fi

                ;;


            q)
                break
                ;;

        esac

    done
}
