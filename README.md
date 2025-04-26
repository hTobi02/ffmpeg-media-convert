# Optimize-Media.ps1

## Overview

`Optimize-Media.ps1` is a PowerShell script designed to convert video files into multiple resolution-based quality levels with customizable video and audio codecs. It leverages `ffmpeg` to handle the conversions and supports High Dynamic Range (HDR) and Dolby Vision detection with optional tone mapping.

---

## Read Before Use

Your video files should use the naming convention recommended by [TRaSH-Guides](https://trash-guides.info/Radarr/Radarr-recommended-naming-scheme/#standard-movie-format).  
This includes formats like `[Bluray-1080p]`, `[Bluray-1080p Proper]`, `[Bluray-1080p Real]`, or similar.  
While you can still run the script with other formats, full functionality has only been tested using the recommended naming.

---

## Features

- Convert video files to multiple resolutions (4320p, 3456p, 2880p, 2160p, 1440p, 1080p, 720p, 480p)
- Customize video and audio codecs (e.g., `libx265`, `aac`, `copy`, `av1_nvenc`)
- Set individual bitrates per resolution
- Detect HDR and Dolby Vision content
- Optional tone mapping for HDR content (can be disabled via `-DenyTonemap`)
- Supports batch processing of video files
- Retains all audio and subtitle streams
- Mirrors original folder structure inside output directory

---

## Requirements

- **PowerShell 5.1+**
- **ffmpeg** and **ffprobe** must be available in your system's `PATH`

---

## Parameters

| Parameter        | Description                                                      |
|------------------|------------------------------------------------------------------|
| `OriginalPath`   | Path(s) to the source video file(s)                              |
| `OptimizedPath`  | Path(s) for the converted output files                           |
| `VideoCodec`     | Desired video codec (e.g., `libx265`, `libx264`, `av1_nvenc`)    |
| `AudioCodec`     | Desired audio codec (e.g., `ac3`, `copy`)                        |
| `Bitrate4320p`   | Target bitrate for 8K (4320p) videos                             |
| `Bitrate3456p`   | Target bitrate for 6K (3456p) videos                             |
| `Bitrate2880p`   | Target bitrate for 5K (2880p) videos                             |
| `Bitrate2160p`   | Target bitrate for 4K (2160p) videos                             |
| `Bitrate1440p`   | Target bitrate for 1440p videos                                  |
| `Bitrate1080p`   | Target bitrate for Full HD (1080p) videos                        |
| `Bitrate720p`    | Target bitrate for HD (720p) videos                              |
| `Bitrate480p`    | Target bitrate for SD (480p) videos                              |
| `DenyTonemap`    | Prevent tone mapping from HDR to SDR (boolean switch)            |

---

## Example Usage

Convert videos in `C:\Input` to 2160p and 1080p using H.264 and AC3 audio:

```powershell
.\Optimize-Media.ps1 -OriginalPath "C:\Input" `
                     -OptimizedPath "C:\Output" `
                     -VideoCodec "libx264" `
                     -AudioCodec "ac3" `
                     -Bitrate2160p "12000k" `
                     -Bitrate1080p "5M"
```
<br>

Convert videos in C:\Input to 1080p, 720p and 480p using AV1 and disable tone mapping:

```powershell
.\Optimize-Media.ps1 -OriginalPath "C:\Input" `
                     -OptimizedPath "C:\Output" `
                     -VideoCodec av1_nvenc `
                     -AudioCodec copy `
                     -Bitrate1080p 4M `
                     -Bitrate720p 1500k `
                     -Bitrate480p 400k `
                     -DenyTonemap $true
```

## Notes
HDR (BT.2020 with PQ transfer) and Dolby Vision content are detected via ffprobe.

Tone mapping from HDR to SDR will be applied automatically unless -DenyTonemap is set to $true.

Output files will retain folder structure under OptimizedPath.

---