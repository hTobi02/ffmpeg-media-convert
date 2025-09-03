<#
.SYNOPSIS
  Re-encodes videos recursively with adjustable FPS and bitrate while mirroring the folder structure.

.DESCRIPTION
  Walks a source folder recursively, finds video files, and writes converted files into a destination
  root while preserving subfolder structure. By default keeps audio/subtitles (copy).
  You can set target FPS (or keep original), and set a video bitrate (CBR style) or use CRF instead.
  Uses ffmpeg/ffprobe; make sure both are in PATH.

.PARAMETER SourcePath
  Root directory to scan for input videos (recursively).

.PARAMETER DestPath
  Root directory where converted files will be written (subfolders mirrored).

.PARAMETER TargetFps
  Desired FPS as a number (e.g. 24, 25, 30) or 'copy' to keep original. Default: 'copy'.

.PARAMETER AllowFpsUpsample
  If specified, allows increasing FPS above source FPS. By default, FPS is only reduced (downsample).

.PARAMETER VideoCodec
  Video codec to use (e.g. 'libx264', 'libx265', 'h264_nvenc', 'hevc_nvenc', 'av1_nvenc'). Default: 'libx264'.

.PARAMETER Preset
  Encoder preset passed to -preset (x264/x265) or -preset for NVENC. Default: 'medium'.

.PARAMETER VideoBitrate
  Target video bitrate (e.g. '5M', '12000k'). If set, CBR mode is used (-b:v plus optional -maxrate/-bufsize).

.PARAMETER MaxRate
  Optional maxrate (e.g. '6M') to cap VBV. Only used if VideoBitrate is set.

.PARAMETER BufSize
  Optional bufsize (e.g. '12M'). Only used if VideoBitrate is set.

.PARAMETER CRF
  Use constant rate factor instead of bitrate (e.g. 18–28). If set, VideoBitrate/MaxRate/BufSize are ignored.

.PARAMETER AudioMode
  'copy' to copy all audio tracks (default) or a specific codec (e.g. 'aac', 'ac3', 'libopus') to re-encode.

.PARAMETER AudioBitrate
  Audio bitrate when re-encoding audio (e.g. '160k'). Ignored if AudioMode='copy'.

.PARAMETER MapSubtitles
  Copy subtitle streams if present (default: On). Use -MapSubtitles:$false to disable.

.PARAMETER Overwrite
  Overwrite existing output files. Default: Off (skip existing).

.PARAMETER DryRun
  Print what would be done without running ffmpeg.

.PARAMETER Extensions
  File extensions to include. Default: .mkv,.mp4,.m4v,.avi,.mov,.webm

.PARAMETER Suffix
  Optional filename suffix before extension (e.g. '_opt'). Default: no suffix.

.PARAMETER Threads
  Optional threads for ffmpeg (-threads). Default: not set (ffmpeg decides).

.EXAMPLE
  .\Transcode-FpsBitrate.ps1 -SourcePath 'D:\Input' -DestPath 'E:\Output' `
    -TargetFps 25 -VideoBitrate '5M' -MaxRate '6M' -BufSize '12M' `
    -VideoCodec h264_nvenc -Preset p5 -Overwrite

