#required 7.0
Param(
    [parameter(Mandatory=$true)][String[]]$MoviePath,
    [parameter(Mandatory=$true)][String[]]$NewPath,
    $codec=$null,
    $audiocodec="copy",
    [Boolean]$HLS=$false,
    [Boolean]$HDRTonemapOnly=$false,
    [Boolean]$HDRTonemap=$false,
    $ToolsPath="$($PSScriptRoot)/Tools/$(if($IsWindows){"win"}elseif($IsLinux){"linux"}elseif($IsMacOS){"mac"}else{write-error "could not detect OS";exit})",
    $PathOriginal="$NewPath/Original",
    $Path8K="$NewPath/8k",
    $Path4K="$NewPath/4k",
    $Path2K="$NewPath/2k",
    $PathFHD="$NewPath/FHD",
    $PathHD="$NewPath/HD",
    $PathSD="$NewPath/SD",
    $PathHLS="$NewPath/HLS",
    $PathMerge="$MoviePath/Merged",
    $TempPath="$($PSScriptRoot)/Temp",
    $bitrate8khdr="50M",
    $bitrate4khdr="20M",
    $bitrate2khdr="14M",
    $bitratefhdhdr="10M",
    $bitratehdhdr="4M",
    $bitratesdhdr="1M",
    $bitrate8k="30M",
    $bitrate4k="12M",
    $bitrate2k="10M",
    $bitratefhd="8M",
    $bitratehd="3M",
    $bitratesd="1M",
    $tmdbAPIKey="",
    <#
    [Boolean]$8KOnly=$false,
    [Boolean]$4KOnly=$false,
    [Boolean]$2KOnly=$false,
    [Boolean]$FHDOnly=$false,
    [Boolean]$HDOnly=$false,
    [Boolean]$SDOnly=$false,
    #>
    [Boolean]$No8K=$false,
    [Boolean]$No4K=$false,
    [Boolean]$No2K=$false,
    [Boolean]$NoFHD=$false,
    [Boolean]$NoHD=$false,
    [Boolean]$NoSD=$false,
    [Boolean]$SkipDolbyVisionCheck=$true,
    [Boolean]$SkipHDR10PlusCheck=$true,
    [Boolean]$MergeCDs=$false,
    [Boolean]$MergeOnly=$false
)


#region Get-HWDecodingProcessor
"Getting Decoder"
$HWAccels=$(ffmpeg -hide_banner -hwaccels)
$decodec=if((($HWAccels | select-string cuda).count) -ge 1){"-hwaccel cuda"}elseif((($HWAccels | select-string videotoolbox).count) -ge 1){"-hwaccel videotoolbox"}else{""}
$decodec
#endregion


#region Get-HWEncodingProcessor
"Getting Encoder"
    if($null -eq $codec){
        $codec=$(if(((ffmpeg -hide_banner -hwaccels | select-string cuda).count) -ge 1){"hevc_nvenc"}elseif(((ffmpeg -hide_banner -hwaccels | select-string videotoolbox).count) -ge 1){"hevc_videotoolbox"}else{"hevc"})
    }
$codec
#endregion


#region Vars
if($MergeOnly){
    $No8K=$true
    $No4K=$true
    $No2K=$true
    $NoFHD=$true
    $NoHD=$true
    $NoSD=$true
}
#endregion


#region Display
$Display+="RunningPath: $PSScriptRoot`n"
$Display+="ToolsPath: $ToolsPath`n"
$Display+="MoviePath: $MoviePath`n"
$Display+="NewPath: $NewPath`n"
$Display+="Codec: $codec`n"
if($HLS){
    $Display+="PathHLS: $PathHLS`n"
} else {
    if($MergeCDs){$Display+="PathMerge: $PathMerge`n"}
    if(!($No8K)){$Display+="Path8K: $Path8K`n"}
    if(!($No4K)){$Display+="Path4K: $Path4K`n"}
    if(!($No2K)){$Display+="Path2K: $Path2K`n"}
    if(!($NoFHD)){$Display+="PathFHD: $PathFHD`n"}
    if(!($NoHD)){$Display+="PathHD: $PathHD`n"}
    if(!($NoSD)){$Display+="PathSD: $PathSD`n"}
    }
"$($Display)

Starting in 5 seconds"
Start-Sleep -Seconds 5
#endregion


#region Create Unavailable Folders/Files
$DolbyVisionPath="$($TempPath)/dv.txt"
$HDR10PlusPath="$($TempPath)/hdr.txt"
$CropFile="$($TempPath)/crop.txt"
if(!(Test-Path -Path "$($TempPath)")){New-Item -type directory "$($TempPath)" -Force | Out-Null}
if(!(Test-Path "$DolbyVisionPath")){New-Item "$DolbyVisionPath"}
if(!(Test-Path "$HDR10PlusPath")){New-Item "$HDR10PlusPath"}
if(!(Test-Path "$CropFile")){New-Item "$CropFile"}
if(!(Test-Path -Path "$($ToolsPath)")){New-Item -type directory "$($ToolsPath)" -Force | Out-Null}
if(!(Test-Path -Path "$($NewPath)")){New-Item -type directory "$($NewPath)" -Force | Out-Null}
if(!(Test-Path -Path "$($PathMerge)")){New-Item -type directory "$($PathMerge)" -Force | Out-Null}
#endregion


