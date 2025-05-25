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
        $idx  = $stream.index
        $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
        Write-Verbose "Stream raw index: $idx, channels=$($stream.channels), language=$lang"

        if ($seenLang.ContainsKey($lang)) {
            Write-Verbose "Skipping stream idx=$idx (duplicate language)"
            continue
        }
        $seenLang[$lang] = $true

        $inLabel  = "[0:a:$idx]"
        $outLabel = "[aout$outCount]"

        switch ($stream.channels) {
            1 {
                $pan = "pan=stereo|c0=c0|c1=c0"
            }
            2 {
                $pan = "anull"
            }
            6 {
                $leftIdx   = @(0,4); $rightIdx  = @(1,5); $centerIdx = @(2)
                $mixLeft   = ( ($leftIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $mixRight  = ( ($rightIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $pan       = "pan=stereo|c0=$mixLeft|c1=$mixRight"
            }
            8 {
                $leftIdx   = @(0,4,6); $rightIdx = @(1,5,7); $centerIdx = @(2)
                $mixLeft   = ( ($leftIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $mixRight  = ( ($rightIdx + $centerIdx) | ForEach-Object { "c$_" } ) -join "+"
                $pan       = "pan=stereo|c0=$mixLeft|c1=$mixRight"
            }
            default {
                $all = 0..($stream.channels - 1) | ForEach-Object { "c$_" } -join "+"
                $pan = "pan=stereo|c0=$all|c1=$all"
            }
        }

        Write-Verbose "Built pan for idx=$($idx): $pan"
        $filters += "$inLabel $pan $outLabel"
        $maps    += "-map $outLabel"
        $metas   += "-metadata:s:a:$outCount language=$lang"

        $outCount++
    }

    Write-Verbose "Generated $($filters.Count) filter(s), $($maps.Count) map(s), $($metas.Count) meta(s)."
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

    # Validierung
    if (-not $VideoCodec) { Write-Host "Missing video codec. Abort." -ForegroundColor Red; return }
    if (-not $AudioCodec) { Write-Host "Missing audio codec. Abort." -ForegroundColor Red; return }

    # HDR / Tonemap
    if (-not $DenyTonemap) {
        $isHDR  = Test-IsHDR  -VideoFile $InputFile.FullName
        $isDoVi = Test-DoVi   -VideoFile $InputFile.FullName
        if ($isDoVi.dv_profile -eq 5) {
            Write-Host "Unsupported DoVi profile: $($isDoVi.dv_profile)" -ForegroundColor Red
            return
        }
        elseif ($isHDR) {
            $tonemapFilter = "zscale=t=linear:npl=100,format=gbrpf32le," +
                             "zscale=p=bt709,tonemap=tonemap=hable:desat=0," +
                             "zscale=t=bt709:m=bt709:r=tv,format=yuv420p,"
            $HDRTagsRegex  = '\[(DV\s+)?(HDR|HDR10|HDR10Plus?(\+|Plus)?|DV|HDR10Plus)\]'
            $optimizedName = $InputFile.BaseName -replace $HDRTagsRegex, ''
        }
        else {
            $tonemapFilter = ""
            $optimizedName = $InputFile.BaseName
        }
    }
    else {
        $tonemapFilter = ""
        $optimizedName = $InputFile.BaseName
    }

    # Video-Auflösung ermitteln
    $videoStream = & ffprobe -v error -select_streams v:0 `
        -show_entries stream=width,height -of csv=p=0 "`"$($InputFile.FullName)`""
    $parts       = $videoStream -split ","
    $videoWidth  = [int]$parts[0]

    # Dauer & Dateigröße
    $durSize      = & ffprobe -v error `
        -show_entries format=duration,size -of csv=p=0 "`"$($InputFile.FullName)`""
    $dsParts      = $durSize -split ","
    $duration     = [double]$dsParts[0]
    $filesize     = [double]$dsParts[1]
    $videoBitrate = $filesize / ($duration/60*0.0075) / 1000

    # Name anpassen
    if ($AudioCodec -ne "copy") {
        $AudioInfo     = Get-AudioInfo -File $InputFile.FullName
        $AudioReplace  = if ($AudioInfo.profile -eq "unknown") { $AudioInfo.codec.ToUpper() } else { $AudioInfo.profile }
        $tag           = Convert-AudioTag -Codec $AudioCodec
        $optimizedName = $optimizedName -replace $AudioReplace, $tag
        if ($AudioToStereo) {
            $optimizedName = $optimizedName -replace '\[([^\]]+?)\s+[0-9]+\.[0-9]+\]', '[$1 2.0]'
        }
    }

    # Video-Splits definieren
    $splitCount = 0
    $Outputs    = @()
    foreach ($resolution in $BitrateMap.Keys) {
        $width    = switch ($resolution) {
            "4320p" { 7680 }; "3456p" { 6144 }; "2880p" { 5120 }
            "2160p" { 3840 }; "1440p" { 2560 }; "1080p" { 1920 }
            "720p"  { 1280 }; "480p"  { 858 }
        }
        $codecTag = switch -Regex ($VideoCodec) {
            '264'  { 'x264' }; '265'  { 'x265' }
            'hevc' { 'x265' }; 'av1'  { 'av1' }
            default{ 'unknown' }
        }
        $bitrate = $BitrateMap[$resolution]
        if (-not $bitrate) { continue }
        if ((Convert-BitrateToBps -Bitrate $bitrate) -ge $videoBitrate -and $width -le $videoWidth) { continue }
        if ($width -gt $videoWidth) { continue }

        $splitCount++
        $outName = $optimizedName `
            -replace '\[(Bluray|WEBDL|WEB|Remux|HDTV|DVDRip|BRRip)-\d+p.*?\]', "[Optimized-$resolution]" `
            -replace '\[x\d+\]|\[x264\]|\[x265\]|\[hevc\]|\[av1\]|\[vc1\]', "[$codecTag]"

        $Outputs += [PSCustomObject]@{
            id           = $splitCount
            filterOutput = "v$splitCount"
            mapCommand   = "-map [v${splitCount}out] -c:v $VideoCodec -b:v $bitrate"
            videoFilter  = "[v$splitCount]scale=$($width):-2[v${splitCount}out]"
            outputFile   = Join-Path $OutputDirectory "$outName.mkv"
        }
    }

    if ($splitCount -eq 0) {
        Write-Host "No valid bit rates specified. Skipping conversion." -ForegroundColor DarkGray
        return
    }

    $videoFCParts     = "[0:v]${tonemapFilter}split=$splitCount$splitLabels;$scaleFilters"

    if ($AudioToStereo) {
        $audioData        = Get-AudioStereoMapping -InputFile $InputFile.FullName -count $Outputs.Count -Verbose:$PSBoundParameters.Verbose
        $audioFilterPart  = ($audioData.Filters) -join ";"
        $filterComplexAll = "$videoFCParts;$audioFilterPart"
        $audioMaps        = ($audioData.Maps)  -join " "
        $audioMetas       = ($audioData.Metas) -join " "
        $Outputs          = $audioData.Outputs
    }
    else {
        $filterComplexAll = $videoFCParts
        $audioMaps        = "-map a"
        $audioMetas       = ""
    }

    # Video-Filter-Complex sauber zusammenbauen
    $splitLabels      = ($Outputs | ForEach-Object { "[v$($_.id)]" }) -join ""
    $scaleFilters     = ($Outputs | ForEach-Object { $_.videoFilter }) -join ";"

    $mapSubs = "-map s? -c:s copy"
    $mapMeta = "-map_metadata 0 -map_chapters 0"

    # ffmpeg-Kommando zusammenbauen
    $cmd = "ffmpeg -hide_banner -loglevel error -n -stats " +
           "-i `"$($InputFile.FullName)`" " +
           "-filter_complex `"$filterComplexAll`" "

    foreach ($out in $Outputs) {
        $cmd += "$($out.mapCommand) " +
                "$audioMaps $audioMetas -c:a $AudioCodec " +
                "$mapSubs $mapMeta `"$($out.outputFile)`" "
    }

    Write-Verbose "Final ffmpeg command: $cmd"
    Write-Host "Convert: $($InputFile.BaseName) with $splitCount version(s)..." -ForegroundColor Cyan

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
