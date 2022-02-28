#required 7.0
Param
  (
    [parameter(Mandatory=$true)]
    [String[]]
    $MoviePath,
    [parameter(Mandatory=$true)]
    [String[]]
    $NewPath,
    $codec,
    $audiocodec,
    [System.Boolean]$HLS=$false,
    [System.Boolean]$HDRTonemapOnly=$false,
    [System.Boolean]$HDRTonemap=$false,
    [System.Boolean]$FHDonly=$false,
    $bitrate4khdr,
    $bitratefhdhdr,
    $bitratehdhdr,
    $bitratesdhdr,
    $bitrate4k,
    $bitratefhd,
    $bitratehd,
    $bitratesd,
    $tmdbAPIKey
  )
$RunningPath="$($PSScriptRoot)"
$TempPath="$($RunningPath)/Temp"
if($IsWindows){$ToolsOS="win"}elseif($IsLinux){$ToolsOS="linux"}elseif($IsMacOS){$ToolsOS="mac"}else{write-error "could not detect OS";exit}
$ToolsPath="$RunningPath/Tools/$($ToolsOS)"
if(!(Test-Path -Path $MoviePath)){
    Write-Error "Movie Path Doesnt exist"
    exit 100
}
if(!(Test-Path -Path $NewPath)){
    Write-Error "New Path Doesnt exist"
    exit 101
}
#$NewPath="$RunningPath/Filme - Transcoded"
$PathOriginal="$NewPath/Original"
$Path4K="$NewPath/4k"
$PathFHD="$NewPath/1080p"
$PathHD="$NewPath/720p"
$PathSD="$NewPath/SD"
$PathHLS="$NewPath/HLS"
if($null -ne $codec){}elseif($IsWindows){$codec="hevc"}elseif($IsLinux){$codec="hevc"}elseif($IsMacOS){$codec="hevc_videotoolbox"}else{$codec="hevc"}
if($null -eq $audiocodec){$audiocodec="copy"}
if($null -eq $bitrate4khdr){$bitrate4khdr="20M"}
if($null -eq $bitratefhdhdr){$bitratefhdhdr="10M"}
if($null -eq $bitratehdhdr){$bitratehdhdr="4M"}
if($null -eq $bitratesdhdr){$bitratesdhdr="1M"}
if($null -eq $bitrate4k){$bitrate4k="12M"}
if($null -eq $bitratefhd){$bitratefhd="8M"}
if($null -eq $bitratehd){$bitratehd="4M"}
if($null -eq $bitratesd){$bitratesd="1M"}


#Weizenerzeugnisse sind das zwölfte Gebrot

#region init
if($HLS){
"RunningPath: $RunningPath
ToolsPath: $ToolsPath
MoviePath: $MoviePath
NewPath: $NewPath
PathHLS: $PathHLS
Codec: $codec


Beginning in 5 seconds"
} elseif($FHDonly) {
"RunningPath: $RunningPath
ToolsPath: $ToolsPath
MoviePath: $MoviePath
NewPath: $NewPath
PathOriginal: $PathOriginal
PathFHD: $PathFHD
Codec: $codec


Beginning in 5 seconds"
} else {
    "RunningPath: $RunningPath
    ToolsPath: $ToolsPath
    MoviePath: $MoviePath
    NewPath: $NewPath
    PathOriginal: $PathOriginal
    Path4K: $Path4K
    PathFHD: $PathFHD
    PathHD: $PathHD
    PathSD: $PathSD
    Codec: $codec
    
    
    Beginning in 5 seconds"
    }
Start-Sleep -Seconds 5
#endregion

if(!(Test-Path -Path "$($TempPath)")){mkdir "$($TempPath)" | Out-Null}
$DolbyVisionPath="$($TempPath)/dv.txt"
$HDR10PlusPath="$($TempPath)/hdr.txt"
$CropFile="$($TempPath)/crop.txt"
if(!(Test-Path "$DolbyVisionPath")){New-Item "$DolbyVisionPath"}
if(!(Test-Path "$HDR10PlusPath")){New-Item "$HDR10PlusPath"}
if(!(Test-Path "$CropFile")){New-Item "$CropFile"}

#region TestDependencies