#region TestHDR10Tool+DoViTool
function Install-HDR10PlusTool{
    if($IsWindows){
        if(!(Test-Path -Path "$($ToolsPath)/hdr10plus_tool.exe")){
            "Downloading HDR10Plus Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*windows*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/hdr10plus_tool.tar.gz"
            Clear-Host
            "Please Extract Archive here"
            "$ToolsPath"
            C:\Windows\explorer.exe $ToolsPath
            $hasBeenExtracted=$false
            while(!($hasBeenExtracted)){
                if(Test-Path "$($ToolsPath)/dist/hdr10plus_tool.exe"){
                    $hasBeenExtracted=$true
                }
                Start-Sleep 5
            }
            Move-Item "$($ToolsPath)/dist/hdr10plus_tool.exe" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/hdr10plus_tool.tar.gz"
        }
    }else{
        if(!(Test-Path -Path "$($ToolsPath)/hdr10plus_tool")){
            "Downloading HDR10Plus Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like $(if($IsMacOS){"*apple*"}elseif($IsLinux){"*linux*"})}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/hdr10plus_tool.tar.gz"
            tar -xvzf "$($ToolsPath)/hdr10plus_tool.tar.gz"
            Move-Item "$($Tools)/dist/hdr10plus_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/hdr10plus_tool.tar.gz"
        }
    }
}
function Install-DoViTool {
    if($IsWindows){
        if(!(Test-Path -Path "$($ToolsPath)/dovi_tool.exe")){
            "Downloading DOVI Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/dovi_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*windows*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/dovi_tool.tar.gz"
            #C:\WINDOWS\System32\cmd.exe /c "tar -xvzf $($ToolsPath)/dovi_tool.tar.gz"
            Clear-Host
            "Please Extract Archive"
            "$ToolsPath"
            C:\Windows\explorer.exe $ToolsPath
            #C:\WINDOWS\System32\cmd.exe /c "tar -xvzf $($ToolsPath)/hdr10plus_tool.tar.gz"
            $hasBeenExtracted=$false
            while(!($hasBeenExtracted)){
                if(Test-Path "$($ToolsPath)/dist/dovi_tool.exe"){
                    $hasBeenExtracted=$true
                }
                Start-Sleep 5
            }
            Move-Item "$($ToolsPath)/dist/dovi_tool.exe" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/dovi_tool.tar.gz"
        }
    } else {
        if(!(Test-Path -Path "$($ToolsPath)/dovi_tool")){
            "Downloading dovi Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/dovi_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*apple*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/dovi_tool.tar.gz"
            tar -xvzf "$($ToolsPath)/dovi_tool.tar.gz"
            Move-Item "$($ToolsPath)/dist/dovi_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/dovi_tool.tar.gz"
        }
    }
}
function Test-HDR10PlusTool {
    Install-HDR10PlusTool

    if($null -eq $latestVersionOfHDR10PLUSTOOL){
        $latestVersionOfHDR10PLUSTOOL=((Invoke-webrequest -uri "https://api.github.com/repos/quietvoid/hdr10plus_tool/tags").Content | ConvertFrom-Json)[0].name
    }
    if(!($?)){exit}
    if($IsWindows){
        $localVersionOfHDR10PLUSTOOL=(pwsh -Command "$($ToolsPath)/hdr10plus_tool.exe -V").Replace("hdr10plus_tool ","")
    } else {
        $localVersionOfHDR10PLUSTOOL=(pwsh -Command "$($ToolsPath)/hdr10plus_tool -V").Replace("hdr10plus_tool ","")
    }
    if($latestVersionOfHDR10PLUSTOOL -gt $localVersionOfHDR10PLUSTOOL){
        "HDR10PlusTool - Update Available"
        if($IsWindows){
            Remove-Item ./Tools/win/hdr10plus_tool.exe
            Install-HDR10PlusTool
        } else {
            Remove-Item ./Tools/linux/hdr10plus_tool
            Install-HDR10PlusTool
        }
    } else {
        "HDR10PlusTool - Already up-to-date"
		return
    }
}
function Test-DOVITool {
    Install-DoViTool

    if($null -eq $latestVersionOfDOVITOOL){
        $latestVersionOfDOVITOOL=((Invoke-webrequest -uri "https://api.github.com/repos/quietvoid/dovi_tool/tags").Content | ConvertFrom-Json)[0].name
    }
    if(!($?)){exit}
    if($IsWindows){
        $localVersionOfDOVITOOL=(pwsh -Command "$($ToolsPath)/dovi_tool.exe -V").Replace("dovi_tool ","")
    } else {
        $localVersionOfDOVITOOL=(pwsh -Command "$($ToolsPath)/dovi_tool -V").Replace("dovi_tool ","")
    }
    if($latestVersionOfDOVITOOL -gt $localVersionOfDOVITOOL){
        "DoViTool - Update Available"
        if($IsWindows){
            Remove-Item "$($ToolsPath)/dovi_tool.exe"
            Install-DoViTool
        } else {
            Remove-Item "$($ToolsPath)/dovi_tool"
            Install-DoViTool
        }
    } else {
        "DoViTool - Already up-to-date"
		return
    }
}

if(!(Test-Path -Path $ToolsPath)){mkdir $ToolsPath | Out-Null}
if(!($SkipHDR10PlusCheck)){
    Test-HDR10PlusTool
}
if(!($SkipDolbyVisionCheck)){
    Test-DOVITool
}
#endregion


