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

.PARAMETER MergeAudio
  If set and the file has multiple audio streams, merge/mix them into a single stream via amix.

.PARAMETER NormalizeAudio
  If set, normalize each audio stream via EBU R128 loudnorm before mapping/merging.

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

.NOTES
  Author: htobi02 (adapted by ChatGPT), Version: 1.2 (adds extensive Write-Verbose instrumentation)
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory)][string]$SourcePath,
  [Parameter(Mandatory)][string]$DestPath,

  [Parameter()][Alias('fps')][string]$TargetFps = 'copy',
  [switch]$AllowFpsUpsample,

  [Parameter()][string]$VideoCodec = 'libx264',
  [Parameter()][string]$Preset,

  [Parameter()][string]$VideoBitrate,
  [Parameter()][string]$MaxRate,
  [Parameter()][string]$BufSize,
  [Parameter()][int]$CRF,

  [Parameter()][ValidateSet('copy','aac','ac3','libopus','mp3','eac3','flac','copy:all')]
  [string]$AudioMode = 'copy',
  [Parameter()][string]$AudioBitrate,

  [Parameter()][bool]$MapSubtitles = $true,

  [switch]$MergeAudio,
  [switch]$NormalizeAudio,

  [switch]$Overwrite,
  [switch]$DryRun,

  [string[]]$Extensions = @('.mkv','.mp4','.m4v','.avi','.mov','.webm'),
  [string]$Suffix = '',
  [int]$Threads
)

# ---- Verbose standardmäßig aktivieren (nur Skript-Scope) ----
$__prevVerbose = $VerbosePreference
$VerbosePreference = 'Continue'
$__scriptStart = Get-Date
Write-Verbose ("[INIT] Script start: {0:yyyy-MM-dd HH:mm:ss}" -f $__scriptStart)

# ---- Umgebungsinfo / Tools ----
try {
  $os = [System.Environment]::OSVersion.VersionString
  Write-Verbose "[ENV] OS: $os"
  Write-Verbose "[ENV] PowerShell: $($PSVersionTable.PSVersion)"
  Write-Verbose "[ENV] Current Dir: $(Get-Location)"
  Write-Verbose "[ENV] TEMP: $($env:TEMP)"
  $ffprobeVer = (& ffprobe -hide_banner -version 2>$null | Select-Object -First 1)
  $ffmpegVer  = (& ffmpeg  -hide_banner -version 2>$null | Select-Object -First 1)
  if ($ffprobeVer) { Write-Verbose "[TOOL] ffprobe: $ffprobeVer" } else { Write-Verbose "[TOOL] ffprobe not found in PATH?" }
  if ($ffmpegVer)  { Write-Verbose "[TOOL] ffmpeg : $ffmpegVer" } else { Write-Verbose "[TOOL] ffmpeg not found in PATH?" }
} catch {
  Write-Verbose "[ENV] Tool/version probe failed: $($_.Exception.Message)"
}

# ---- Parameter-Dump ----
Write-Verbose "[PARAMS] Effective parameters:"
$PSBoundParameters.GetEnumerator() | Sort-Object Key | ForEach-Object {
  $v = $_.Value
  if ($v -is [Array]) { $v = $v -join ', ' }
  Write-Verbose ("  - {0} = {1}" -f $_.Key, $v)
}
Write-Verbose ("[DEFAULTS] Unbound defaults => TargetFps={0}, VideoCodec={1}, MapSubtitles={2}, Extensions={3}" -f $TargetFps,$VideoCodec,$MapSubtitles,($Extensions -join ','))

