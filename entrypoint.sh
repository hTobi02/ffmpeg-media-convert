#!/bin/sh

set -e

PARAMS=""

add_param() {
  VAR_NAME="$1"
  VAR_VALUE="$2"
  if [ -n "$VAR_VALUE" ]; then
    PARAMS="$PARAMS -$VAR_NAME '$VAR_VALUE'"
  fi
}

add_switch() { # nur Flag setzen, wenn logisch "true"
  v="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
  case "$v" in 1|true|yes|on) PARAMS="$PARAMS -$1" ;; esac
}

# Required
add_param "SourcePath" "$SOURCE_PATH"
add_param "DestPath"   "$DEST_PATH"

# Optional (normale Parameter)
add_param "TargetFps"    "$TARGET_FPS"
add_param "VideoCodec"   "$VIDEO_CODEC"
add_param "Preset"       "$PRESET"
add_param "VideoBitrate" "$VIDEO_BITRATE"
add_param "MaxRate"      "$MAXRATE"
add_param "BufSize"      "$BUFSIZE"
add_param "CRF"          "$CRF"
add_param "AudioMode"    "$AUDIO_MODE"
add_param "AudioBitrate" "$AUDIO_BITRATE"
add_param "Extensions"   "$EXTENSIONS"
add_param "Suffix"       "$SUFFIX"
add_param "Threads"      "$THREADS"

# Switches (ohne '1' anhängen!)
add_switch "AllowFpsUpsample" "$ALLOW_FPS_UPSAMPLE"
add_switch "MergeAudio"       "$MERGE_AUDIO"
add_switch "NormalizeAudio"   "$NORMALIZE_AUDIO"
add_switch "MapSubtitles"     "$MAP_SUBTITLES"
add_switch "Overwrite"        "$OVERWRITE"
add_switch "DryRun"           "$DRYRUN"

# Debug
echo "PARAMS: $PARAMS"
sleep 10

# Run PowerShell script with built params
while true; do
  eval "pwsh -File '/app/Optimize-Media.ps1' $PARAMS"
  sleep $SLEEP_SECONDS
done