#region Convert-VideoFile
function Convert-VideoFile {
    $ffmpegArgs="ffmpeg -y -hide_banner -loglevel error -stats $($decodec) -i `"$(($Movie.FullName))`" "
    if($HLS){$M3U8File=$M3U8FileDefault}
    $i=0
    # Normal Section
    if($HDR -and (!($HDRTonemap) -and !($HDRTonemapOnly)) -and !($HLS)){
        # HDR Content
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($Path8K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path8K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs8KHDR;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path4K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs4KHDR;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($Path2K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path2K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs2KHDR;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathFHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsFHDHDR;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsHDHDR;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathSD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsSDHDR;$i+=1}})
    }elseif(($HDR) -and ($HDRTonemap) -and !($HDRTonemapOnly) -and !($HLS)){
        # HDR Content with Tonemapping
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($Path8K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path8K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs8KHDR;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path4K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs4KHDR;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($Path2K)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($Path2K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs2KHDR;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathFHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsFHDHDR;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsHDHDR;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_HDR.mkv")){mkdir "$($PathSD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsSDHDR;$i+=1}})
        # Tonemapping
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($Path8K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path8K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs8KHDRTM;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path4K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs4KHDRTM;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($Path2K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path2K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs2KHDRTM;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathFHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsFHDHDRTM;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsHDHDRTM;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathSD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsSDHDRTM;$i+=1}})
    }elseif($HDR -and $HDRTonemapOnly -and !($HDRTonemap) -and !($HLS)){
        # Tonemapping HDR Content only
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($Path8K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path8K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs8KHDRTM;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path4K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs4KHDRTM;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($Path2K)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($Path2K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs2KHDRTM;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathFHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsFHDHDRTM;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsHDHDRTM;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_TM.mkv")){mkdir "$($PathSD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsSDHDRTM;$i+=1}})
    }elseif(!($HDR) -and !($HLS)){
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($Path8K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($Path8K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs8KSDR;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($Path4K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs4KSDR;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($Path2K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($Path2K)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgs2KSDR;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($PathFHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsFHDSDR;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($PathHD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsHDSDR;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv")){mkdir "$($PathSD)/$($Movie.BaseName)" | Out-Null;$ffmpegArgs+=$ffmpegArgsSDSDR;$i+=1}})
    }
    # HLS Section
    elseif($HLS -and $HDR -and !($HDRTonemap) -and !($HDRTonemapOnly)){
        #HLS Only
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_8K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File8KHDR;$ffmpegArgs+=$ffmpegArgsHLS8KHDR;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_4K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File4KHDR;$ffmpegArgs+=$ffmpegArgsHLS4KHDR;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File2KHDR;$ffmpegArgs+=$ffmpegArgsHLS2KHDR;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_FHD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileFHDHDR;$ffmpegArgs+=$ffmpegArgsHLSFHDHDR;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_HD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileHDHDR;$ffmpegArgs+=$ffmpegArgsHLSHDHDR;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_SD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileSDHDR;$ffmpegArgs+=$ffmpegArgsHLSSDHDR;$i+=1}})
    }elseif($HLS -and $HDR -and $HDRTonemap -and $HDRTonemapOnly){
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_8K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File8KHDR;$ffmpegArgs+=$ffmpegArgsHLS8KHDRTM;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_4K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File4KHDR;$ffmpegArgs+=$ffmpegArgsHLS4KHDRTM;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2K_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File2KHDR;$ffmpegArgs+=$ffmpegArgsHLS2KHDRTM;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_FHD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileFHDHDR;$ffmpegArgs+=$ffmpegArgsHLSFHDHDRTM;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_HD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileHDHDR;$ffmpegArgs+=$ffmpegArgsHLSHDHDRTM;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_SD_HDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileSDHDR;$ffmpegArgs+=$ffmpegArgsHLSSDHDRTM;$i+=1}})

        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_8K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File8KTM;$ffmpegArgs+=$ffmpegArgsHLS8KHDRTM;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_4K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File4KTM;$ffmpegArgs+=$ffmpegArgsHLS4KHDRTM;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File2KTM;$ffmpegArgs+=$ffmpegArgsHLS2KHDRTM;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_FHD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileFHDTM;$ffmpegArgs+=$ffmpegArgsHLSFHDHDRTM;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_HD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileHDTM;$ffmpegArgs+=$ffmpegArgsHLSHDHDRTM;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_SD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileSDTM;$ffmpegArgs+=$ffmpegArgsHLSSDHDRTM;$i+=1}})
    }elseif($HLS -and $HDR -and ($HDRTonemap) -and !($HDRTonemapOnly)){
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_8K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File8KTM;$ffmpegArgs+=$ffmpegArgsHLS8KHDRTM;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_4K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File4KTM;$ffmpegArgs+=$ffmpegArgsHLS4KHDRTM;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2K_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File2KTM;$ffmpegArgs+=$ffmpegArgsHLS2KHDRTM;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_FHD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileFHDTM;$ffmpegArgs+=$ffmpegArgsHLSFHDHDRTM;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_HD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileHDTM;$ffmpegArgs+=$ffmpegArgsHLSHDHDRTM;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_SD_TM.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileSDTM;$ffmpegArgs+=$ffmpegArgsHLSSDHDRTM;$i+=1}})
    }elseif($HLS -and !($HDR)){
        $(if(($Width -ge 7680) -or ($8KOnly) -and !($No8K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_8K_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File8KSDR;$ffmpegArgs+=$ffmpegArgsHLS8KSDR;$i+=1}})
        $(if(($Width -ge 3840) -or ($4KOnly) -and !($No4K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_4K_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File4KSDR;$ffmpegArgs+=$ffmpegArgsHLS4KSDR;$i+=1}})
        $(if(($Width -ge 2560) -or ($2KOnly) -and !($No2K)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2K_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8File2KSDR;$ffmpegArgs+=$ffmpegArgsHLS2KSDR;$i+=1}})
        $(if(($Width -ge 1920) -or ($FHDOnly) -and !($NoFHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_FHD_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileFHDSDR;$ffmpegArgs+=$ffmpegArgsHLSFHDSDR;$i+=1}})
        $(if(($Width -ge 1280) -or ($HDOnly) -and !($NoHD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_HD_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileHDSDR;$ffmpegArgs+=$ffmpegArgsHLSHDSDR;$i+=1}})
        $(if(($Width -ge 640) -or ($SDOnly) -and !($NoSD)){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_SD_SDR.m3u8")){if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" | Out-Null};$M3U8File+=$M3U8FileSDSDR;$ffmpegArgs+=$ffmpegArgsHLSSDSDR;$i+=1}})
    }
    if($HLS){$M3U8File > "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName).m3u8"}

    if($i -eq 0){Write-Host "$($Movie.Basename) already transcoded"}else{"$($ffmpegArgs)`n";Invoke-Expression $ffmpegArgs}
}
#endregion


