#!/usr/bin/env python3

import os
import subprocess
import sys
import tempfile
from pathlib import Path

GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
NC = "\033[0m"

INPUT_DIR = Path("input")
OUTPUT_DIR = Path("output")
EXTENSIONS = {".mpg", ".mpeg"}


def find_audio_stream_index(file_path):
    """Find the best audio stream index, preferring mp1 codec."""
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-select_streams", "a",
            "-show_entries", "stream=index,codec_name,channels",
            "-of", "csv=p=0",
            str(file_path),
        ],
        capture_output=True, text=True,
    )
    first_valid = None
    for line in result.stdout.strip().splitlines():
        parts = line.split(",")
        if len(parts) < 3:
            continue
        index, codec, channels = parts[0], parts[1], parts[2]
        try:
            ch = int(channels)
        except ValueError:
            continue
        if ch <= 0:
            continue
        if codec == "mp1":
            return index
        if first_valid is None:
            first_valid = index
    return first_valid


def convert_file(file_path):
    print(f"{GREEN}[CONVERTING]{NC} {file_path}")

    relative = file_path.relative_to(INPUT_DIR)
    output_file = OUTPUT_DIR / relative.with_suffix(".mp4")
    output_file.parent.mkdir(parents=True, exist_ok=True)

    audio_index = find_audio_stream_index(file_path)

    ffmpeg_args = [
        "ffmpeg", "-nostdin",
        "-i", str(file_path),
        "-map", "0:v:0",
        "-c:v", "libx265",
        "-preset", "slow",
        "-crf", "18",
        "-tag:v", "hvc1",
        "-movflags", "+faststart",
        "-y",
    ]

    if audio_index is not None:
        ffmpeg_args += ["-map", f"0:{audio_index}", "-c:a", "aac", "-b:a", "256k"]
    else:
        ffmpeg_args += ["-an"]

    ffmpeg_args.append(str(output_file))

    with tempfile.NamedTemporaryFile(mode="w", suffix=".log", delete=False) as log:
        log_path = log.name

    try:
        with open(log_path, "w") as log_f:
            ffmpeg_status = subprocess.call(ffmpeg_args, stdout=log_f, stderr=log_f)

        with open(log_path) as log_f:
            log_contents = log_f.read()

        for line in log_contents.splitlines():
            lower = line.lower()
            if any(kw in lower for kw in ["duration", "stream #", "fps=", "time=", "error"]):
                if "failed to genrate cpu mask" not in lower:
                    print(line)

        cpu_mask_warning = "failed to genrate cpu mask" in log_contents.lower()
        probe_ok = ffmpeg_status == 0 and subprocess.call(
            ["ffprobe", "-v", "error", str(output_file)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ) == 0

        if probe_ok:
            if cpu_mask_warning:
                print(f"  {YELLOW}Warning{NC} x265 reported a CPU-mask issue, but the file validated successfully")
            print(f"  {GREEN}Done{NC}")
        else:
            output_file.unlink(missing_ok=True)
            print(f"  {RED}Failed{NC} {file_path}")
            if cpu_mask_warning:
                print(f"  {YELLOW}Note{NC} x265 emitted a CPU-mask warning in this container")
    finally:
        os.unlink(log_path)

    print()


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    files = sorted(
        f for f in INPUT_DIR.rglob("*")
        if f.is_file() and f.suffix.lower() in EXTENSIONS
    )

    if not files:
        print("No input files found.")
        sys.exit(0)

    for f in files:
        convert_file(f)


if __name__ == "__main__":
    main()
