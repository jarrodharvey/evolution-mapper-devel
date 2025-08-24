#!/bin/bash

# List of files to extract env values from
files=(
    "evolution-mapper-backend/.Renviron"
    "evolution-mapper-frontend/.env"
)

# Extract all unique values, splitting comma-separated lists, excluding localhost
values=$(for file in "${files[@]}"; do
    grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$file" | cut -d '=' -f 2- | tr ',' '\n'
done | sed '/^\s*$/d' | grep -v 'localhost' | sort -u)

# Search for each value using ripgrep (literal search)
for value in $values; do
    echo "Searching for: $value"
    rg -F --with-filename --line-number "$value"
    echo "-----------------------------------"
done