#region TestDVHDR10
function Confirm-DolbyVision {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Verbosity
    )

    if ($PSBoundParameters['Verbosity']) {
        $VerbosePreference = 'Continue'
    }
    else {
        $VerbosePreference = 'SilentlyContinue'
    }

    #if x265 not found in PATH, cannot generate RPU
    if (!(Get-Command -Name 'x265*')) {
        Write-Verbose "x265 not found in PATH. Cannot encode Dolby Vision"
        return $false
    }

    #Check for existing RPU file. Verification based on file size, can be improved
    if (Test-Path -Path $DolbyVisionPath) {
        if ([math]::round((Get-Item $DolbyVisionPath).Length / 1MB, 2) -gt 15) {
            Write-Host "Existing Dolby Vision RPU file found" @emphasisColors
            Write-Host "If the RPU file was generated during a test encode (i.e. not a full frame count), exit the script NOW, delete the file, and regenerate" @warnColors
            return $true
        }
    }

    #Determine if file supports dolby vision
    if($IsWindows){
        ffmpeg -loglevel panic -i "$($InputFile)" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/win/dovi_tool.exe --crop -m 2 extract-rpu - -o "$($DolbyVisionPath)"
    }elseif($IsLinux){
        ffmpeg -loglevel panic -i "$($InputFile)" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/linux/dovi_tool --crop -m 2 extract-rpu - -o "$($DolbyVisionPath)"
    }elseif($IsMacOS){
        ffmpeg -loglevel panic -i "$($InputFile)" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/mac/dovi_tool --crop -m 2 extract-rpu - -o "$($DolbyVisionPath)"
    }
    #If size is 0, DV metadata was not found
    if ((Get-Item $DolbyVisionPath).Length -eq 0) {
        Write-Verbose "Input File does not support Dolby Vision"
        if (Test-Path -Path $DolbyVisionPath) {
            Remove-Item -Path $DolbyVisionPath -Force
        }
        return $false
    }
    elseif ((Get-Item $DolbyVisionPath).Length -gt 0) {
        Write-Host "Dolby Vision Metadata found. Generating RPU file..." @emphasisColors
        Remove-Item -Path $DolbyVisionPath -Force

        if ($IsMacOS) {
            bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/mac/dovi_tool --crop -m 2 extract-rpu - -o $dvPath"
        }elseif ($IsLinux) {
            bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/linux/dovi_tool --crop -m 2 extract-rpu - -o $dvPath"
        }elseif($IsWindows) {
            cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/win/dovi_tool --crop -m 2 extract-rpu - -o `"$DolbyVisionPath`""
        }

        if ([math]::round((Get-Item $DolbyVisionPath).Length / 1MB, 2) -gt 1) {
            Write-Verbose "RPU size is greater than 1 MB. RPU was most likely generated successfully"
            return $true
        }
        else {
            Write-Host "There was an issue creating the RPU file. Verify the RPU file size" @warnColors
            return $false
        }
    }
    else {
        throw "There was an unexpected error while generating RPU file. This should be unreachable"
        exit 2
    }
}
function Confirm-HDR10Plus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile
    )
    #Verifies if the source is HDR10+ compatible
    if($IsWindows){
        $res = ffmpeg -loglevel panic -i `"$InputFile`" -vframes 100 -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/win/hdr10plus_tool.exe extract -
    }elseif($IsLinux){
        $res = ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/linux/hdr10plus_tool extract -
    }elseif($IsMacOS){
        $res = ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/mac/hdr10plus_tool extract -
    }#If last command completed successfully and found metadata, generate json file
    if ($? -and $res -eq "Dynamic HDR10+ metadata detected.") {
        Write-Host "HDR10+ SEI metadata found..." -NoNewline
        if (Test-Path -Path $HDR10PlusPath) { Write-Host "JSON metadata file already exists" @warnColors }
        else {
            Write-Host "Generating JSON file" @emphasisColors
            if($IsWindows){
                ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/win/hdr10plus_tool.exe extract -o "$($HDR10PlusPath)" -
            }elseif($IsLinux){
                ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/linux/hdr10plus_tool extract -o "$($HDR10PlusPath)" -
            }elseif($IsMacOS){
                ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/mac/hdr10plus_tool extract -o "$($HDR10PlusPath)" -
            }
        }
        return $true
    }
    else { return $false }
}
#endregion