function Test-HDR10PlusTool {
    if($null -eq $latestVersionOfHDR10PLUSTOOL){
        $latestVersionOfHDR10PLUSTOOL=((Invoke-webrequest -uri "https://api.github.com/repos/quietvoid/hdr10plus_tool/tags").Content | ConvertFrom-Json)[0].name
    }
    if(!($?)){exit}

    if($IsWindows){
        if(!(Test-Path -Path "$($ToolsPath)/hdr10plus_tool.exe")){
            "Downloading HDR10Plus Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*windows*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/hdr10plus_tool.tar.gz"
            Clear-Host
            "Please Extract Archive"
            "$ToolsPath"
            C:\Windows\explorer.exe $ToolsPath
            #C:\WINDOWS\System32\cmd.exe /c "tar -xvzf $($ToolsPath)/hdr10plus_tool.tar.gz"
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
            $TestHDR10PlusTool = $true
        }
    }
    if($IsLinux){
        if(!(Test-Path -Path "$($ToolsPath)/hdr10plus_tool")){
            "Downloading HDR10Plus Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*linux*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile ./Tools/linux/hdr10plus_tool.tar.gz
            tar -xvzf "$($ToolsPath)/hdr10plus_tool.tar.gz"
            Move-Item "$($ToolsPath)/dist/hdr10plus_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/hdr10plus_tool.tar.gz"
            $TestHDR10PlusTool = $true
        }
    }
    if($IsMacOS){
        if(!(Test-Path -Path "$($ToolsPath)/hdr10plus_tool")){
            "Downloading HDR10Plus Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/hdr10plus_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*apple*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/hdr10plus_tool.tar.gz"
            tar -xvzf "$($ToolsPath)/hdr10plus_tool.tar.gz"
            Move-Item "$($Tools)/dist/hdr10plus_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/hdr10plus_tool.tar.gz"
            $TestHDR10PlusTool = $true
        }
    }


    if($IsWindows){
        $localVersionOfHDR10PLUSTOOL=(./Tools/win/hdr10plus_tool.exe -V).Replace("hdr10plus_tool ","")
    } elseif($IsLinux) {
        $localVersionOfHDR10PLUSTOOL=(./Tools/linux/hdr10plus_tool -V).Replace("hdr10plus_tool ","")
    } elseif($IsLMacOS) {
        $localVersionOfHDR10PLUSTOOL=(./Tools/mac/hdr10plus_tool -V).Replace("hdr10plus_tool ","")
    }
    if($latestVersionOfHDR10PLUSTOOL -gt $localVersionOfHDR10PLUSTOOL){
        "Update Available"
        if($IsWindows){
            Remove-Item ./Tools/win/hdr10plus_tool.exe
        } elseif($IsLinux) {
            Remove-Item ./Tools/linux/hdr10plus_tool
        } elseif($IsLMacOS) {
            Remove-Item ./Tools/mac/hdr10plus_tool
        }
        $TestHDR10PlusTool = $false
    } else {
        "Already up-to-date"
        $TestHDR10PlusTool = $true
		return
    }
}
function Test-DOVITool {
    if($null -eq $latestVersionOfDOVITOOL){
        $latestVersionOfDOVITOOL=((Invoke-webrequest -uri "https://api.github.com/repos/quietvoid/dovi_tool/tags").Content | ConvertFrom-Json)[0].name
    }
    if(!($?)){exit}

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
            $TestDOVITool = $true
        }
    }
    if($IsLinux){
        if(!(Test-Path -Path "$($ToolsPath)/dovi_tool")){
            "Downloading dovi Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/dovi_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*linux*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/dovi_tool.tar.gz"
            tar -xvzf "$($ToolsPath)/dovi_tool.tar.gz"
            Move-Item "$($ToolsPath)/dist/dovi_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/dovi_tool.tar.gz"
            $TestDOVITool =  $true
        }
    }
    if($IsMacOS){
        if(!(Test-Path -Path "$($ToolsPath)/dovi_tool")){
            "Downloading dovi Tool"
            $url = ((invoke-webrequest https://api.github.com/repos/quietvoid/dovi_tool/releases/latest | convertfrom-json).assets | Where-Object {$_.name -like "*apple*"}).browser_download_url
            if(!(Test-Path -Path "$($ToolsPath)")){mkdir $($ToolsPath) | Out-Null}
            invoke-webrequest -uri $url -OutFile "$($ToolsPath)/dovi_tool.tar.gz"
            tar -xvzf "$($ToolsPath)/dovi_tool.tar.gz"
            Move-Item "$($ToolsPath)/dist/dovi_tool" "$($ToolsPath)"
            Remove-Item "$($ToolsPath)/dist"
            Remove-Item "$($ToolsPath)/dovi_tool.tar.gz"
            $TestDOVITool =  $true
        }
    }


    if($IsWindows){
        $localVersionOfDOVITOOL=(./Tools/win/dovi_tool.exe -V).Replace("dovi_tool ","")
    } elseif($IsLinux) {
        $localVersionOfDOVITOOL=(./Tools/linux/dovi_tool -V).Replace("dovi_tool ","")
    } elseif($IsLMacOS) {
        $localVersionOfDOVITOOL=(./Tools/mac/dovi_tool -V).Replace("dovi_tool ","")
    }
    if($latestVersionOfDOVITOOL -gt $localVersionOfDOVITOOL){
        "Update Available"
        if($IsWindows){
            Remove-Item ./Tools/win/dovi_tool.exe
        } elseif($IsLinux) {
            Remove-Item ./Tools/linux/dovi_tool
        } elseif($IsLMacOS) {
            Remove-Item ./Tools/mac/dovi_tool
        }
        $TestDOVITool =  $false
    } else {
        "Already up-to-date"
        $TestDOVITool =  $true
		return
    }
}
#endregion
#region Convert
function Convert-HDR {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}

            #ffmpeg -y -hide_banner -loglevel warning -stats -vsync 0 -hwaccel cuda -init_hw_device opencl=ocl -filter_hw_device ocl -extra_hw_frames 3 -threads 16 -c:v hevc_cuvid -i $Movie.FullName `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 20M -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 10M -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 4M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"

            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhdhdr -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitrate4khdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {$_ -lt 1280} {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratesdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
    }
}
function Convert-HDRTonemapped {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}

            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitrate4khdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhdhdr -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"

            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitrate4k -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"

        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"

            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        {$_ -lt 1280} {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratesdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratesd -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
    }
}
function Convert-HDRTonemapOnly {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}

            #ffmpeg -y -hide_banner -loglevel warning -stats -vsync 0 -hwaccel cuda -init_hw_device opencl=ocl -filter_hw_device ocl -extra_hw_frames 3 -threads 16 -c:v hevc_cuvid -i $Movie.FullName `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 20M -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 10M -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            #-map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v 4M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"

            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitrate4k -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"

        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        {$_ -lt 1280} {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratesdhdr -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
    }
}
function Convert-SDR {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitrate4k -vf "crop=$crop" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratefhd -vf "crop=$crop" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratehd -vf "crop=$crop" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        Default {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel quiet -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a $audiocodec -c:s copy -b:v $bitratesd "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
    }
    
}
#endregion
#region HLS
function Convert-HDRHLS {
    switch ($Width) {
        {$_ -ge 3840} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=1920:h=1080:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 8000k -maxrate 10000k -bufsize 9500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=2560:h=1440:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 12000k -maxrate 13000k -bufsize 13500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1440p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1440p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=3840:h=2160:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 19000k -maxrate 20000k -bufsize 22500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2160p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2160p.m3u8"
        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=1920:h=1080:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 8000k -maxrate 10000k -bufsize 9500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p.m3u8"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
        }
        Default {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0"  -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8"
        }
    }
}
function Convert-SDRHLS {
    switch ($Width) {
        {$_ -ge 3840} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=1920:h=1080:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 8000k -maxrate 10000k -bufsize 9500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=2560:h=1440:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 12000k -maxrate 13000k -bufsize 13500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1440p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1440p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=3840:h=2160:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 19000k -maxrate 20000k -bufsize 22500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2160p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_2160p.m3u8"
        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=1920:h=1080:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 8000k -maxrate 10000k -bufsize 9500k -b:a 192k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_1080p.m3u8"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=1280:h=720:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 4000k -maxrate 5000k -bufsize 4200k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_720p.m3u8"
        }
        Default {
            ffmpeg -hide_banner -y -i "$($Movie.FullName)" `
                -map 0:v -map 0:a -vf scale=w=640:h=360:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod  -b:v 800k -maxrate 856k -bufsize 1200k -b:a 96k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_360p.m3u8" `
                -map 0:v -map 0:a -vf scale=w=842:h=480:force_original_aspect_ratio=decrease -c:a aac -ar 48000 -c:v $codec -crf 20 -sc_threshold 0 -g 48 -keyint_min 48 -hls_time 4 -hls_playlist_type vod -b:v 1400k -maxrate 1498k -bufsize 2100k -b:a 128k -hls_segment_filename "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p_%03d.ts" "$($PathHLS)/$($Movie.BaseName)/$($Movie.BaseName)_480p.m3u8"
        }
    }
    
}
#endregion
#region TestDVorHDR10
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
        [string]$InputFile

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
    [string]$STDOUT_FILE = "$($CropFile)"
    $ArgumentList = "-hide_banner -ss 300 -i `"$($Movie.FullName)`" -vframes 10 -vf cropdetect -f null -"
    Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow -RedirectStandardError $STDOUT_FILE
    $crop = (((Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_ -Like '*crop=*' }).Split(" "))[13]).Split("=")[1]

    #$crop1 = $crop.split(":")[0]
    $crop2 = $crop.split(":")[1]
    $crop3 = $crop.split(":")[2]
    $crop4 = $crop.split(":")[3]
    switch ($($VideoInfo.Width)) {
        {$_ -ge 3840} {
            if($crop4 -In 270..290){}else{
                $ArgumentList = "-hide_banner -ss 60 -i `"$($Movie.FullName)`" -vframes 10 -vf cropdetect -f null -"
                Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow -RedirectStandardError $STDOUT_FILE
                $crop = (((Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_ -Like '*crop=*' }).Split(" "))[13]).Split("=")[1]

                #$crop1 = $crop.split(":")[0]
                $crop2 = $crop.split(":")[1]
                $crop3 = $crop.split(":")[2]
                $crop4 = $crop.split(":")[3]
                
                if($crop4 -In 270..290){}else{
                    $crop = "$($VideoInfo.Width):$($VideoInfo.Height):0:0"
                }
            }
        }
        {($_ -ge 1900) -and ($_ -lt 3840)} {
            if($crop4 -In 135..145){}else{
                $ArgumentList = "-hide_banner -ss 60 -i `"$($Movie.FullName)`" -vframes 10 -vf cropdetect -f null -"
                Start-Process -FilePath ffmpeg -ArgumentList $ArgumentList -Wait -NoNewWindow -RedirectStandardError $STDOUT_FILE
                $crop = (((Get-Content -LiteralPath $STDOUT_FILE | Where-Object { $_ -Like '*crop=*' }).Split(" "))[13]).Split("=")[1]

                #$crop1 = $crop.split(":")[0]
                $crop2 = $crop.split(":")[1]
                $crop3 = $crop.split(":")[2]
                $crop4 = $crop.split(":")[3]
                
                if($crop4 -In 135..145){}else{
                    $crop = "$($VideoInfo.Width):$($VideoInfo.Height):0:0"
                }
            }
        }
        Default {
            $crop = "$($VideoInfo.Width):$($VideoInfo.Height):0:0"
        }
    }

    if($crop3 -ne 0){
        $crop = "$($VideoInfo.Width):$($crop2):0:$($crop4)"
    }

    return $crop
}
#endregion

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
if($null -ne $tmdbAPIKey){$tmdb=$true}else{$tmdb=$false}
if($tmdb){
    if(!(Test-Path -Path $PathOriginal)){mkdir $PathOriginal | Out-Null}
    Start-TMDBMovieNameConversion
    $MoviePath=$PathOriginal
}
Set-Location $PSScriptRoot
#"Getting List of Movies without year inside name"
#$MoviesNoYear = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude "*([0-9][0-9][0-9][0-9])*","*cd[0-9]*"
#foreach($Movie in $MoviesNoYear){
#}

#"Getting list of MovieCDs"
#$MoviesCD = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Include *cd[0-9]* -Exclude "*([0-9][0-9][0-9][0-9])*"
#foreach($Movie in $MoviesCD){}

$TestHDR10PlusTool = $false
$TestDOVITool = $false
if(!(Test-Path -Path $ToolsPath)){mkdir $ToolsPath | Out-Null}
#while(!($TestHDR10PlusTool)){Test-HDR10PlusTool}
#while(!($TestDOVITool)){Test-DOVITool}

$Movies = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude *cd[0-9]* -Include "*([0-9][0-9][0-9][0-9])*.avi","*([0-9][0-9][0-9][0-9])*.mp4","*([0-9][0-9][0-9][0-9])*.mkv","*([0-9][0-9][0-9][0-9])*.ts"
$transcoded=1
$finished = 0
if($HLS){
    if(!(Test-Path -Path $PathHLS)){mkdir $PathHLS | Out-Null}
} else {
    if(!(Test-Path -Path $PathOriginal)){mkdir $PathOriginal | Out-Null}
    if(!(Test-Path -Path $Path4K)){mkdir $Path4K | Out-Null}
    if(!(Test-Path -Path $PathFHD)){mkdir $PathFHD | Out-Null}
    if(!(Test-Path -Path $PathHD)){mkdir $PathHD | Out-Null}
    if(!(Test-Path -Path $PathSD)){mkdir $PathSD | Out-Null}
    if(!(Test-Path -Path $TempPath)){mkdir $TempPath | Out-Null}
}

foreach ($Movie in $Movies){
	if($transcoded -eq 1){
		$watch = Get-ChildItem -Path "$($NewPath)" -Recurse -File -Include *.avi,*.mp4,*.mkv,*.ts -exclude Original/
		$transcoded = 0
	}

    if($watch.BaseName -notcontains $Movie.BaseName){
        $Remaining=$($Movies.Length)-$finished
        "Processing $($Movie.BaseName)"
        $VideoInfo=((ffprobe -v error -select_streams v:0 -show_format -show_entries stream=width,height -print_format json "$($Movie.FullName)") | ConvertFrom-Json).streams
        $Width=$VideoInfo.width
        $HDRMeta=Get-HDRMetadata -InputFile $($Movie.FullName)
        #"$($Movie.BaseName) - $($crop) - $($Width)" | out-file -FilePath "$($ToolsPath)/info.log" -Append
        $Duration = (ffprobe -v error -sexagesimal -show_entries format=duration -print_format json "$($Movie.FullName)" | ConvertFrom-Json).format.duration
		if($HDRMeta.ColorSpace -eq "bt2020nc"){
			$HDR = $true
		} else {
			$HDR = $false
		}
		if(!($HLS)){
			"Measure Crop Dimensions"
			$crop = Measure-CropDimensions
		}
        #Clear-Host
        $info = "Transcoding $($Movie.BaseName)
        Crop: $($crop)
        Original Resolution: $($VideoInfo.width)x$($VideoInfo.height)
        HDR: $($HDR)
        HDR10Plus: $($HDRMeta.HDR10Plus)
        Dolby Vision: $($HDRMeta.DV)
        Duration: $($Duration)

        Remaining Movies: $($Remaining)"
        Write-Host $info
        #$info | Out-File "$($ToolsPath)/transcode-movies_info.log"
        if($HLS){
            if(!(Test-Path "$($PathHLS)/$($Movie.BaseName)")){mkdir "$($PathHLS)/$($Movie.BaseName)" > $null}else{}

            "#EXTM3U
#EXT-X-VERSION:3" > "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            if($Width -ge 640){
                "#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }
            if($Width -ge 842){
                "#EXT-X-STREAM-INF:BANDWIDTH=1400000,RESOLUTION=842x480
480p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }
            if($Width -ge 1280){
                "#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1280x720
720p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }
            if($Width -ge 1920){
                "#EXT-X-STREAM-INF:BANDWIDTH=9500000,RESOLUTION=1920x1080
1080p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }
            if($Width -ge 2560){
                "#EXT-X-STREAM-INF:BANDWIDTH=13000000,RESOLUTION=2560x1440
1440p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }
            if($Width -ge 3840){
                "#EXT-X-STREAM-INF:BANDWIDTH=20000000,RESOLUTION=3840x2160
2160p.m3u8" >> "$PathHLS/$($Movie.BaseName)/$($Movie.BaseName).m3u8"
            }



            if(!($HDR)){
                #Convert SDR Content
                "Convert SDR"
                Convert-SDRHLS
                $transcoded = 1
            } else {
                #Convert HDR Content
                "Convert HDR"
                if($HDRTonemapOnly){
                    #Convert-HDRHLSTonemapOnly
                    Convert-HDRHLS
                }elseif($HDRTonemap){
                    #Convert-HDRHLSTonemapped
                    Convert-HDRHLS
                }else{
                    Convert-HDRHLS
                }
                $transcoded = 1
            }
        }else{
            if(!($HDR)){
                #Convert SDR Content
                "Convert SDR"
                Convert-SDR
                $transcoded = 1
            } else {
                #Convert HDR Content
                "Convert HDR"
                if($HDRTonemapOnly){
                    Convert-HDRTonemapOnly
                }elseif($HDRTonemap){
                    Convert-HDRTonemapped
                }else{
                    Convert-HDR
                }
                $transcoded = 1
            }
        }
        #$Movie.BaseName | Out-File -Append -FilePath "$($ToolsPath)/watch.txt"
    }else {
        "Skipping $($Movie.BaseName)"
    }
    $finished = $finished+1
}
$env:Path = $SysPathOld
Remove-Item -Force -Path "$($TempPath)" -Recurse