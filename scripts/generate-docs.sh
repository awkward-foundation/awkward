#!/bin/bash

SRC_FILES=(
    "./lib/core.awk"
    "./lib/modules/math.awk"
    "./lib/modules/system.awk"
    "./lib/modules/io.awk"
    "./lib/modules/fs.awk"
    "./lib/modules/http.awk"
    "./lib/modules/regex.awk"
    "./lib/modules/kek.awk"
    "./lib/modules/mysql.awk"
)
OUT_DIR="./docs"

mkdir -p "$OUT_DIR"

current_category=""
description=""
examples=""
mode=""
written_categories=""

while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*#\ *@doc[[:space:]]*\[([a-zA-Z0-9_]+)\] ]]; then
        current_category="${BASH_REMATCH[1]}"
        description=""
        examples=""
        mode="description"
        continue
    fi

    if [[ $line =~ ^[[:space:]]*#(.*) ]] && [[ -n "$current_category" ]]; then
        content="${BASH_REMATCH[1]}"
        content="${content# }"
        if [[ $content == examples:* ]]; then
            mode="examples"
            continue
        fi
        if [[ $mode == "description" ]]; then
            description="${description}${content}"$'\n'
        else
            examples="${examples}${content}"$'\n'
        fi
        continue
    fi

    if [[ $line =~ ^[[:space:]]*function[[:space:]]+([A-Za-z0-9_]+) ]] && [[ -n "$current_category" ]]; then
        func_name="${BASH_REMATCH[1]}"
        if [[ $func_name == parse_* ]]; then
            func_name="${func_name#parse_}"
        elif [[ $func_name == execute_* ]]; then
            func_name="${func_name#execute_}"
        fi

        outfile="$OUT_DIR/$current_category.md"

        if ! echo "$written_categories" | grep -qw "$current_category"; then
            echo "# $current_category" > "$outfile"
            echo >> "$outfile"
            written_categories="$written_categories $current_category"
        fi

        {
            echo "## \`$func_name\`"
            echo
            printf '%s\n' "$description"
            if [ -n "$examples" ]; then
                echo "**Examples:**"
                echo '```awkward'
                printf '%s' "$examples"
                echo '```'
                echo
            fi
        } >> "$outfile"

        current_category=""
        description=""
        examples=""
        mode=""
    fi

done < <(cat "${SRC_FILES[@]}")