#region Meta
function Get-HDRMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,
        [Boolean]$SkipDolbyVision,
        [Boolean]$SkipHDR10Plus

    )

    #Constants for mastering display color primaries
    Set-Variable -Name Display_P3 -Value "G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" -Option Constant
    Set-Variable -Name BT_2020 -Value "G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)" -Option Constant

    Write-Host "Retrieving HDR Metadata..."

    #Exit script if the input file is null or empty
    if (!(Test-Path -Path $InputFile)) {
        Write-Warning "<$InputFile> could not be found. Check the input path and try again."
        $ioError = New-Object System.IO.FileNotFoundException
        throw $ioError
        exit 2
    }
    #Gather HDR metadata using ffprobe
    $probe = ffprobe -hide_banner -loglevel error -select_streams V -print_format json `
        -show_frames -read_intervals "%+#5" -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" `
        -i $InputFile

    $metadata = $probe | ConvertFrom-Json | Select-Object -ExpandProperty frames | Where-Object { $_.pix_fmt -like "yuv420p10le" } |
        Select-Object -First 1

    if (!$metadata) {
        Write-Warning "10-bit pixel format could not be found within the first 5 frames. Make sure the input file supports HDR."
        Write-Host "HDR metadata will not be copied" @warnColors
        return $false
    }

    [string]$pixelFmt = $metadata.pix_fmt
    [string]$colorSpace = $metadata.color_space
    [string]$colorPrimaries = $metadata.color_primaries
    [string]$colorTransfer = $metadata.color_transfer
    #Compares the red coordinates to determine the mastering display color primaries
    if ($metadata.side_data_list[0].red_x -match "35400/\d+" -and
        $metadata.side_data_list[0].red_y -match "14600/\d+") {
        $masterDisplayStr = $BT_2020
    }
    elseif ($metadata.side_data_list[0].red_x -match "34000/\d+" -and
        $metadata.side_data_list[0].red_y -match "16000/\d+") {
        $masterDisplayStr = $Display_P3
    }
    else { throw "Unknown mastering display colors found. Only BT.2020 and Display P3 are supported." }
    #HDR min and max luminance values
    [int]$minLuma = $metadata.side_data_list[0].min_luminance -replace "/.*", ""
    [int]$maxLuma = $metadata.side_data_list[0].max_luminance -replace "/.*", ""
    #MAx content light level and max frame average light level
    $maxCLL = $metadata.side_data_list[1].max_content
    $maxFAL = $metadata.side_data_list[1].max_average
    #Check if input has HDR10+ metadata and generate json if skip not present
    if (!$SkipHDR10Plus) {
        $isHDR10Plus = Confirm-HDR10Plus -InputFile $InputFile
    }
    else {
        Write-Verbose "Skipping HDR10+"
        $isHDR10Plus = $false
    }
    #Check if input has Dolby Vision metadata and generate rpu if skip not present
    if (!$SkipDolbyVision) {
        $isDV = Confirm-DolbyVision -InputFile $InputFile
    }
    else {
        Write-Verbose "Skipping Dolby Vision"
        $isDV = $false
    }

    $metadataObj = @{
        PixelFmt       = $pixelFmt
        ColorSpace     = $colorSpace
        ColorPrimaries = $colorPrimaries
        Transfer       = $colorTransfer
        MasterDisplay  = $masterDisplayStr
        MaxLuma        = $maxLuma
        MinLuma        = $minLuma
        MaxCLL         = $maxCLL
        MaxFAL         = $maxFAL
        DV             = $isDV
        HDR10Plus      = $isHDR10Plus
    }
    if ($null -eq $metadataObj) {
        throw "HDR object is null. ffprobe may have failed to retrieve the data. Reload the module and try again, or run ffprobe manually to investigate."
    }
    else {
        Write-Host "** HDR METADATA SUCCESSFULLY RETRIEVED **" @progressColors
        Write-Host
        return $metadataObj
    }
}
function Measure-CropDimensions {
    param ([parameter(Mandatory=$true)][int]$ss)
    #[string]$STDOUT_FILE = "$($CropFile)"
    #$ArgumentList = "-hide_banner -ss $($ss) -i `"$($MovieFile)`" -vframes 10 -vf cropdetect -f null -"
    #$STDOUT=(Execute-Command -commandTitle "ffmpeg" -commandPath ffmpeg -commandArguments $ArgumentList).stdout
    #$ffmpegCommand="ffmpeg -hide_banner -ss `"$($ss)`" -i `"$($Movie)`" -vframes 10 -vf cropdetect -f null -"
    #iex $ffmpegCommand > $STDOUT
    $STDOUT=ffmpeg -hide_banner -ss "$($ss)" -i "$($Movie)" -vframes 10 -vf cropdetect -f null - 2>&1
    $crop = ((($STDOUT[$STDOUT.length-4] | Out-String).Split(" "))[13]).Split("=")[1]
    return $crop
}
function Get-CropDimensions {
    $crop = Measure-CropDimensions -ss 300
    Write-Host "STDOUT: $($crop)"
    $crop2 = $crop.split(":")[1]
    $crop3 = $crop.split(":")[2]
    $crop4 = $crop.split(":")[3]
    $ss=15
    $VideoWidth=$VideoInfo.Width
    $AR=$(1920/1080)
    $TnormalCrop4=$((($VideoWidth/$AR)-$crop2)/2)
    $normalCrop4="$($TnormalCrop4-10)..$($TnormalCrop4+10)"


    while(!(($crop4 -In $($TnormalCrop4-10)..$($TnormalCrop4+10)) -or ($crop4 -In 0..10))){
        $crop = Measure-CropDimensions -ss $ss
        $crop2 = $crop.split(":")[1]
        $crop4 = $crop.split(":")[3]
        $TnormalCrop4=$((($VideoWidth/$AR)-$crop2)/2)
        $normalCrop4="$($TnormalCrop4-10)..$($TnormalCrop4+10)"
        Write-Host "Width: $($VideoWidth)`ncrop4: $($crop4)`nTempCrop: $($TnormalCrop4)`nCrop: $($normalCrop4)`nSTDOUT: $($crop)"
        
        $ss=$ss+15
        if($ss -ge 600){
            $crop = "$($VideoInfo.Width):$($VideoInfo.Height):0:0"
            $crop4 = 0
        }
    }
    $crop2 = $crop.split(":")[1]
    $crop3 = $crop.split(":")[2]
    if($crop3 -ne 0){
        $crop = "$($VideoInfo.Width):$($crop2):0:$($crop4)"
    }
    elseif(($crop4 -In 0..10)){
        $crop = "$($VideoInfo.Width):$($VideoInfo.Height):0:0"
        $crop4 = $crop.split(":")[3]
    }

    return $crop
}
#endregion


