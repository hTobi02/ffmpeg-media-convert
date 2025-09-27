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
add_param "OriginalPath" "$ORIGINAL_PATH"
add_param "OptimizedPath" "$OPTIMIZED_PATH"

# Optional
add_param "VideoCodec" "$VIDEO_CODEC"
add_param "AudioCodec" "$AUDIO_CODEC"
add_param "Bitrate4320p" "$BITRATE_4320P"
add_param "Bitrate3456p" "$BITRATE_3456P"
add_param "Bitrate2880p" "$BITRATE_2880P"
add_param "Bitrate2160p" "$BITRATE_2160P"
add_param "Bitrate1440p" "$BITRATE_1440P"
add_param "Bitrate1080p" "$BITRATE_1080P"
add_param "Bitrate720p" "$BITRATE_720P"
add_param "Bitrate480p" "$BITRATE_480P"
add_param "DenyTonemap" "$DENY_TONEMAP"
add_param "AudioToStereo" "$AUDIO_TO_STEREO"
add_param "uploader" "$UPLOADER"

# Debug
echo "PARAMS: $PARAMS"
sleep 10

# Run PowerShell script with built params
while true; do
  eval "pwsh -File '/app/Optimize-Media.ps1' $PARAMS"
  sleep $SLEEP_SECONDS
done
