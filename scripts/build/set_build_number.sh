#!/bin/bash

# Check if a file name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Assign the filename to a variable
filename=$1

# Generate the replacement string
replacement=$(date '+%y%m%d%H%M')

# Use sed to replace the number at the end of the line
# The regex looks for the pattern, captures the start of the line, and replaces only the last number
sed -i '' "s/^\(BUILD_NUMBER: &BUILD_NUMBER \)[0-9]*$/\1$replacement/" "$filename"
