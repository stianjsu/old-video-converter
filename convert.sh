#!/bin/bash

set -e

# Create output directory if it doesn't exist
mkdir -p output

# Find all files in input directory and subdirectories
find input -type f | while read -r file; do
    echo "Processing $file"
    
    # Get the relative path from input directory
    relative_path="${file#input/}"
    
    # Get directory part of the relative path
    dir_part=$(dirname "$relative_path")
    
    # Get filename without extension
    filename=$(basename "$relative_path")
    filename_no_ext="${filename%.*}"
    
    # Create output directory structure
    output_dir="output/$dir_part"
    mkdir -p "$output_dir"
    
    # Convert file
    ffmpeg -i "$file" -c:v libx264 -crf 15 -preset slower -c:a aac -b:a 256k "$output_dir/${filename_no_ext}.mp4"
done