function Get-VideoInfo {
  param([Parameter(Mandatory)][string]$Path)
  Write-Verbose "[ffprobe] Query video stream info: $Path"

  $jsonRaw = & ffprobe -v error -select_streams v:0 `
    -show_entries stream=width,height,avg_frame_rate,codec_name,bit_rate `
    -of json -- "$Path"

  if (-not $jsonRaw) {
    Write-Verbose "[ffprobe] No JSON returned for video stream."
    return $null
  }

  try {
    $json = $jsonRaw | ConvertFrom-Json
  } catch {
    Write-Verbose "[ffprobe] JSON parse failed: $($_.Exception.Message)"
    return $null
  }

  if (-not $json.streams) {
    Write-Verbose "[ffprobe] No 'streams' in JSON."
    return $null
  }

  $s = $json.streams[0]
  $fps = $null
  if ($s.avg_frame_rate -and $s.avg_frame_rate -ne '0/0') {
    $parts = $s.avg_frame_rate -split '/'
    if ($parts.Count -eq 2 -and [double]$parts[1] -ne 0) {
      $fps = [double]$parts[0] / [double]$parts[1]
    }
  }
  Write-Verbose ("[ffprobe] vcodec={0}, {1}x{2}, fps≈{3:N3}, vbitrate={4}" -f $s.codec_name,$s.width,$s.height,$fps,$s.bit_rate)
  return [pscustomobject]@{
    width    = $s.width
    height   = $s.height
    fps      = $fps
    vcodec   = $s.codec_name
    vbitrate = $s.bit_rate
  }
}

function Get-AudioStreamIndices {
  param([Parameter(Mandatory)][string]$Path)
  Write-Verbose "[ffprobe] Query audio indices: $Path"
  $ajRaw = & ffprobe -v error -select_streams a -show_entries stream=index -of json -- "$Path"
  if (-not $ajRaw) {
    Write-Verbose "[ffprobe] No JSON for audio streams."
    return @()
  }
  try {
    $aj = $ajRaw | ConvertFrom-Json
  } catch {
    Write-Verbose "[ffprobe] JSON parse failed for audio streams: $($_.Exception.Message)"
    return @()
  }
  if (-not $aj.streams) { Write-Verbose "[ffprobe] No audio streams."; return @() }
  $idx = @($aj.streams | ForEach-Object { [int]$_.index })
  Write-Verbose "[ffprobe] Audio stream indices: $($idx -join ', ')"
  return $idx
}

function Should-ChangeFps {
  param(
    [double]$SourceFps,
    [string]$TargetFps,
    [switch]$AllowUpsample
  )
  Write-Verbose ("[FPS] Decide: src={0:N3}, target={1}, allow-up={2}" -f $SourceFps,$TargetFps,$AllowUpsample.IsPresent)
  if ($TargetFps -eq 'copy' -or -not $TargetFps) { Write-Verbose "[FPS] target='copy' → no change."; return $false }
  $t = [double]$TargetFps
  if (-not $AllowUpsample -and $t -gt $SourceFps) { Write-Verbose "[FPS] Upsample not allowed and target>src → no change."; return $false }
  $change = ([math]::Abs($SourceFps - $t) -gt 0.01)
  Write-Verbose "[FPS] change? $change"
  return $change
}

