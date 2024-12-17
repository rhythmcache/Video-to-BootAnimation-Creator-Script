# BootAnimation-Creator-Script

A  Termux/Linux Interactive script that converts YouTube videos or local video files into Android-compatible bootanimation Magisk modules.

[![Tutorial](https://img.shields.io/badge/Tutorial-YouTube-red?logo=youtube)](https://youtu.be/lZdVf88BTZ4)
---

## Features
- Convert `YouTube` videos or `local` video files into boot animations.
- can scale bootanimations to the desired resolution and fps

## Requirements
Ensure that these dependencies are installed in your environment though script will try to install the dependencies if it finds any of them Missing.
- **FFmpeg**: Used for extracting frames from the video.
- **Zip**: Used for creating the `bootanimation.zip`.
- **yt-dlp**: Download YouTube videos (if selected as input).
---
### Termux Users
- Since yt-dlp is not available in Termux's repositories, you need to install it using Python if you want to use the YouTube to bootanimation converter.

- To install yt-dlp on Termux, run the following commands:

```
termux-setup-storage
pkg install openssl-tool python -y
pip install yt-dlp
```

## How To Use ?
- copy and paste this on termux or Linux terminal
- Choose either YouTube video or local video as the source.
- For YouTube videos, select the desired resolution to download.
- The script will generate a flashable Magisk module.
- Flash created zip in magisk or kernel su or aPatch
- ~~Recommended to select "loop animation" if your video is too short or if its a gif~~ ⚠️ Selecting loop animation is known to cause problems on some devices, so it's better to avoid it
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh -o cbootanim.sh
chmod +x cbootanim.sh
./cbootanim.sh
```


## Use As Command-Line
- [Download This](https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V2/bootc) and give executable permission
- it will create just a bootanimation.zip (not module)
- General Syntax to use for creating a looped boot-animation 
```
bootc -i <path to video file> <resolution> <fps> loop <output/path/bootanimation.zip>
```
- General Syntax to use for creating a non-looped boot-animation (same just remove the loop)
```
bootc -i <path to video file> <resolution> <fps <output/path/bootanimation.zip>
```
- For example
```
./bootc -i /storage/emulated/0/Movies/VID_20241211_201851_329.mp4 1080x2400 50 /sdcard/bootanimation.zip
```
---
- same but interactive script to create bootanimation.zip (not module)
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/genbootanim.sh -o genbootanim.sh
chmod +x genbootanim.sh
./genbootanim.sh
```

## Convert Bootanimation.zip to video

- Converts bootanimation.zip into video
- Not Guaranteed to work with every Bootanimation.zip
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V1/boot2mp4.sh -o boot2mp4.sh
chmod +x boot2mp4.sh
./boot2mp4.sh
```






Also see - https://github.com/rhythmcache/video-to-bootanimation


If you find any bugs , report here https://t.me/ximistuffschat

## License
This project is licensed under the GNU General Public License v3.0.


---
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-blue?style=flat-square&logo=telegram)](https://t.me/ximistuffschat)
