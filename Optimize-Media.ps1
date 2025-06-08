<#
.SYNOPSIS
    DE: Konvertiert Videodateien in verschiedene Qualitaetsstufen mit individuell einstellbaren Codecs und Bitraten.
    EN: Converts video files into different quality levels with customizable codecs and bitrates.

.DESCRIPTION
    DE: Dieses Skript verarbeitet eine oder mehrere Videodateien und erstellt neue Ausgabedateien im angegebenen Zielverzeichnis.
        Es unterstuetzt verschiedene Video-/Audio-Codecs und Bitraten, je nach Zielaufloesung.
        Die Konvertierung erfolgt ueber ffmpeg und kann flexibel angepasst werden.
    
    EN: This script processes one or more video files and generates new output files in the specified target directory.
        It supports different video/audio codecs and bitrates depending on the target resolution.
        Conversion is handled by ffmpeg and can be customized easily.

.PARAMETER OriginalPath
    DE: Pfad(e) zu den Quelldateien.
    EN: Path(s) to the source video file(s).

.PARAMETER OptimizedPath
    DE: Pfad(e) fuer die Zieldateien nach Konvertierung.
    EN: Path(s) for the converted output files.

.PARAMETER VideoCodec
    DE: Gewuenschter Videocodec (z.B. 'libx265', 'libx264').
    EN: Desired video codec (e.g., 'libx265', 'libx264').

.PARAMETER AudioCodec
    DE: Gewuenschter Audiocodec (z.B. 'aac', 'copy').
    EN: Desired audio codec (e.g., 'aac', 'copy').

.PARAMETER Bitrate4320p
    DE: Zielbitrate fuer 8K-Videos.
    EN: Target bitrate for 8K (4320p) videos.

.PARAMETER Bitrate3456p
    DE: Zielbitrate fuer 6K-Videos.
    EN: Target bitrate for 6K (3456p) videos.

.PARAMETER Bitrate2880p
    DE: Zielbitrate fuer 5K-Videos.
    EN: Target bitrate for 5K (2880p) videos.

.PARAMETER Bitrate2160p
    DE: Zielbitrate fuer 4K-Videos.
    EN: Target bitrate for 4K (2160p) videos.

.PARAMETER Bitrate1440p
    DE: Zielbitrate fuer 1440p-Videos.
    EN: Target bitrate for 1440p videos.

.PARAMETER Bitrate1080p
    DE: Zielbitrate fuer Full HD-Videos.
    EN: Target bitrate for Full HD (1080p) videos.

.PARAMETER Bitrate720p
    DE: Zielbitrate fuer HD-Videos.
    EN: Target bitrate for HD (720p) videos.

.PARAMETER Bitrate480p
    DE: Zielbitrate fuer SD-Videos.
    EN: Target bitrate for SD (480p) videos.

.PARAMETER DenyTonemap
    DE: Verhindere, dass HDR zu SDR gefiltert wird.
    EN: Prevent HDR from being filtered to SDR.

