# ffmpeg-media-convert
 Convert your Movie Media into multiple optimized Versions <br>

## Info
This Script creates multiple for Plex optimized versions from your Media Library.
If your Library contains one 4K HDR Movie, it will get converted into 6 different versions:
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

You can define all Bitrate settings with parameters. 

## Dependencies
dependencies are automatically downloaded
- [ffmpeg](https://ffmpeg.org)
- [hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool/releases/latest)
- [dovi_tool](https://github.com/quietvoid/dovi_tool/releases/latest)

## Usage
### powershell
```powershell
pwsh ./transcode-movies.ps1 -MoviePath /PATH/TO/YOUR/MOVIES -NewPath /PATH/FOR/CONVERTED
```
### Docker
```docker
docker run -d \
-e MOVIEPATH=/movies \
-e NEWPATH=/converted \
-v /PATH/TO/MOVIES:/movies \
-v /PATH/FOR/CONVERTED:/converted \
htobi02/ffmpeg-media-convert:alpine
```

### More Configoptions:
Parameter|Docker Env|Description|Default
|---|---|---|---|
-codec|CODEC|choose videocodec|hevc
-audiocodec|AUDIOCODEC|choose audiocodec|copy
-HDRTonemapOnly|HDRTONEMAPONLY|Convert HDR content only tonemapped to SDR|$false
-HDRTonemap|HDRTONEMAP|Convert HDR content to HDR and SDR (not recommended)|$false
-FHDonly|FHDONLY|Convert HDR content to HDR and SDR (not recommended)|$false
-HLS|HLS|Convert input into HLS streamable media|$false
-bitrate4khdr|BITRATE4KHDR|Bitrate for 4K HDR Content|20M
-bitratefhdhdr|BITRATEFHDHDR|Bitrate for 1080p HDR Content|10M
-bitratehdhdr|BITRATEHDHDR|Bitrate for 720p HDR Content|4M
-bitratesdhdr|BITRATESDHDR|Bitrate for SD HDR Content|1M
-bitrate4k|BITRATE4K|Bitrate for 4K SDR Content|12M
-bitratefhd|BITRATEFHD|Bitrate for 1080p SDR Content|8M
-bitratehd|BITRATEHD|Bitrate for 720p SDR Content|4M
-bitratesd|BITRATESD|Bitrate for SD SDR Content|1M

## Progress
- ~~Overhaul code~~
- fixing bugs
    -
    - ffmpeg cannot process parsed parameters
- ~~Depencency Check~~
- ~~Auto Update/Download Depencencies~~
- ~~[create Docker Container](https://hub.docker.com/r/htobi02/ffmpeg-media-convert)~~
- ~~add HLS output~~
- Auto Select Codec if no Parameter was set
- Use Hardwaredecoding if Devices present
- Merge Files with "CD[X]" in Name
- Add TMDB Year for Movies without date in Name