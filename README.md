# Convert-Videos.ps1

## Overview

`Convert-Videos.ps1` is a PowerShell script designed to convert video files into multiple resolution-based quality levels with customizable video and audio codecs. It leverages `ffmpeg` to handle the conversions and supports High Dynamic Range (HDR) and Dolby Vision detection with automatic tone mapping when needed.

---

## Features

- Convert video files to multiple resolutions (2160p, 1440p, 1080p, 720p, 480p)
- Customize video and audio codecs (e.g., `libx265`, `aac`)
- Set individual bitrates for each resolution
- Automatically detect HDR and Dolby Vision content
- Apply tone mapping when required
- Supports batch processing of video files
- Retains audio and subtitle streams

---

## Requirements

- **PowerShell 5.1+**
- **ffmpeg** and **ffprobe** must be available in your system's `PATH`

---

## Parameters

| Parameter       | Description                                                      |
|----------------|------------------------------------------------------------------|
| `OriginalPath` | Path(s) to the source video file(s)                              |
| `OptimizedPath`| Path(s) for the converted output files                           |
| `VideoCodec`   | Desired video codec (e.g., `libx265`, `libx264`)                 |
| `AudioCodec`   | Desired audio codec (e.g., `aac`, `copy`)                        |
| `Bitrate2160p` | Target bitrate for 4K (2160p) videos                             |
| `Bitrate1440p` | Target bitrate for 1440p videos                                  |
| `Bitrate1080p` | Target bitrate for Full HD (1080p) videos                        |
| `Bitrate720p`  | Target bitrate for HD (720p) videos                              |
| `Bitrate480p`  | Target bitrate for SD (480p) videos                              |

---

## Example Usage

Convert videos in `C:\Input` to 2160p and 1080p using H.264 and AC3:

```powershell
.\Convert-Videos.ps1 -OriginalPath "C:\Input" `
                     -OptimizedPath "C:\Output" `
                     -VideoCodec "libx264" `
                     -AudioCodec "ac3" `
                     -Bitrate2160p "12000k" `
                     -Bitrate1080p "5M"
```

## Notes
The script detects HDR (bt2020 / PQ) and Dolby Vision (DOVI_Profile) content and applies appropriate tone mapping.

Output files will be saved in the mirrored folder structure inside OptimizedPath.