#region TMDB
function Start-TMDBMovieNameConversion {
    $Movies=(Get-ChildItem -Path $MoviePath)
    foreach($Movie in $Movies){
        $file = (Get-ChildItem $Movie.FullName | Sort-Object -Property Length -Descending)[0]
        $newMovie = ((Invoke-webrequest "https://api.themoviedb.org/3/search/movie?api_key=$($tmdbAPIKey)&language=de-DE&query=$($Movie.Name.Replace("_","%20"))&page=1&include_adult=false").Content | ConvertFrom-Json)
        if($newMovie.Count -ne 0){
            $newMovie = $newMovie.results[0]
            $newTitle = "$($newMovie.title.Replace(':','')) ($($newMovie.release_date.Remove(4,6)))$($file.Extension)"
            $newFile="$($PathOriginal)/$($newTitle)"
            if(!(Test-Path $newFile)){
                Copy-Item "$($file.FullName)" "$($PathOriginal)/$($newTitle)"
            }else{"$($Movie) already exists. skipping"}
        } else {Write-Error "No Movie found for $Movie"}
    }
}
if("" -ne $tmdbAPIKey){$tmdb=$true}else{$tmdb=$false}
if($tmdb){
    if(!(Test-Path -Path $PathOriginal)){mkdir $PathOriginal | Out-Null}
    Start-TMDBMovieNameConversion
    $MoviePath=$PathOriginal
}
#endregion


#region NOT IMPLEMENTED Add Year to movies without
#"Getting List of Movies without year inside name"
#$MoviesNoYear = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude "*([0-9][0-9][0-9][0-9])*","*cd[0-9]*"
#foreach($Movie in $MoviesNoYear){
#}
#endregion


#region Merge CDs
if($MergeCDs){
    "Merging CDs"
    $MoviesCD = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Include *cd[0-9]* -Exclude "*([0-9][0-9][0-9][0-9])*","*.ts"
    for ($i = 0; $i -lt (($MoviesCD | Where-Object {$_.Name -like "*CD1*"}).count -1); $i++) {
        $CDList=$MoviesCD | Where-Object {$_.Name -match ($MoviesCD | Where-Object {$_.Name -like "*CD1*"})[$i].Name.Replace("CD1","").Replace("cd1","").remove((($MoviesCD | Where-Object {$_.Name -like "*CD1*"})[$i].Name.Replace("CD1","").Replace("cd1","")).length-4,4)}
        $files="concat:"
        for ($j = 0; $j -lt $CDList.Count; $j++) {
            #"$($CDList.FullName[$j])"
            $files+="$($CDList.FullName[$j])|"
        }
        $CDName=($MoviesCD | Where-Object {$_.Name -like "*CD1*"})[$i].Name.Replace("CD1","").Replace("cd1","").remove((($MoviesCD | Where-Object {$_.Name -like "*CD1*"})[$i].Name.Replace("CD1","").Replace("cd1","")).length-4,4).Replace(" - ","")
        $files=$files.remove($($files.length-1),1)
        Clear-Host
        "Files: $($files)`nProcessing: $($CDName)`nCMD: ffmpeg -i `"$($files)`" -c copy `"$($PathMerge)/$($CDName).mp4`""
        Invoke-Expression "ffmpeg -n -hide_banner -loglevel error -stats -i `"$($files)`" -c copy `"$($PathMerge)/$($CDName).mp4`""
    }
}
if($MergeOnly){exit}
#endregion

Set-Location $PSScriptRoot

