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

# Required
add_param "SourcePath" "$SOURCE_PATH"
add_param "DestPath" "$DEST_PATH"

# Optional
add_param "TargetFps" "$TARGET_FPS"
add_param "AllowFpsUpsample" "$ALLOW_FPS_UPSAMPLE"
add_param "VideoCodec" "$VIDEO_CODEC"
add_param "Preset" "$PRESET"
add_param "VideoBitrate" "$VIDEO_BITRATE"
add_param "MaxRate" "$MAXRATE"
add_param "BufSize" "$BUFSIZE"
add_param "CRF" "$CRF"
add_param "AudioMode" "$AUDIO_MODE"
add_param "AudioBitrate" "$AUDIO_BITRATE"
add_param "MapSubtitles" "$MAP_SUBTITLES"
add_param "Overwrite" "$OVERWRITE"
add_param "DryRun" "$DRYRUN"
add_param "Extensions" "$EXTENSIONS"
add_param "Suffix" "$SUFFIX"
add_param "Threads" "$THREADS"

# Run PowerShell script with built params
while true; do
  eval "pwsh -File '/app/Optimize-Media.ps1' $PARAMS"
  sleep $SLEEP_SECONDS
done
