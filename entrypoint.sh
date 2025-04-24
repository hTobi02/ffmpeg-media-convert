#!/bin/bash

set -e

PARAMS=""

add_param() {
  VAR_NAME="$1"
  VAR_VALUE="$2"
  if [ -n "$VAR_VALUE" ]; then
    PARAMS+=" -$VAR_NAME '$VAR_VALUE'"
  fi
}

# Required
add_param "OriginalPath" "$ORIGINAL_PATH"
add_param "OptimizedPath" "$OPTIMIZED_PATH"

# Optional
add_param "VideoCodec" "$VIDEO_CODEC"
add_param "AudioCodec" "$AUDIO_CODEC"
add_param "Bitrate2160p" "$BITRATE_2160P"
add_param "Bitrate1440p" "$BITRATE_1440P"
add_param "Bitrate1080p" "$BITRATE_1080P"
add_param "Bitrate720p" "$BITRATE_720P"
add_param "Bitrate480p" "$BITRATE_480P"

# Run PowerShell script with built params
pwsh -File ./Convert-Videos.ps1 $PARAMS
