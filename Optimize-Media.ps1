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