function New-OutputPath {
  param(
    [string]$InFile,
    [string]$FromRoot,
    [string]$ToRoot,
    [string]$Suffix
  )
  Write-Verbose "[PATH] Build output path for: $InFile"
  $srcRoot = (Resolve-Path -LiteralPath $FromRoot).Path
  $absIn   = (Resolve-Path -LiteralPath $InFile).Path
  $rel     = $absIn.Substring($srcRoot.Length).TrimStart('\','/')
  $out     = Join-Path -Path $ToRoot -ChildPath $rel
  $dir     = Split-Path -Path $out -Parent
  $name    = [System.IO.Path]::GetFileNameWithoutExtension($out)
  $ext     = [System.IO.Path]::GetExtension($out)
  if ($Suffix) { $name = "$name$Suffix" }
  $final   = Join-Path $dir "$name$ext"
  $tempDir = if ($env:TEMP -and $env:TEMP.Trim()) { $env:TEMP } else { '/tmp' }
  $temp    = Join-Path $tempDir "$name$ext"
  Write-Verbose ("[PATH] dir={0} | file={1} | temp={2}" -f $dir,$final,$temp)
  return @{ Directory = $dir; File = $final; Temp = $temp }
}

# --- Validations ---
Write-Verbose "[CHECK] Validate paths"
if (-not (Test-Path -LiteralPath $SourcePath)) { throw "SourcePath not found: $SourcePath" }
if (-not (Test-Path -LiteralPath $DestPath))   {
  Write-Verbose "[CHECK] DestPath does not exist. Creating: $DestPath"
  New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
}

# Gather files
Write-Verbose "[SCAN] Extensions: $($Extensions -join ', ')"
$mask = $Extensions | ForEach-Object { "*$($_.Trim())" }
Write-Verbose "[SCAN] Enumerate files under: $SourcePath"
$files = Get-ChildItem -LiteralPath $SourcePath -Recurse -File |
  Where-Object { $Extensions -contains ([System.IO.Path]::GetExtension($_.Name).ToLowerInvariant()) } |
  Sort-Object FullName

# Gather base temp path (Fallback: /tmp)
$baseTemp = if ($env:TEMP -and $env:TEMP.Trim()) { $env:TEMP } else { '/tmp' }
New-Item -ItemType Directory -Path $baseTemp -Force -ErrorAction SilentlyContinue | Out-Null
Write-Verbose "[ENV] Base temp: $baseTemp"

if ($files.Count -eq 0) {
  Write-Host "No matching files under $SourcePath" -ForegroundColor Yellow
  Write-Verbose "[END] Nothing to do."
  $VerbosePreference = $__prevVerbose
  return
}

Write-Host "Found $($files.Count) video(s)." -ForegroundColor Cyan
Write-Verbose "[SCAN] Found $($files.Count) file(s) to process."

# Processing loop
$idx = 0
foreach ($f in $files) {
  $idx++
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  Write-Verbose ("`n[FILE {0}/{1}] Start: {2}" -f $idx,$files.Count,$f.FullName)
  try {
    $info = Get-VideoInfo -Path $f.FullName
    if (-not $info) {
      Write-Host "Skipping (no video stream): $($f.FullName)" -ForegroundColor DarkGray
      Write-Verbose "[FILE] Skip reason: no video stream info."
      continue
    }

    $aIdx = Get-AudioStreamIndices -Path $f.FullName
    $aCount = $aIdx.Count
    Write-Verbose "[AUDIO] Streams count: $aCount"

    $out = New-OutputPath -InFile $f.FullName -FromRoot $SourcePath -ToRoot $DestPath -Suffix $Suffix
    if (-not (Test-Path -LiteralPath $out.Directory)) {
      Write-Verbose "[PATH] Create directory: $($out.Directory)"
      New-Item -ItemType Directory -Path $out.Directory -Force | Out-Null
    }

    if ((-not $Overwrite) -and (Test-Path -LiteralPath $out.File)) {
      Write-Host "Skip existing: $($out.File)" -ForegroundColor DarkGray
      Write-Verbose "[FILE] Existing output and -Overwrite not set → skipping."
      continue
    }

    # Build ffmpeg args as array
    $args = @("-hide_banner", "-loglevel", "error", "-stats")
    $args += "-y"
    $args += @("-i", $f.FullName)

    # FPS filter?
    $applyFps = $false
    if ($TargetFps -ne 'copy' -and $info.fps) {
      $applyFps = Should-ChangeFps -SourceFps $info.fps -TargetFps $TargetFps -AllowUpsample:$AllowFpsUpsample
    } else {
      Write-Verbose ("[FPS] Skip FPS evaluation (target='{0}', srcFPS={1})" -f $TargetFps,$info.fps)
    }

    $vfParts = @()
    if ($applyFps) {
      $vfParts += "fps=$TargetFps"
      Write-Verbose "[VF] Add fps filter: fps=$TargetFps"
    }
    if ($vfParts.Count -gt 0) {
      $vfJoined = ($vfParts -join ",")
      $args += @("-vf", $vfJoined)
      Write-Verbose "[VF] Final -vf: $vfJoined"
    } else {
      Write-Verbose "[VF] No video filter chain."
    }

    # Video codec & rate control
    $args += @("-c:v", $VideoCodec)
    Write-Verbose "[VIDEO] Codec: $VideoCodec"
    if ($Preset) { $args += @("-preset", $Preset); Write-Verbose "[VIDEO] Preset: $Preset" }
    if ($CRF) {
      $args += @("-crf", "$CRF")
      Write-Verbose "[VIDEO] Using CRF mode: CRF=$CRF (bitrate settings ignored)"
    } elseif ($VideoBitrate) {
      $args += @("-b:v", $VideoBitrate)
      Write-Verbose "[VIDEO] Using CBR-like: b:v=$VideoBitrate"
      if ($MaxRate) { $args += @("-maxrate", $MaxRate); Write-Verbose "[VIDEO]   maxrate=$MaxRate" }
      if ($BufSize) { $args += @("-bufsize", $BufSize); Write-Verbose "[VIDEO]   bufsize=$BufSize" }
    } else {
      Write-Verbose "[VIDEO] No CRF/Bitrate set → encoder defaults/quality-driven."
    }
    if ($Threads -gt 0) { $args += @("-threads", "$Threads"); Write-Verbose "[VIDEO] Threads: $Threads" }

    # --- Audio: normalize / merge filter graph (robust) ---
    $needsFC = $NormalizeAudio -or ($MergeAudio -and $aCount -gt 1)
    $filterComplex = $null
    $audioMapArgs = @()

    Write-Verbose ("[AUDIO] Normalize={0}, Merge={1}, Streams={2}" -f $NormalizeAudio.IsPresent,$MergeAudio.IsPresent,$aCount)

    if ($needsFC -and $aCount -gt 0) {
      $fcParts = @()
      $preLabels = @()

      for ($i = 0; $i -lt $aCount; $i++) {
        $src = "[0:a:$i]"
        $mid = "[apre$i]"
        if ($NormalizeAudio) {
          $fc = "$src loudnorm=I=-16:TP=-1.5:LRA=11, aresample=async=1:min_hard_comp=0.100:first_pts=0, aformat=sample_rates=48000:channel_layouts=stereo $mid"
          Write-Verbose "[AUDIO/FC] + normalize+resample chain for a:$i"
        } else {
          $fc = "$src aresample=async=1:min_hard_comp=0.100:first_pts=0, aformat=sample_rates=48000:channel_layouts=stereo $mid"
          Write-Verbose "[AUDIO/FC] + resample chain for a:$i"
        }
        $fcParts += $fc
        $preLabels += $mid
      }

      if ($MergeAudio -and $aCount -gt 1) {
        $amix = "$($preLabels -join '') amix=inputs=$($aCount):duration=longest:normalize=1 [aout]"
        $fcParts += $amix
        $audioMapArgs += @("-map","[aout]")
        Write-Verbose "[AUDIO/FC] + amix with inputs=$aCount"
      } else {
        foreach ($lab in $preLabels) { $audioMapArgs += @("-map",$lab) }
        Write-Verbose "[AUDIO/FC] Map each preprocessed track individually."
      }

      $filterComplex = ($fcParts -join ";")
      Write-Verbose "[AUDIO/FC] filter_complex: $filterComplex"
    } else {
      Write-Verbose "[AUDIO] No filter_complex needed."
    }

    # Subtitles + mapping
    if ($filterComplex) {
      $args += @("-filter_complex", $filterComplex)

      # Map video and (optionally) subtitles
      $args += @("-map","0:v")
      Write-Verbose "[MAP] -map 0:v"
      if ($MapSubtitles) {
        $args += @("-map","0:s?","-c:s","copy","-map_metadata","0","-map_chapters","0")
        Write-Verbose "[MAP] Subtitles on: -map 0:s? -c:s copy, metadata & chapters copied"
      } else {
        $args += @("-map_metadata","0","-map_chapters","0")
        Write-Verbose "[MAP] Subtitles off: metadata & chapters copied"
      }

      # Map the filtered audio labels
      $args += $audioMapArgs
      Write-Verbose "[MAP] Audio maps: $($audioMapArgs -join ' ')"

      # Choose audio codec (can't be copy when filters are used)
      $audioCodecActual = $AudioMode
      $audioBitrateActual = $AudioBitrate
      if ($audioCodecActual -eq 'copy' -or $audioCodecActual -eq 'copy:all') {
        Write-Host "AudioMode 'copy' not possible with Merge/Normalize. Using AAC re-encode." -ForegroundColor Yellow
        Write-Verbose "[AUDIO] Force re-encode because filters present."
        $audioCodecActual = 'aac'
        if (-not $audioBitrateActual) { $audioBitrateActual = '192k' }
      }
      if (-not $audioBitrateActual) { $audioBitrateActual = '192k' }
      $args += @(
        "-c:a", $audioCodecActual,
        "-b:a", $audioBitrateActual,
        "-ar", "48000",
        "-ac", "2"
      )
      Write-Verbose "[AUDIO] Codec=$audioCodecActual, Bitrate=$audioBitrateActual, 48kHz, stereo"

    } else {
      # No audio filters: behave like before
      if ($MapSubtitles) {
        $args += @("-map", "0", "-map_metadata", "0", "-map_chapters", "0", "-c:s", "copy")
        Write-Verbose "[MAP] -map 0 (all); subtitles copied; metadata/chapters copied"
      } else {
        $args += @("-map", "0:v", "-map", "0:a?")
        Write-Verbose "[MAP] -map 0:v and 0:a?; subtitles OFF"
      }

      if ($AudioMode -eq 'copy' -or $AudioMode -eq 'copy:all') {
        $args += @("-c:a", "copy")
        Write-Verbose "[AUDIO] Copy audio"
      } else {
        $args += @("-c:a", $AudioMode)
        $ab = if ($AudioBitrate) { $AudioBitrate } else { "192k" }
        $args += @("-b:a", $ab, "-ar", "48000", "-ac", "2")
        Write-Verbose "[AUDIO] Re-encode: codec=$AudioMode, bitrate=$ab, 48kHz, stereo"
      }
    }

    # Muxing Queue
    $args += @("-max_muxing_queue_size","4096")
    Write-Verbose "[MUX] max_muxing_queue_size=4096"

    # if hevc-codec set right tags
    if ($VideoCodec -match "hevc|libx265") {
      $args += @("-tag:v", "hvc1")
      Write-Verbose "[VIDEO] HEVC detected → tag:v=hvc1"
    }

    # Output path
    $args += @($out.temp)
    Write-Verbose "[OUT] Output temp file: $($out.temp)"
    Write-Verbose "[OUT] Final move target: $($out.File)"

    # Progress
    $desc = "-> $($out.File) (Temp: $($out.temp))  [src fps: {0:N3}{1}]" -f $info.fps, ($(if ($applyFps) { " -> $TargetFps" } else { "" }))
    Write-Host "Processing: $($f.FullName)" -ForegroundColor Green
    Write-Host $desc -ForegroundColor Gray

    # Show full command line in verbose
    Write-Verbose ("[CMD] ffmpeg {0}" -f ($args -join ' '))

    if ($DryRun) {
      Write-Host "DryRun ffmpeg: ffmpeg $($args -join ' ')" -ForegroundColor DarkCyan
      Write-Verbose "[DRYRUN] Skipping execution."
    } else {
      & ffmpeg @args
      $code = $LASTEXITCODE
      Write-Verbose "[EXEC] ffmpeg exit code: $code"
      if ($code -ne 0) {
        Write-Host "ffmpeg failed for: $($f.FullName)" -ForegroundColor Red
        Write-Verbose "[EXEC] Failure → no move performed."
      } else {
        Write-Verbose "[MOVE] Moving temp to final: '$($out.temp)' → '$($out.File)'"
        Move-Item -Path @($out.temp) -Destination $($out.File) -Force
        Write-Verbose "[MOVE] Done."
      }
    }
  }
  catch {
    Write-Host "Error on file: $($f.FullName)`n$($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose ("[ERROR] {0}" -f $_.Exception.ToString())
  }
  finally {
    $sw.Stop()
    Write-Verbose ("[FILE] Duration: {0:N2}s" -f $sw.Elapsed.TotalSeconds)
  }
}

$__scriptEnd = Get-Date
Write-Verbose ("[END] Script end:   {0:yyyy-MM-dd HH:mm:ss}" -f $__scriptEnd)
Write-Verbose ("[END] Total runtime: {0:N2}s" -f ($__scriptEnd - $__scriptStart).TotalSeconds)

# Restore original verbose pref
$VerbosePreference = $__prevVerbose
