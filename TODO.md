# Potential TODOs

## High Priority

### 1. Use process substitution instead of pipe subshell

`find ... | while` runs the loop in a subshell, meaning the script always exits 0 regardless of how many conversions fail. Switching to `while ... done < <(find ...)` keeps the loop in the main shell, enabling a failure counter and a meaningful exit code for callers like `run.sh`.

### 2. Handle ffprobe failure explicitly

If `ffprobe` fails (corrupt file, missing codec metadata), `audio_stream_index` silently becomes empty and the output file is encoded without audio — with no warning. A log line when audio detection fails would prevent confusion when reviewing output files later.

### 3. Validate audio_stream_index is numeric

The awk output is used directly in `-map "0:${audio_stream_index}"`. If ffprobe returns unexpected output, this could be a non-numeric string, causing ffmpeg to error out with a confusing message. A simple `[[ "$audio_stream_index" =~ ^[0-9]+$ ]]` guard fixes this.

### 4. Adaptive CRF based on input resolution

CRF is hardcoded at 18 (near-lossless), which is designed for high-res sources. For low-res inputs like 320x240 camera footage, this produces output *larger* than the original because it spends more bits than the source ever had. Probing each file's resolution and scaling CRF accordingly (e.g. 320x240→28, 720p→22, 1080p→20, 4K→18) would avoid wasting space on quality the source can't provide.

### 5. Adaptive audio bitrate based on channel count

Audio bitrate is hardcoded at 256k AAC. Old camera files typically have mono mp1 audio where 96k AAC is more than sufficient. Scaling by channel count (mono→96k, stereo→192k, surround→384k) or capping at the source audio bitrate would prevent bloat. Together with adaptive CRF, these two changes would make the converter right-size its output regardless of input quality.

## Medium Priority

### 6. Fix "genrate" typo in grep filters

Lines 71, 74, and 81 grep for `"Failed to genrate CPU mask"` — this matches x265's current (misspelled) warning. If x265 corrects the typo in a future release, all three checks silently become dead code. Using a regex like `gen[e]*rate` or a variable with a comment would be more resilient.

### 7. Add error checks on setup commands

`mktemp`, `mkdir -p`, and other setup commands can fail silently since `set -e` is not used. Either add `set -e` (with targeted `|| true` where failure is expected) or add explicit checks on critical commands like `mktemp`.

### 8. Trap for temp file cleanup

If the script is interrupted mid-conversion (Ctrl+C, `docker stop`), the current temp log file from `mktemp` is never cleaned up. A `trap 'rm -f "$log_file"' EXIT INT TERM` solves this.

## Low Priority

### 9. Simplify ffmpeg exit code capture

The if/else block on lines 65-69 works but is unnecessarily convoluted. Can be replaced with:
```bash
ffmpeg "${ffmpeg_args[@]}" >"$log_file" 2>&1
ffmpeg_status=$?
```

### 10. Check input directory exists before find

If `input/` is missing or empty, the script silently does nothing and exits 0. An early check with a clear error message would save debugging time.

### 11. Skip-if-exists mode

Re-running the script re-encodes everything (`-y` overwrites). An optional mode that skips files whose output already exists would save time on interrupted/resumed batch jobs.