.EXAMPLE
  # Only reduce FPS to 24 if higher; keep audio/subs; use CRF 20 with x265
  .\Transcode-FpsBitrate.ps1 -SourcePath 'D:\Input' -DestPath 'E:\Out' `
    -TargetFps 24 -VideoCodec libx265 -CRF 20 -Overwrite

.NOTES
  Author: htobi02 (adapted by ChatGPT), Version: 1.0
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory)][string]$SourcePath,
  [Parameter(Mandatory)][string]$DestPath,

  [Parameter()][Alias('fps')][string]$TargetFps = 'copy',
  [switch]$AllowFpsUpsample,

  [Parameter()][string]$VideoCodec = 'libx264',
  [Parameter()][string]$Preset,

  [Parameter()][string]$VideoBitrate,   # e.g. '5M'
  [Parameter()][string]$MaxRate,        # e.g. '6M'
  [Parameter()][string]$BufSize,        # e.g. '12M'
  [Parameter()][int]$CRF,               # e.g. 20 (if set, overrides bitrate mode)

  [Parameter()][ValidateSet('copy','aac','ac3','libopus','mp3','eac3','flac','copy:all')]
  [string]$AudioMode = 'copy',
  [Parameter()][string]$AudioBitrate,   # e.g. '160k'

  [Parameter()][bool]$MapSubtitles = $true,

  [switch]$Overwrite,
  [switch]$DryRun,

  [string[]]$Extensions = @('.mkv','.mp4','.m4v','.avi','.mov','.webm'),
  [string]$Suffix = '',
  [int]$Threads
)

function Get-VideoInfo {
  param([Parameter(Mandatory)][string]$Path)

  # JSON probe for fps & width/height and stream bitrates
  $json = & ffprobe -v error -select_streams v:0 `
    -show_entries stream=width,height,avg_frame_rate,codec_name,bit_rate `
    -of json -- "$Path" | ConvertFrom-Json

  if (-not $json.streams) { return $null }

  $s = $json.streams[0]
  # Parse X/Y fps rational safely
  $fps = $null
  if ($s.avg_frame_rate -and $s.avg_frame_rate -ne '0/0') {
    $parts = $s.avg_frame_rate -split '/'
    if ($parts.Count -eq 2 -and [double]$parts[1] -ne 0) {
      $fps = [double]$parts[0] / [double]$parts[1]
    }
  }
  return [pscustomobject]@{
    width   = $s.width
    height  = $s.height
    fps     = $fps
    vcodec  = $s.codec_name
    vbitrate= $s.bit_rate
  }
}

function Should-ChangeFps {
  param(
    [double]$SourceFps,
    [string]$TargetFps,
    [switch]$AllowUpsample
  )
  if ($TargetFps -eq 'copy' -or -not $TargetFps) { return $false }
  $t = [double]$TargetFps
  if (-not $AllowUpsample -and $t -gt $SourceFps) { return $false }
  # consider a tiny tolerance ~0.01 fps
  return ([math]::Abs($SourceFps - $t) -gt 0.01)
}

function New-OutputPath {
  param(
    [string]$InFile,
    [string]$FromRoot,
    [string]$ToRoot,
    [string]$Suffix
  )
  $rel = Resolve-Path -LiteralPath $InFile | ForEach-Object { $_.Path.Substring((Resolve-Path -LiteralPath $FromRoot).Path.Length).TrimStart('\','/') }
  $out = Join-Path -Path $ToRoot -ChildPath $rel
  $dir = Split-Path -Path $out -Parent
  $name = [System.IO.Path]::GetFileNameWithoutExtension($out)
  $ext = [System.IO.Path]::GetExtension($out)
  if ($Suffix) { $name = "$name$Suffix" }
  $final = Join-Path $dir "$name$ext"
  return @{ Directory = $dir; File = $final }
}

# --- Validations ---
if (-not (Test-Path -LiteralPath $SourcePath)) { throw "SourcePath not found: $SourcePath" }
if (-not (Test-Path -LiteralPath $DestPath))   { New-Item -ItemType Directory -Path $DestPath -Force | Out-Null }

# Gather files
$mask = $Extensions | ForEach-Object { "*$($_.Trim())" }
$files = Get-ChildItem -LiteralPath $SourcePath -Recurse -File |
  Where-Object { $Extensions -contains ([System.IO.Path]::GetExtension($_.Name).ToLowerInvariant()) } |
  Sort-Object FullName

if ($files.Count -eq 0) {
  Write-Host "No matching files under $SourcePath" -ForegroundColor Yellow
  return
}

Write-Host "Found $($files.Count) video(s)." -ForegroundColor Cyan

foreach ($f in $files) {
  try {
    $info = Get-VideoInfo -Path $f.FullName
    if (-not $info) {
      Write-Host "Skipping (no video stream): $($f.FullName)" -ForegroundColor DarkGray
      continue
    }

    $out = New-OutputPath -InFile $f.FullName -FromRoot $SourcePath -ToRoot $DestPath -Suffix $Suffix
    if (-not (Test-Path -LiteralPath $out.Directory)) {
      New-Item -ItemType Directory -Path $out.Directory -Force | Out-Null
    }

    if ((-not $Overwrite) -and (Test-Path -LiteralPath $out.File)) {
      Write-Host "Skip existing: $($out.File)" -ForegroundColor DarkGray
      continue
    }

    # Build ffmpeg args as array (avoids quoting hell)
    $args = @("-hide_banner", "-loglevel", "error", "-stats")
    if (-not $Overwrite) { $args += "-n" } else { $args += "-y" }
    $args += @("-i", $f.FullName)

    # FPS filter?
    $applyFps = $false
    if ($TargetFps -ne 'copy' -and $info.fps) {
      $applyFps = Should-ChangeFps -SourceFps $info.fps -TargetFps $TargetFps -AllowUpsample:$AllowFpsUpsample
    }

    $vfParts = @()
    if ($applyFps) { $vfParts += "fps=$TargetFps" }
    if ($vfParts.Count -gt 0) {
      $args += @("-vf", ($vfParts -join ",")) 
    }

    # Video codec & rate control
    $args += @("-c:v", $VideoCodec, "-preset", $Preset)

    if ($CRF) {
      # CRF mode: ignore VideoBitrate/MaxRate/BufSize
      $args += @("-crf", "$CRF")
    } elseif ($VideoBitrate) {
      $args += @("-b:v", $VideoBitrate)
      if ($MaxRate) { $args += @("-maxrate", $MaxRate) }
      if ($BufSize) { $args += @("-bufsize", $BufSize) }
    }

    if ($Threads -gt 0) { $args += @("-threads", "$Threads") }

    # Audio
    if ($AudioMode -eq 'copy' -or $AudioMode -eq 'copy:all') {
      $args += @("-c:a", "copy")
    } else {
      $args += @("-c:a", $AudioMode)
      if ($AudioBitrate) { $args += @("-b:a", $AudioBitrate) }
      # If multiple audio tracks exist, re-encode all with same settings
    }

    # Subtitles
    if ($MapSubtitles) {
      $args += @("-map", "0", "-map_metadata", "0", "-map_chapters", "0", "-c:s", "copy")
    } else {
      # no subtitle mapping; map all audio+video explicitly
      $args += @("-map", "0:v", "-map", "0:a?")
    }

    # Output path
    $args += @($out.File)

    # Show what we do
    $desc = "-> $($out.File)  [src fps: {0:N3}{1}]" -f $info.fps, ($(if ($applyFps) { " -> $TargetFps" } else { "" }))
    Write-Host "Processing: $($f.FullName)" -ForegroundColor Green
    Write-Host $desc -ForegroundColor Gray

    if ($DryRun) {
      Write-Host "DryRun ffmpeg: ffmpeg $($args -join ' ')" -ForegroundColor DarkCyan
    } else {
      & ffmpeg @args
      if ($LASTEXITCODE -ne 0) {
        Write-Host "ffmpeg failed for: $($f.FullName)" -ForegroundColor Red
      }
    }
  }
  catch {
    Write-Host "Error on file: $($f.FullName)`n$($_.Exception.Message)" -ForegroundColor Red
  }
}
