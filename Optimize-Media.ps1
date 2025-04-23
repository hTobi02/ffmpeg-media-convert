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
                         -VideoCodec "libx264" -AudioCodec "aac" `
                         -Bitrate2160p "12000k" -Bitrate1080p "5000k"

.NOTES
    DE: Autor: github.com/htobi02 - Version: 0.1 - Erstellt: 2025-04-23
    EN: Author: github.com/htobi02 - Version: 0.1 - Created: 2025-04-23
#>
Param(
    [parameter(Mandatory=$true)]
    [String[]]
    $OriginalPath,
    [parameter(Mandatory=$true)]
    [String[]]
    $OptimizedPath,
    $VideoCodec,
    $AudioCodec,
    $Bitrate2160p,
    $Bitrate1440p,
    $Bitrate1080p,
    $Bitrate720p,
    $Bitrate480p
)

function Test-IsHDR {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VideoFile
    )

    $streamInfo = & ffprobe -show_streams -v error "$VideoFile" | Where-Object {
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

    return ($COLORSPACE -eq "bt2020nc" -and $COLORTRANSFER -eq "smpte2084" -and $COLORPRIMARIES -eq "bt2020")
}

function Test-DoVi {
    param (
        [string]$VideoFile
    )
    
    if (-Not (Test-Path $VideoFile)) {
        Write-Host "Die angegebene Datei existiert nicht."
        return
    }

    $output = & ffprobe -v error -select_streams v:0 -show_entries stream_tags -of default=noprint_wrappers=1:nokey=1 $VideoFile

    if ($output -match "DOVI_Profile") {
        if ($output -match "DOVI_Profile=dvhe\.05\.04") {
            return $false
        }
        else {
            return $true
        }
    } else {
        return $false
    }
}

