#!/bin/bash

set -u
set -o pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p output

find input -type f \( -iname '*.mpg' -o -iname '*.mpeg' \) -print0 | while IFS= read -r -d '' file; do
    echo -e "${GREEN}[CONVERTING]${NC} $file"

    relative_path="${file#input/}"
    dir_part=$(dirname "$relative_path")
    filename_no_ext="$(basename "$relative_path" | sed 's/\.[^.]*$//')"

    if [ "$dir_part" = "." ]; then
        output_dir="output"
    else
        output_dir="output/$dir_part"
    fi

    output_file="$output_dir/${filename_no_ext}.mp4"
    log_file=$(mktemp)
    audio_stream_index=$(ffprobe -v error \
        -select_streams a \
        -show_entries stream=index,codec_name,channels \
        -of csv=p=0 \
        "$file" | awk -F',' '
            $2 == "mp1" && $3 + 0 > 0 { print $1; found = 1; exit }
            $3 + 0 > 0 && first == "" { first = $1 }
            END { if (!found && first != "") print first }
        ')

    mkdir -p "$output_dir"

    ffmpeg_status=0
    ffmpeg_args=(
        -nostdin
        -i "$file"
        -map 0:v:0
        -c:v libx265
        -preset slow
        -crf 18
        -tag:v hvc1
        -movflags +faststart
        -y
    )

    if [ -n "$audio_stream_index" ]; then
        ffmpeg_args+=(
            -map "0:${audio_stream_index}"
            -c:a aac
            -b:a 256k
        )
    else
        ffmpeg_args+=( -an )
    fi

    ffmpeg_args+=( "$output_file" )

    if ffmpeg "${ffmpeg_args[@]}" >"$log_file" 2>&1; then
        :
    else
        ffmpeg_status=$?
    fi

    grep -E "Duration|Stream #|fps=|time=|error" "$log_file" | grep -vi "Failed to genrate CPU mask" || true

    if [ "$ffmpeg_status" -eq 0 ] && ffprobe -v error "$output_file" >/dev/null 2>&1; then
        if grep -qi "Failed to genrate CPU mask" "$log_file"; then
            echo -e "  ${YELLOW}Warning${NC} x265 reported a CPU-mask issue, but the file validated successfully"
        fi
        echo -e "  ${GREEN}Done${NC}"
    else
        rm -f "$output_file"
        echo -e "  ${RED}Failed${NC} $file"
        if grep -qi "Failed to genrate CPU mask" "$log_file"; then
            echo -e "  ${YELLOW}Note${NC} x265 emitted a CPU-mask warning in this container"
        fi
    fi

    rm -f "$log_file"
    echo ""
done
