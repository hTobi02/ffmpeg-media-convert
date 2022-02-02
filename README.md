# ffmpeg-media-convert
 Convert your Movie Media into multiple optimized Versions <br>
 complete Readme will be added soon

## Info
This Script creates multiple for Plex optimized versions from your Media Library.
If your Library contains one 4K HDR Movie, it will get converted into 6 different versions:
1. 4K HDR 20Mbit
2. 1080p HDR 10Mbit
3. 720p HDR 4Mbit
4. 4K SDR 12Mbit
5. 1080p SDR 8Mbit
6. 720p SDR 4Mbit

SD Content will be reencoded in HEVC 1MBit

You can define all Bitrate settings with parameters. 

## Dependencies
dependencies are automatically downloaded
- [ffmpeg](https://ffmpeg.org)
- [hdr10plus_tool](https://github.com/quietvoid/hdr10plus_tool/releases/latest)
- [dovi_tool](https://github.com/quietvoid/dovi_tool/releases/latest)

## Usage
```powershell
pwsh ./transcode-movies.ps1 -MoviePath /PATH/TO/YOUR/MOVIES -NewPath /PATH/FOR/CONVERTED
```
### More Configoptions:
Parameter|Description|Default
|---|---|---|
-codec|choose videocodec|hevc
-audiocodec|choose audiocodec|copy
-bitrate4khdr|Bitrate for 4K HDR Content|20M
-bitratefhdhdr|Bitrate for 1080p HDR Content|10M
-bitratehdhdr|Bitrate for 720p HDR Content|4M
-bitratesdhdr|Bitrate for SD HDR Content|1M
-bitrate4k|Bitrate for 4K SDR Content|12M
-bitratefhd|Bitrate for 1080p SDR Content|8M
-bitratehd|Bitrate for 720p SDR Content|4M
-bitratesd|Bitrate for SD SDR Content|1M

## TODO
- ~~Depencency Check~~
- ~~Auto Update/Download Depencencies~~
- Auto Select Codec if no Parameter was set
- Use Hardwaredecoding if Devices present
- Merge Files with "CD[X]" in Name
- Add TMDB Year for Movies without date in Name