$Movies = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude *cd[0-9]* -Include "*([0-9][0-9][0-9][0-9])*.avi","*([0-9][0-9][0-9][0-9])*.mp4","*([0-9][0-9][0-9][0-9])*.mkv","*([0-9][0-9][0-9][0-9])*.ts"
$transcoded=1
$finished = 0
if($HLS){
    if(!(Test-Path -Path $PathHLS)){mkdir $PathHLS | Out-Null}
}else {
    if(!(Test-Path -Path $Path8K) -and !($No8K)){mkdir $Path8K | Out-Null}
    if(!(Test-Path -Path $Path4K) -and !($No4K)){mkdir $Path4K | Out-Null}
    if(!(Test-Path -Path $Path2K) -and !($No2K)){mkdir $Path2K | Out-Null}
    if(!(Test-Path -Path $PathFHD) -and !($NoFHD)){mkdir $PathFHD | Out-Null}
    if(!(Test-Path -Path $PathHD) -and !($NoHD)){mkdir $PathHD | Out-Null}
    if(!(Test-Path -Path $PathSD) -and !($NoSD)){mkdir $PathSD | Out-Null}
}
$WarningPreference = 'SilentlyContinue'
foreach ($Movie in $Movies){
	if($transcoded -eq 1){
		$transcoded = 0
	}
        $Remaining=$($Movies.Length)-$finished
        "Processing $($Movie.BaseName)"
        "$($Movie.FullName)"
        $VideoInfo=((ffprobe -v error -select_streams v:0 -show_format -show_entries stream=width,height -print_format json "$($Movie.FullName)") | ConvertFrom-Json).streams
        $Width=$VideoInfo.width
        $HDRMeta=Get-HDRMetadata -InputFile "$($Movie.FullName)" -SkipHDR10Plus $SkipHDR10PlusCheck -SkipDolbyVision $SkipDolbyVisionCheck
        $Duration = (ffprobe -v error -sexagesimal -show_entries format=duration -print_format json "$($Movie.FullName)" | ConvertFrom-Json).format.duration
		if($HDRMeta.ColorSpace -eq "bt2020nc"){
			$HDR = $true
		} else {
			$HDR = $false
		}
		if(!($HLS)){
			"Measure Crop Dimensions"
			$crop = Get-CropDimensions
		}
        $info = "Transcoding $($Movie.BaseName)
        Crop: $($crop)
        Original Resolution: $($VideoInfo.width)x$($VideoInfo.height)
        HDR: $($HDR)
        HDR10Plus: $($HDRMeta.HDR10Plus)
        Dolby Vision: $($HDRMeta.DV)
        Duration: $($Duration)

        Remaining Movies: $($Remaining)"
        Clear-Host
        Write-Host $info
        if($HLS){
            if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" > $null}else{}
        }

#region Variables
$h265Params="hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"
$SDRTonemap="zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p"

$Scale8K="scale=7680:trunc(ow/a/2)*2"
$Scale4K="scale=3840:trunc(ow/a/2)*2"
$Scale2K="scale=2560:trunc(ow/a/2)*2"
$ScaleFHD="scale=1920:trunc(ow/a/2)*2"
$ScaleHD="scale=1280:trunc(ow/a/2)*2"
$ScaleSD="scale=640:trunc(ow/a/2)*2"

$Scale8KHLS="scale=w=7680:h=4320:force_original_aspect_ratio=decrease"
$Scale4KHLS="scale=w=3840:h=2160:force_original_aspect_ratio=decrease"
$Scale2KHLS="scale=w=2560:h=1440:force_original_aspect_ratio=decrease"
$ScaleFHDHLS="scale=w=1920:h=1080:force_original_aspect_ratio=decrease"
$ScaleHDHLS="scale=w=1280:h=720:force_original_aspect_ratio=decrease"
$ScaleSDHLS="scale=w=640:h=360:force_original_aspect_ratio=decrease"

$ffmpegArgsDefault="-map 0 -c:v $codec -c:a $audiocodec -c:s copy "
$ffmpegArgsDefaultHLS="-map 0:v -map 0:a -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod "
$ffmpegArgsh265Params="-x265-params `"$h265Params`" "

$ffmpegArgs8KHDR="$($ffmpegArgsDefault) -b:v $($bitrate8khdr) -vf `"crop=$($crop),$($Scale8K)`" $($ffmpegArgsh265Params) `"$($Path8K)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "
$ffmpegArgs4KHDR="$($ffmpegArgsDefault) -b:v $($bitrate4khdr) -vf `"crop=$($crop),$($Scale4K)`" $($ffmpegArgsh265Params) `"$($Path4K)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "
$ffmpegArgs2KHDR="$($ffmpegArgsDefault) -b:v $($bitratefhdhdr) -vf `"crop=$($crop),$($Scale2K)`" $($ffmpegArgsh265Params) `"$($Path2K)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "
$ffmpegArgsFHDHDR="$($ffmpegArgsDefault) -b:v $($bitratefhdhdr) -vf `"crop=$($crop),$($ScaleFHD)`" $($ffmpegArgsh265Params) `"$($PathFHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "
$ffmpegArgsHDHDR="$($ffmpegArgsDefault) -b:v $($bitratehdhdr) -vf `"crop=$($crop),$($ScaleHD)`" $($ffmpegArgsh265Params) `"$($PathHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "
$ffmpegArgsSDHDR="$($ffmpegArgsDefault) -b:v $($bitratesdhdr) -vf `"crop=$($crop),$($ScaleSD)`" $($ffmpegArgsh265Params) `"$($PathSD)/$(($Movie.BaseName))/$(($Movie.BaseName))_HDR.mkv`" "

$ffmpegArgs8KHDRTM="$($ffmpegArgsDefault) -b:v $($bitrate8k) -vf `"crop=$($crop),$($Scale8K),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($Path8K)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "
$ffmpegArgs4KHDRTM="$($ffmpegArgsDefault) -b:v $($bitrate4k) -vf `"crop=$($crop),$($Scale4K),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($Path4K)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "
$ffmpegArgs2KHDRTM="$($ffmpegArgsDefault) -b:v $($bitratefhd) -vf `"crop=$($crop),$($Scale2K),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($Path2K)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "
$ffmpegArgsFHDHDRTM="$($ffmpegArgsDefault) -b:v $($bitratefhd) -vf `"crop=$($crop),$($ScaleFHD),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($PathFHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "
$ffmpegArgsHDHDRTM="$($ffmpegArgsDefault) -b:v $($bitratehd) -vf `"crop=$($crop),$($ScaleHD),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($PathHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "
$ffmpegArgsSDHDRTM="$($ffmpegArgsDefault) -b:v $($bitratesd) -vf `"crop=$($crop),$($ScaleSD),$($SDRTonemap)`" $($ffmpegArgsh265Params) `"$($PathSD)/$(($Movie.BaseName))/$(($Movie.BaseName))_TM.mkv`" "

$ffmpegArgs8KSDR="$($ffmpegArgsDefault) -b:v $($bitrate8k) -vf `"crop=$($crop),$($Scale8K)`" `"$($Path8K)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "
$ffmpegArgs4KSDR="$($ffmpegArgsDefault) -b:v $($bitrate4k) -vf `"crop=$($crop),$($Scale4K)`" `"$($Path4K)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "
$ffmpegArgs2KSDR="$($ffmpegArgsDefault) -b:v $($bitratefhd) -vf `"crop=$($crop),$($Scale2K)`" `"$($Path2K)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "
$ffmpegArgsFHDSDR="$($ffmpegArgsDefault) -b:v $($bitratefhd) -vf `"crop=$($crop),$($ScaleFHD)`" `"$($PathFHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "
$ffmpegArgsHDSDR="$($ffmpegArgsDefault) -b:v $($bitratehd) -vf `"crop=$($crop),$($ScaleHD)`" `"$($PathHD)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "
$ffmpegArgsSDSDR="$($ffmpegArgsDefault) -b:v $($bitratesd) -vf `"crop=$($crop),$($ScaleSD)`" `"$($PathSD)/$(($Movie.BaseName))/$(($Movie.BaseName))_SDR.mkv`" "

$ffmpegArgsHLS8KHDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale8KHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate8khdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_HDR.m3u8`" "
$ffmpegArgsHLS4KHDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale4KHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate4khdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_HDR.m3u8`" "
$ffmpegArgsHLS2KHDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale2KHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate2khdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_HDR.m3u8`" "
$ffmpegArgsHLSFHDHDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleFHDHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratefhdhdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_HDR.m3u8`" "
$ffmpegArgsHLSHDHDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleHDHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratehdhdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_HDR.m3u8`" "
$ffmpegArgsHLSSDHDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleSDHLS)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratesdhdr)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_HDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_HDR.m3u8`" "

$ffmpegArgsHLS8KHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($Scale8KHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate8k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_TM.m3u8`" "
$ffmpegArgsHLS4KHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($Scale4KHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate4k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_TM.m3u8`" "
$ffmpegArgsHLS2KHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($Scale2KHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitrate2k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_TM.m3u8`" "
$ffmpegArgsHLSFHDHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleFHDHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratefhd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_TM.m3u8`" "
$ffmpegArgsHLSHDHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleHDHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratehd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_TM.m3u8`" "
$ffmpegArgsHLSSDHDRTM="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleSDHLS),$($SDRTonemap)`" $($ffmpegArgsh265Params)  -b:v `"$($bitratesd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_TM_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_TM.m3u8`" "

$ffmpegArgsHLS8KSDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale8KHLS),$($SDRTonemap)`" -b:v `"$($bitrate8k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_8K_SDR.m3u8`" "
$ffmpegArgsHLS4KSDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale4KHLS),$($SDRTonemap)`" -b:v `"$($bitrate4k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_4K_SDR.m3u8`" "
$ffmpegArgsHLS2KSDR="$($ffmpegArgsDefaultHLS) -vf `"$($Scale2KHLS),$($SDRTonemap)`" -b:v `"$($bitrate2k)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_2K_SDR.m3u8`" "
$ffmpegArgsHLSFHDSDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleFHDHLS),$($SDRTonemap)`" -b:v `"$($bitratefhd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_FHD_SDR.m3u8`" "
$ffmpegArgsHLSHDSDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleHDHLS),$($SDRTonemap)`" -b:v `"$($bitratehd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_HD_SDR.m3u8`" "
$ffmpegArgsHLSSDSDR="$($ffmpegArgsDefaultHLS) -vf `"$($ScaleSDHLS),$($SDRTonemap)`" -b:v `"$($bitratesd)`" -hls_segment_filename `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_SDR_%03d.ts`" `"$($PathHLS)/$(($Movie.BaseName))/$(($Movie.BaseName))_SD_SDR.m3u8`" "


$M3U8FileDefault="#EXTM3U`n#EXT-X-VERSION:3`n"

$M3U8FileSDSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratesd.Remove($($bitratesd.length-1),1))*1000000),RESOLUTION=640x360`n$($Movie.BaseName)_SD_SDR.m3u8`n"
$M3U8FileHDSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratehd.Remove($($bitratehd.length-1),1))*1000000),RESOLUTION=1280x720`n$($Movie.BaseName)_HD_SDR.m3u8`n"
$M3U8FileFHDSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratefhd.Remove($($bitratefhd.length-1),1))*1000000),RESOLUTION=1920x1080`n$($Movie.BaseName)_FHD_SDR.m3u8`n"
$M3U8File2KSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate2k.Remove($($bitrate2k.length-1),1))*1000000),RESOLUTION=2560x1440`n$($Movie.BaseName)_2K_SDR.m3u8`n"
$M3U8File4KSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate4k.Remove($($bitrate4k.length-1),1))*1000000),RESOLUTION=3840x2160`n$($Movie.BaseName)_4K_SDR.m3u8`n"
$M3U8File8KSDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate8k.Remove($($bitrate8k.length-1),1))*1000000),RESOLUTION=7680x4320`n$($Movie.BaseName)_8K_SDR.m3u8`n"