.EXAMPLE
    DE: Beispielaufruf (erstellt nur Versionen fuer 2160p und 1080p):
    EN: Example call (only creates versions for 2160p and 1080p):

    .\Convert-Videos.ps1 -OriginalPath "C:\Input" `
                         -OptimizedPath "C:\Output" `
                         -VideoCodec "libx264" -AudioCodec "ac3" `
                         -Bitrate2160p "12000k" -Bitrate1080p "5M"

.NOTES
    DE: Autor: github.com/htobi02 - Version: 0.2 - Erstellt: 2025-04-23
    EN: Author: github.com/htobi02 - Version: 0.2 - Created: 2025-04-23
#>
Param(
    [parameter(Mandatory=$true)][String[]]$OriginalPath,
    [parameter(Mandatory=$true)][String[]]$OptimizedPath,
    $VideoCodec,
    $AudioCodec,
    $Bitrate4320p,
    $Bitrate3456p,
    $Bitrate2880p,
    $Bitrate2160p,
    $Bitrate1440p,
    $Bitrate1080p,
    $Bitrate720p,
    $Bitrate480p,
    [boolean]$DenyTonemap,
    [boolean]$AudioToStereo
)

function Test-IsHDR {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VideoFile
    )
    
    if (-Not (Test-Path $($VideoFile.Replace("[","``[").Replace("]","``]")))) {
        Write-Host "Video File not found: $VideoFile" -ForegroundColor Red
        return
    }

    $streamInfo = & ffprobe -select_streams v:0 -show_streams -v error "$VideoFile" | Where-Object {
        $_ -match '^color_transfer=|^color_space=|^color_primaries='
    }

    $COLORSPACE = $null
    $COLORTRANSFER = $null
    $COLORPRIMARIES = $null

    foreach ($line in $streamInfo) {
        if ($line -like "color_space=*") {
            $COLORSPACE = $line -replace "color_space=", ""
        } elseif ($line -like "color_transfer=*") {
            $COLORTRANSFER = $line -replace "color_transfer=", ""
        } elseif ($line -like "color_primaries=*") {
            $COLORPRIMARIES = $line -replace "color_primaries=", ""
        }
    }

    return ($COLORSPACE -eq "bt2020nc" -and $COLORPRIMARIES -eq "bt2020" -and (($COLORTRANSFER -eq "smpte2084") -or ($COLORTRANSFER -eq "smpte2086") -or ($COLORTRANSFER -like "bt2020*") -or ($COLORTRANSFER -eq "arib-std-b67")))
}

function Test-DoVi {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VideoFile
    )
    
    if (-Not (Test-Path $($VideoFile.Replace("[","``[").Replace("]","``]")))) {
        Write-Host "Video File not found: $VideoFile" -ForegroundColor Red
        return
    }
    $dvData = (& ffprobe -v error -select_streams v:0 -show_streams -show_format -of json $VideoFile | ConvertFrom-Json).streams.side_data_list
    
    # Ausgabe
    if ($dvData) {
        return $dvData
    } else {
        return $false
    }
}

function Get-AutoCrop {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VideoFile,
        [int]$DetectDuration = 60
    )
    # Test-Path mit -LiteralPath, damit [ ] nicht als Wildcards interpretiert werden
    if (-Not (Test-Path -LiteralPath $VideoFile)) {
        Write-Host "Video File not found for crop detection: $VideoFile" -ForegroundColor Yellow
        return ""
    }

    # Ermittel Crop-Parameter der ersten $DetectDuration Sekunden
    $args = @(
        "-hide_banner", "-ss", "00:01:00", "-t", $DetectDuration,
        "-i", $VideoFile, "-vf", "cropdetect",
        "-f", "null", "-"
    )
    $output = & ffmpeg @args 2>&1

    Write-Verbose "Crop Output: $($output | Select-String -Pattern "crop=\d+:\d+:\d+:\d+")"

    # letzte crop= Zeile parsen
    $cropLine = ($output |
        Select-String -Pattern "crop=\d+:\d+:\d+:\d+" |
        ForEach-Object { $_.Matches.Value })[-1]

    return $cropLine
}


function Convert-BitrateToBps {
    param (
        [Parameter(Mandatory)]
        [string]$Bitrate
    )

    # Bereinige Whitespace
    $Bitrate = $Bitrate.Trim()

    # Prüfe und konvertiere die Einheit
    if ($Bitrate -match '^(\d+)([kKmM]?)$') {
        $value = [int]$matches[1]
        $unit = $matches[2].ToLower()

        switch ($unit) {
            'k' { return $value * 1000 }
            'm' { return $value * 1000000 }
            default { return $value }
        }
    }
    else {
        throw "Ungültiges Bitratenformat: '$Bitrate'"
    }
}

function Get-AudioInfo {
    param ([string]$File)
    $audioStream = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,profile,channel_layout -of default=nw=1:nk=1 "$File"
    $audioInfo = $audioStream -split "`n"
    return @{
        codec = $audioInfo[0]
        profile = $audioInfo[1]
        layout = $audioInfo[2]
    }
}

function Convert-AudioTag {
    param ([string]$Codec)

    switch -Regex ($Codec.ToLower()) {
        'aac'             { return 'AAC' }
        'ac3'             { return 'AC3' }
        'eac3'            { return 'EAC3' }
        'dts'             { return 'DTS' }
        'dts_hd'          { return 'DTS-HD MA' }
        'truehd'          { return 'TrueHD' }
        'truehd_atmos'    { return 'TrueHD Atmos' }
        default           { return $Codec.ToUpper() }
    }
}

