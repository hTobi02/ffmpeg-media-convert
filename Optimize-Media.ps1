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

.EXAMPLE
    DE: Beispielaufruf (erstellt nur Versionen fuer 2160p und 1080p):
    EN: Example call (only creates versions for 2160p and 1080p):

    .\Convert-Videos.ps1 -OriginalPath "C:\Input" `
                         -OptimizedPath "C:\Output" `
                         -VideoCodec "libx264" -AudioCodec "ac3" `
                         -Bitrate2160p "12000k" -Bitrate1080p "5M"

.NOTES
    DE: Autor: github.com/htobi02 - Version: 0.1 - Erstellt: 2025-04-23
    EN: Author: github.com/htobi02 - Version: 0.1 - Created: 2025-04-23
#>
Param(
    [parameter(Mandatory=$true)][String[]]$OriginalPath,
    [parameter(Mandatory=$true)][String[]]$OptimizedPath,
    $VideoCodec,
    $AudioCodec,
    $Bitrate2160p,
    $Bitrate1440p,
    $Bitrate1080p,
    $Bitrate720p,
    $Bitrate480p,
    [boolean]$DenyTonemap
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


function Convert-Video {
    param (
        [object]$InputFile,
        [string]$OutputDirectory,
        [string]$VideoCodec,
        [string]$AudioCodec,
        [hashtable]$BitrateMap,
        [boolean]$DenyTonemap
    )
    
    $basename = $InputFile.BaseName
    $fullname = $InputFile.FullName

    if (-not $VideoCodec) {
        Write-Host "Missing video codec. Abort." -ForegroundColor Red
        return
    }
    if (-not $AudioCodec) {
        Write-Host "Missing audio codec. Abort." -ForegroundColor Red
        return
    }

    if(!($DenyTonemap)){
        $isHDR = Test-IsHDR -VideoFile $fullname
        $isDoVi = Test-DoVi -VideoFile $fullname

        if ($isDoVi.dv_profile -eq 5) {
            Write-Host "Unsupported DoVi profile: $($isDoVi.dv_profile)" -ForegroundColor Red
            $optimizedName = $basename
            return
        } elseif ($isHDR) {
            $tonemapFilter = "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p,"
            $HDRTagsRegex = '\[(DV\s+)?(HDR|HDR10|HDR10Plus?(\+|Plus)?|DV|HDR|HDR10|HDR10Plus)\]'
            $optimizedName = $basename -replace $HDRTagsRegex, ''
        } else {
            $tonemapFilter = ""
            $optimizedName = $basename
        }
    }
    
    # Auflösung des Quellvideos ermitteln
    $videoStream = Invoke-Expression "ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 `"$fullname`""
    $videoWidth, $videoHeight = $videoStream -split ","

    $videoWidth = [int]$videoWidth
    $videoHeight = [int]$videoHeight[0]

    $duration, $filesize = (& ffprobe -v error -show_entries format=duration,size -of csv=p=0 "$fullname") -split ","
    $videoBitrate = $filesize/($duration/60*0.0075)/1000

    # AudioInfos ermitteln
    $AudioInfo = Get-AudioInfo -File $fullname
    $optimizedName = $optimizedName -replace "$($AudioInfo.profile)","$(Convert-AudioTag -Codec ac3)"

    # Filter & Mapping vorbereiten
    $splitCount = 0
    $Outputs = @()

    foreach ($resolution in $BitrateMap.Keys) {
        $bitrate = $BitrateMap[$resolution]
        if (-not $bitrate) { continue }
        if((Convert-BitrateToBps -Bitrate $bitrate) -ge $videoBitrate) { Write-Host "Final File might be bigger than original. Skipping..." -ForegroundColor Yellow; continue }

        $width = switch ($resolution) {
            "2160p" { 3840 }
            "1440p" { 2560 }
            "1080p" { 1920 }
            "720p"  { 1280 }
            "480p"  { 858 }
        }

        switch -Regex ($VideoCodec) {
            '264'          { $codecTag = 'x264' ; break }
            '265'          { $codecTag = 'x265' ; break }
            'hevc'         { $codecTag = 'x265' ; break }
            'av1'          { $codecTag = 'av1'  ; break }
            default        { $codecTag = 'unknown' }
        }

        if($width -gt $videoWidth){
            Write-Host "Target ($width) bigger than the original resolution ($videoWidth). Skipping $resolution..." -ForegroundColor Yellow
            continue
        }

        $splitCount++

        # Optimierter Dateiname
        $outputName = $optimizedName -replace '\[(Bluray|WEBDL|WEB|Remux|HDTV|DVDRip|BRRip)-\d+p\]', "[Optimized-$resolution]"
        $outputName = $outputName -replace '\[x\d+\]|\[x265\]|\[x264\]|\[av1\]', "[$codecTag]"

        $Output = New-Object PSObject -property @{
            id = $splitCount
            filterOutput = "v$splitCount"
            mapCommand = "-map [v$($splitCount)out] -c:v:$($splitCount-1) $VideoCodec -b:v:$($splitCount-1) $bitrate"
            videoFilter = "[v$splitCount]scale=$($width):-2[v$($splitCount)out]"
            outputFile = "$OutputDirectory/$($outputName).mkv"
            
        }
        $Outputs += $Output
    }

    if ($splitCount -eq 0) {
        Write-Host "No valid bit rates specified. Skipping $fullname." -ForegroundColor DarkGray
        return
    }

    $filterComplex = "[0:v]${tonemapFilter}split=$splitCount$($Outputs.filterOutput | ForEach-Object { "[$_]" })$($Outputs.videoFilter | ForEach-Object { ";$_" })" -replace " ",""
    
    $mapAudio = "-map a -c:a $AudioCodec"
    $mapSubtitles = "-map s -c:s copy"
    $mapMetadata = "-map_metadata 0 -map_chapters 0"

    $cmd = "ffmpeg -hide_banner -loglevel error -n -stats -i `"$fullname`" -filter_complex `"$filterComplex`" "
    foreach($Output in $Outputs){
        $cmd += "$($Output.MapCommand) $mapAudio $mapSubtitles $mapMetadata `"$($Output.outputFile)`" "
    }


    Write-Host "Convert: $basename with $splitCount version(s)..." -ForegroundColor Cyan
    Write-Host $cmd -ForegroundColor DarkGray

    Invoke-Expression $cmd
}


$bitrateMap = @{
    "2160p" = $Bitrate2160p
    "1440p" = $Bitrate1440p
    "1080p" = $Bitrate1080p
    "720p"  = $Bitrate720p
    "480p"  = $Bitrate480p
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
        -BitrateMap $bitrateMap
}