$M3U8FileSDTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratesd.Remove($($bitratesd.length-1),1))*1000000),RESOLUTION=640x360`n$($Movie.BaseName)_SD_TM.m3u8`n"
$M3U8FileHDTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratehd.Remove($($bitratehd.length-1),1))*1000000),RESOLUTION=1280x720`n$($Movie.BaseName)_HD_TM.m3u8`n"
$M3U8FileFHDTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratefhd.Remove($($bitratefhd.length-1),1))*1000000),RESOLUTION=1920x1080`n$($Movie.BaseName)_FHD_TM.m3u8`n"
$M3U8File2KTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate2k.Remove($($bitrate2k.length-1),1))*1000000),RESOLUTION=2560x1440`n$($Movie.BaseName)_2K_TM.m3u8`n"
$M3U8File4KTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate4k.Remove($($bitrate4k.length-1),1))*1000000),RESOLUTION=3840x2160`n$($Movie.BaseName)_4K_TM.m3u8`n"
$M3U8File8KTM="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate8k.Remove($($bitrate8k.length-1),1))*1000000),RESOLUTION=7680x4320`n$($Movie.BaseName)_8K_TM.m3u8`n"

$M3U8FileSDHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratesd.Remove($($bitratesd.length-1),1))*1000000),RESOLUTION=640x360`n$($Movie.BaseName)_SD_HDR.m3u8`n"
$M3U8FileHDHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratehd.Remove($($bitratehd.length-1),1))*1000000),RESOLUTION=1280x720`n$($Movie.BaseName)_HD_HDR.m3u8`n"
$M3U8FileFHDHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitratefhd.Remove($($bitratefhd.length-1),1))*1000000),RESOLUTION=1920x1080`n$($Movie.BaseName)_FHD_HDR.m3u8`n"
$M3U8File2KHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate2k.Remove($($bitrate2k.length-1),1))*1000000),RESOLUTION=2560x1440`n$($Movie.BaseName)_2K_HDR.m3u8`n"
$M3U8File4KHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate4k.Remove($($bitrate4k.length-1),1))*1000000),RESOLUTION=3840x2160`n$($Movie.BaseName)_4K_HDR.m3u8`n"
$M3U8File8KHDR="#EXT-X-STREAM-INF:BANDWIDTH=$([int]($bitrate8k.Remove($($bitrate8k.length-1),1))*1000000),RESOLUTION=7680x4320`n$($Movie.BaseName)_8K_HDR.m3u8`n"
#endregion
        Convert-VideoFile
    $finished = $finished+1
}
#$env:Path = $SysPathOld
Remove-Item -Force -Path "$($TempPath)" -Recurse