function Get-AudioStereoMapping {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string] $InputFile
    )

    Write-Verbose "==> Starting Get-AudioStereoMapping for file: $InputFile"

    # ffprobe JSON auslesen, inkl. language-Tag
    $json = & ffprobe -v error -select_streams a `
        -show_entries stream=index,channels,channel_layout:stream_tags=language `
        -of json "$InputFile" |
        ConvertFrom-Json

    Write-Verbose "Found $($json.streams.Count) audio stream(s)."

    $filters   = @()
    $maps      = @()
    $metas     = @()
    $seenLang  = @{}
    $outCount  = 0

    foreach ($stream in $json.streams) {
        # ffprobe index ist 1-basiert
        $idx = $stream.index -1
        Write-Verbose "Stream raw index: $idx"

        # Sprache ermitteln, fallback auf "und" (undetermined)
        $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
        Write-Verbose "Processing stream idx=$($idx): channels=$($stream.channels), language=$lang"

        # Wenn diese Sprache schon gemappt wurde, überspringen
        if ($seenLang.ContainsKey($lang)) {
            Write-Verbose "Skipping stream idx=$idx because language '$lang' is already mapped."
            continue
        }
        $seenLang[$lang] = $true

        $ch        = $stream.channels
        $inLabel   = "[0:a:$idx]"
        $outLabel  = "[aout$outCount]"

        switch ($ch) {
            1 {
                $pan = "pan=stereo|c0=c0|c1=c0"
                Write-Verbose "Built MONO->STEREO pan: $pan"
            }
            2 {
                $pan = "anull"
                Write-Verbose "Built STEREO passthrough pan: $pan"
            }
            6 {
                Write-Verbose "Building 5.1(side)->STEREO pan"
                $leftIdx   = @(0,4);    $rightIdx  = @(1,5);    $centerIdx = @(2)
                $mixLeft   = ( ($leftIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $mixRight  = ( ($rightIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $pan       = "pan=stereo|c0=$mixLeft|c1=$mixRight"
                Write-Verbose "Built pan: $pan"
            }
            8 {
                Write-Verbose "Building 7.1->STEREO pan"
                $leftIdx   = @(0,4,6);  $rightIdx  = @(1,5,7);  $centerIdx = @(2)
                $mixLeft   = ( ($leftIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $mixRight  = ( ($rightIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $pan       = "pan=stereo|c0=$mixLeft|c1=$mixRight"
                Write-Verbose "Built pan: $pan"
            }
            default {
                Write-Verbose "Building fallback pan for $ch channels"
                $all  = 0..($ch - 1) | ForEach-Object { "c$_" } -join "+"
                $pan  = "pan=stereo|c0=$all|c1=$all"
                Write-Verbose "Built fallback pan: $pan"
            }
        }

        # Filter, Map und Metadata sammeln
        $filters += "$inLabel $pan $outLabel"
        $maps    += "-map $outLabel"
        $metas   += "-metadata:s:a:$outCount language=$lang"

        $outCount++
    }

    Write-Verbose "Generated $($filters.Count) filter(s), $($maps.Count) map(s) and $($metas.Count) meta(s)."
    return @{ Filters = $filters; Maps = $maps; Metas = $metas }
}


function Convert-Video {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]   $InputFile,
        [Parameter(Mandatory)][string]   $OutputDirectory,
        [Parameter(Mandatory)][string]   $VideoCodec,
        [Parameter(Mandatory)][string]   $AudioCodec,
        [Parameter(Mandatory)][hashtable] $BitrateMap,
        [boolean]                        $DenyTonemap,
        [boolean]                        $AudioToStereo
    )
    Write-Verbose "==> Starting Convert-Video for '$($InputFile.Name)'"

    # --- Validierung ---
    if (-not $VideoCodec) { Write-Host "Missing video codec. Abort." -ForegroundColor Red; return }
    if (-not $AudioCodec) { Write-Host "Missing audio codec. Abort." -ForegroundColor Red; return }

    # --- HDR / Tonemap ---
    if (-not $DenyTonemap) {
        $isHDR  = Test-IsHDR -VideoFile $InputFile.FullName
        $isDoVi = Test-DoVi  -VideoFile $InputFile.FullName
        if ($isDoVi.dv_profile -eq 5) {
            Write-Host "Unsupported DoVi profile: $($isDoVi.dv_profile)" -ForegroundColor Red; return
        } elseif ($isHDR) {
            $tonemapFilter = "zscale=t=linear:npl=100,format=gbrpf32le," +
                             "zscale=p=bt709,tonemap=tonemap=hable:desat=0," +
                             "zscale=t=bt709:m=bt709:r=tv,format=yuv420p,"
            $optimizedName  = $InputFile.BaseName -replace '\[(DV\s+)?(HDR|HDR10|HDR10Plus?(\+|Plus)?|DV|HDR10Plus)\]', ''
        } else {
            $tonemapFilter = ""; $optimizedName = $InputFile.BaseName
        }
    } else {
        $tonemapFilter = ""; $optimizedName = $InputFile.BaseName
    }

    # --- AutoCrop ---
    $cropParams = Get-AutoCrop -VideoFile "$($InputFile.FullName)" -DetectDuration 5
    Write-Verbose "Crop Params: $cropParams"
    if ($cropParams) { $cropFilter = "$cropParams," } else { $cropFilter = "" }

    # --- Video-Auflösung ermitteln ---
    $videoStream = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$($InputFile.FullName)"
    $parts       = $videoStream -split ","
    $videoWidth  = [int]$parts[0]

    # --- Dauer & Dateigröße ---
    $durSize      = & ffprobe -v error -show_entries format=duration,size -of csv=p=0 "$($InputFile.FullName)"
    $dsParts      = $durSize -split ","
    $duration     = [double]$dsParts[0]
    $filesize     = [double]$dsParts[1]
    $videoBitrate = $filesize / ($duration/60*0.0075) / 1000

    # --- Name anpassen bei neuem Audio-Codec ---
    if ($AudioCodec -ne "copy") {
        $AudioInfo     = Get-AudioInfo -File $InputFile.FullName
        $AudioReplace  = if ($AudioInfo.profile -eq "unknown") { $AudioInfo.codec.ToUpper() } else { $AudioInfo.profile }
        $tag           = Convert-AudioTag -Codec $AudioCodec
        $optimizedName = $optimizedName -replace $AudioReplace, $tag
        if ($AudioToStereo) {
            $optimizedName = $optimizedName -replace '\[([^\]]+?)\s+[0-9]+\.[0-9]+\]', '[$1 2.0]'
        }
    }

    # --- Video-Outputs konfigurieren ---
    $splitCount = 0; $Outputs = @()
    foreach ($resolution in $BitrateMap.Keys) {
        $width    = switch ($resolution) {
            "4320p" { 7680 }; "3456p" { 6144 }; "2880p" { 5120 };
            "2160p" { 3840 }; "1440p" { 2560 }; "1080p" { 1920 };
            "720p"  { 1280 }; "480p"  { 858 }
        }
        $bitrate = $BitrateMap[$resolution]
        if (-not $bitrate -or $width -gt $videoWidth) { continue }
        Write-Verbose "readying up resolution $resolution"

        $outName     = $optimizedName `
            -replace '\[(Bluray|WEBDL|WEB|Remux|HDTV|DVDRip|BRRip)-\d+p.*?\]', "[Optimized-$resolution]" `
            -replace '\[x\d+\]|\[x264\]|\[x265\]|\[hevc\]|\[av1\]|\[vc1\]\[vp9\]', "[$($VideoCodec -replace 'lib','')]"
        $outputFile  = Join-Path $OutputDirectory "$outName.mkv"
        if (Test-Path -LiteralPath $outputFile) {
            Write-Verbose "Resolution $resolution already exists: $outputFile"; continue
        }
        $splitCount++
        $Outputs += [PSCustomObject]@{ id = $splitCount; width = $width; bitrate = $bitrate; outputFile = $outputFile }
    }
    if ($splitCount -eq 0) {
        Write-Host "No valid bit rates specified. Skipping conversion." -ForegroundColor DarkGray
        return
    }

    # --- Audio Duplizieren & Mapping ---
    $audioFilters = @(); $audioLabels = @{}; $langIndex = 0
    $streams = (& ffprobe -v error -select_streams a -show_entries stream=index,channels,channel_layout:stream_tags=language -of json "$($InputFile.FullName)" |
                ConvertFrom-Json).streams
    Write-Verbose "Found Audio Infos: $streams"
    foreach ($stream in $streams) {
        $lang = if ($stream.tags.language) { $stream.tags.language } else { 'und' }
        if ($audioLabels.ContainsKey($lang)) { continue }
        $idx  = $stream.index - 1
        $pan  = switch ($stream.channels) {
            1 { 'pan=stereo|c0=c0|c1=c0' }
            2 { 'anull' }
            6 { 'pan=stereo|c0=c0+c4+c2|c1=c1+c5+c2' }
            8 { 'pan=stereo|c0=c0+c4+c6+c2|c1=c1+c5+c7+c2' }
            default { "pan=stereo|c0=0|c1=0" }
        }
        $base = "a$langIndex"
        $audioLabels[$lang] = $base
        $audioFilters += "[0:a:$idx]$pan[$base]"
        $audioFilters += "[$base]asplit=$splitCount" + ((0..($splitCount-1)) | ForEach-Object { "[$base$_]" }) -join ''
        $langIndex++
    }

    # --- Filter-Complex bauen (mit AutoCrop + Tonemap + Split + Scale + Audio) ---
    $videoLabels = (1..$splitCount | ForEach-Object { "[v$_]" }) -join ''
    $videoSplit  = "[0:v]$cropFilter$tonemapFilter split=$splitCount$videoLabels"
    $videoScales = ($Outputs | ForEach-Object { "[v$($_.id)]scale=$($_.width):-2[v$($_.id)out]" }) -join ';'
    $filterComplex = "$videoSplit;$videoScales;" + ($audioFilters -join ';')

    # --- ffmpeg-Kommando ausführen ---
    $cmd = "ffmpeg -hide_banner -loglevel error -n -stats -i `"$($InputFile.FullName)`" -filter_complex `"$filterComplex`" "
    for ($i = 1; $i -le $splitCount; $i++) {
        $out = $Outputs | Where-Object { $_.id -eq $i }
        $cmd += "-map [v${i}out] -c:v $VideoCodec -b:v $($out.bitrate) "
        $si = 0
        foreach ($lang in $audioLabels.Keys) {
            $dupLabel = "[$($audioLabels[$lang])$(( $i - 1 ))]"
            $cmd += "-map $dupLabel -metadata:s:a:$si language=$lang "
            $si++
        }
        $cmd += "-c:a $AudioCodec -map s? -c:s copy -map_metadata 0 -map_chapters 0 `"$($out.outputFile)`" "
    }
    Write-Verbose "Final ffmpeg command: $cmd"
    Invoke-Expression $cmd
}

$bitrateMap = @{
    "4320p" = $Bitrate4320p
    "3456p" = $Bitrate3456p
    "2880p" = $Bitrate2880p
    "2160p" = $Bitrate2160p
    "1440p" = $Bitrate1440p
    "1080p" = $Bitrate1080p
    "720p"  = $Bitrate720p
    "480p"  = $Bitrate480p
}

if($AudioToStereo -and ($AudioCodec -eq "copy")){
    Write-Error "Can't convert audio to stereo while AudioCodec equals `"copy`""
    exit
}

$Files = Get-ChildItem -Path "$OriginalPath/*" -Recurse -Include *.mkv, *.mp4, *.avi, *.m4v | Sort-Object -Property Name
foreach ($File in $Files) {
    "Processing $($File.BaseName)"
    $OutputPath = $File.DirectoryName.Replace($OriginalPath,$OptimizedPath)
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    Convert-Video -InputFile $File `
        -OutputDirectory $OutputPath `
        -VideoCodec $VideoCodec `
        -AudioCodec $AudioCodec `
        -BitrateMap $bitrateMap `
        -DenyTonemap $DenyTonemap `
        -AudioToStereo $AudioToStereo
}
