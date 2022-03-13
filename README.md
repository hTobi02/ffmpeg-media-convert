# ffmpeg-media-convert
 Convert your Movie Media into multiple optimized Versions <br>

## Info
This Script creates multiple for Plex optimized versions from your Media Library.
These are all implemented Versions which should be completely compatible with Plex:
1. 8K HDR 50Mbit
2. 4K HDR 20Mbit
3. 2K HDR 14Mbit
4. 1080p HDR 10Mbit
5. 720p HDR 4Mbit
6. SD HDR 1Mbit
7. 8K SDR 30Mbit
8. 4K SDR 12Mbit
9. 2K SDR 10Mbit
10. 1080p SDR 8Mbit
11. 720p SDR 4Mbit
12. SD SDR 1Mbit

You can define all Bitrate settings with [parameters](#more-configoptions). 

### Attention
Automatic selection of hwdecoding only tested with mac but should work also with nvidia. 

## Dependencies
- [ffmpeg](https://ffmpeg.org)
<!-->
<br>the folowing dependencies are getting automatically downloaded/updated
  - [hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool/releases/latest)
  - [dovi_tool](https://github.com/quietvoid/dovi_tool/releases/latest)
-->

## Usage
### powershell
```powershell
pwsh ./app.ps1 -MoviePath /PATH/TO/YOUR/MOVIES -NewPath /PATH/FOR/CONVERTED
```
<!-->
### Docker
```docker
docker run -d \
-e MOVIEPATH=/movies \
-e NEWPATH=/converted \
-v /PATH/TO/MOVIES:/movies \
-v /PATH/FOR/CONVERTED:/converted \
htobi02/ffmpeg-media-convert:alpine
```
-->

### More Configoptions:
Parameter|Description|Default
|---|---|---|
-codec|choose videocodec|hevc
-audiocodec|choose audiocodec|copy
-HDRTonemapOnly|Convert HDR content only tonemapped to SDR|$false
-HDRTonemap|Convert HDR content to HDR and SDR (not recommended)|$false
-HLS|Convert input into HLS streamable media|$false
-MergeCDs|Merge files named "CD[1-9]"|$false
-MergeOnly|Only merge files named "CD[1-9]"|$false
-SkipHDR10PlusCheck|Dont use [hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool/releases/latest) |$false
-SkipDolbyVisionCheck|Dont use [dovi_tool](https://github.com/quietvoid/dovi_tool/releases/latest) |$false
|<b>Resolution</b>||||
-No8K|Doesn't convert source to 8K|$false
-No4K|Doesn't convert source to 4K|$false
-No2K|Doesn't convert source to 2K|$false
-NoFHD|Doesn't convert source to FHD|$false
-NoHD|Doesn't convert source to HD|$false
-NoSD|Doesn't convert source to SD|$false
|<b>Bitrate Settings</b>||||
-bitrate8khdr|Bitrate for 8K HDR Content|50M
-bitrate4khdr|Bitrate for 4K HDR Content|20M
-bitrate4khdr|Bitrate for 2K HDR Content|15M
-bitratefhdhdr|Bitrate for 1080p HDR Content|10M
-bitratehdhdr|Bitrate for 720p HDR Content|4M
-bitratesdhdr|Bitrate for SD HDR Content|1M
-bitrate8k|Bitrate for 8K SDR Content|15M
-bitrate4k|Bitrate for 4K SDR Content|12M
-bitrate2k|Bitrate for 2K SDR Content|10M
-bitratefhd|Bitrate for 1080p SDR Content|8M
-bitratehd|Bitrate for 720p SDR Content|4M
-bitratesd|Bitrate for SD SDR Content|1M

## Progress
- ~~Overhaul code~~
- ~~fixing bugs~~
- ~~Depencency Check~~
- ~~Auto Update/Download Depencencies~~
- ~~[create Docker Container](https://hub.docker.com/r/htobi02/ffmpeg-media-convert)~~
- ~~add HLS output~~
- ~~Auto Select Codec if no Parameter was set~~
- ~~Use Hardwaredecoding if Devices present~
- ~~Merge Files with "CD[X]" in Name~~
- Add TMDB Year for Movies without date in Name