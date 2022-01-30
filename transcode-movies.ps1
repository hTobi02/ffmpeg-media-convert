Param
  (
    [parameter(Mandatory=$true)]
    [String[]]
    $MoviePath,
    [parameter(Mandatory=$true)]
    [String[]]
    $NewPath
  )
$RunningPath="$($PSScriptRoot)"
$TempPath="$($RunningPath)/Temp"
$ToolsPath="$RunningPath/Tools"
#$MoviePath=Read-Host "Type exact MoviePath"
if(!(Test-Path -Path $MoviePath)){
    Write-Error "Movie Path Doesnt exist"
    exit 100
}
#$NewPath=Read-Host "Type exact NewPath"
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
if($IsWindows){$codec="hevc_nvenc"}elseif($IsLinux){$codec="hevc_nvenc"}elseif($IsMacOS){$codec="hevc_videotoolbox"}else{$codec="libx265"}


#Weizenerzeugnisse sind das zwölfte Gebrot

#region init
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
Start-Sleep -Seconds 5
#endregion

$DolbyVisionPath="$($ToolsPath)/dv.txt"
$HDR10PlusPath="$($ToolsPath)/hdr.txt"
#$SysPathOld = $env:Path
#$env:Path += ";$($ToolsPath)"

#-hwaccel cuda -hwaccel_output_format cuda   -hide_banner -loglevel quiet -stats 
function Convert-HDR {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 20M -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 10M -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"

        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 10M -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop" -x265-params "hdr-opt=1:repeat-headers=1:colorprim=$($HDRMeta.ColorPrimaries):transfer=$($HDRMeta.Transfer):colormatrix=$($HDRMeta.ColorSpace):master-display=$($HDRMeta.MasterDisplay)L($($HDRMeta.MaxLuma),$($HDRMeta.MinLuma)):max-cll=0,0" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,zscale=transfer=linear,tonemap=tonemap=clip:param=1.0:desat=2:peak=0,zscale=transfer=bt709,format=yuv420p" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName)_SDR.mkv"
        }
        Default {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 2M "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
    }
}
function Convert-SDR {
    switch ($Width) {
        {$_ -ge 3840} {
            if(!(Test-Path "$($Path4K)/$($Movie.BaseName)")){mkdir "$($Path4K)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 20M -vf "crop=$crop" "$($Path4K)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 10M -vf "crop=$crop,scale=1920:trunc(ow/a/2)*2" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1920) -and ($_ -lt 3840)} {
            if(!(Test-Path "$($PathFHD)/$($Movie.BaseName)")){mkdir "$($PathFHD)/$($Movie.BaseName)" > $null}else{}
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 10M -vf "crop=$crop" "$($PathFHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv" `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop,scale=1280:trunc(ow/a/2)*2" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        {($_ -ge 1280) -and ($_ -lt 1920)} {
            if(!(Test-Path "$($PathHD)/$($Movie.BaseName)")){mkdir "$($PathHD)/$($Movie.BaseName)" > $null}else{}    
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 5M -vf "crop=$crop" "$($PathHD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
        Default {
            if(!(Test-Path "$($PathSD)/$($Movie.BaseName)")){mkdir "$($PathSD)/$($Movie.BaseName)" > $null}else{}
            ffmpeg -y -hide_banner -loglevel warning -stats -i $Movie.FullName `
            -map 0 -c:v $codec -c:a ac3 -c:s copy -b:v 2M "$($PathSD)/$($Movie.BaseName)/$($Movie.BaseName).mkv"
        }
    }
    
}
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
        ffmpeg -loglevel panic -i "$($InputFile)" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/dovi_tool.exe --crop -m 2 extract-rpu - -o "$($DolbyVisionPath)"
    }else{
        ffmpeg -loglevel panic -i "$($InputFile)" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/dovi_tool --crop -m 2 extract-rpu - -o "$($DolbyVisionPath)"
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

        if ($IsMacOS -or $IsLinux) {
            bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/dovi_tool --crop -m 2 extract-rpu - -o $dvPath"
        }
        else {
            cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/dovi_tool --crop -m 2 extract-rpu - -o `"$DolbyVisionPath`""
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
        $res = ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/hdr10plus_tool.exe extract -
    }else{
        $res = ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/hdr10plus_tool extract -
    }#If last command completed successfully and found metadata, generate json file
    if ($? -and $res -eq "Dynamic HDR10+ metadata detected.") {
        Write-Host "HDR10+ SEI metadata found..." -NoNewline
        if (Test-Path -Path $HDR10PlusPath) { Write-Host "JSON metadata file already exists" @warnColors }
        else {
            Write-Host "Generating JSON file" @emphasisColors
            if($IsWindows){
                ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/hdr10plus_tool.exe extract -o "$($HDR10PlusPath)" -
            }else{
                ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | Tools/hdr10plus_tool extract -o "$($HDR10PlusPath)" -
            }
        }
        return $true
    }
    else { return $false }
}
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
    [string]$STDOUT_FILE = "$($TempPath)/crop.txt"
    $ArgumentList = "-hide_banner -ss 600 -i `"$($Movie.FullName)`" -vframes 10 -vf cropdetect -f null -"
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
#function Get-Movieyear {
#}

Set-Location $PSScriptRoot
#"Getting List of Movies without year inside name"
#$MoviesNoYear = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude "*([0-9][0-9][0-9][0-9])*","*cd[0-9]*"
#foreach($Movie in $MoviesNoYear){
#}

#"Getting list of MovieCDs"
#$MoviesCD = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Include *cd[0-9]* -Exclude "*([0-9][0-9][0-9][0-9])*"
#foreach($Movie in $MoviesCD){}


$Movies = Get-ChildItem -Path "$($MoviePath)" -Recurse -File -Exclude *cd[0-9]* -Include "*([0-9][0-9][0-9][0-9])*.avi","*([0-9][0-9][0-9][0-9])*.mp4","*([0-9][0-9][0-9][0-9])*.mkv","*([0-9][0-9][0-9][0-9])*.ts"
$transcoded=1
$finished = 0

if(!(Test-Path -Path $PathOriginal)){mkdir $PathOriginal}
if(!(Test-Path -Path $Path4K)){mkdir $Path4K}
if(!(Test-Path -Path $PathFHD)){mkdir $PathFHD}
if(!(Test-Path -Path $PathHD)){mkdir $PathHD}
if(!(Test-Path -Path $PathSD)){mkdir $PathSD}
if(!(Test-Path -Path $TempPath)){mkdir $TempPath}

foreach ($Movie in $Movies){
	if($transcoded -eq 1){
		$watch = Get-ChildItem -Path "$($NewPath)" -Recurse -File -Include *.avi,*.mp4,*.mkv,*.ts
		$transcoded = 0
	}

    if($watch.BaseName -notcontains $Movie.BaseName){
        $Remaining=$($Movies.Length)-$finished
        "Processing $($Movie.BaseName)"
        $VideoInfo=((ffprobe -v error -select_streams v:0 -show_format -show_entries stream=width,height -print_format json "$($Movie.FullName)") | ConvertFrom-Json).streams
        $Width=$VideoInfo.width
        $HDRMeta=Get-HDRMetadata -InputFile $($Movie.FullName)
        "Measure Crop Dimensions"
        $crop = Measure-CropDimensions
        "$($Movie.BaseName) - $($crop) - $($Width)" | out-file -FilePath "$($ToolsPath)/info.log" -Append
        $Duration = (ffprobe -v error -sexagesimal -show_entries format=duration -print_format json "$($Movie.FullName)" | ConvertFrom-Json).format.duration
		if($HDRMeta.ColorSpace -eq "bt2020nc"){
			$HDR = $true
		} else {
			$HDR = $false
		}
        #Clear-Host
        $info = "Transcoding $($Movie.BaseName)
        Crop: $($crop)
        Resolution: $($VideoInfo.width)x$($VideoInfo.height)
        HDR: $($HDRMeta)
        Duration: $($Duration)

        Remaining Movies: $($Remaining)"
        Write-Host $info
        $info | Out-File "$($ToolsPath)/transcode-movies_info.log"
        if(!($HDR)){
            #Convert SDR Content
            "Convert SDR"
            Convert-SDR
			$transcoded = 1
        } else {
            #Convert HDR Content
            "Convert HDR"
            Convert-HDR
			$transcoded = 1
        }
        $Movie.BaseName | Out-File -Append -FilePath "$($ToolsPath)/watch.txt"
    }else {
        "Skipping $($Movie.BaseName)"
    }
    $finished = $finished+1
}
$env:Path = $SysPathOld