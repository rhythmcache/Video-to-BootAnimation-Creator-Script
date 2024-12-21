# BootAnimation-Creator-Script

 A Termux/Linux Interactive script that converts YouTube videos or local video files into Android-compatible bootanimation Magisk modules.

[![Tutorial](https://img.shields.io/badge/Tutorial-YouTube-red?logo=youtube)](https://youtu.be/lZdVf88BTZ4)
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-blue?style=flat-square&logo=telegram)](https://t.me/ximistuffschat)

## 🌟 Features

- Convert `YouTube` or `local` video files into boot animations
-  Scale bootanimations to desired resolution and FPS

## ⚠️ Requirements

> **Warning**: Ensure these dependencies are installed. The script will attempt to install missing dependencies.

- **FFmpeg**: Used for extracting frames from the video
- **Zip**: Used for creating the `bootanimation.zip`
- **yt-dlp**: Download YouTube videos (if selected as input)

### 🔧 Termux-Specific Setup
- Since Termux doesn't have yt-dlp in their repositories , you need to run these commands first if you want to use youtube to bootanimation converter
```
termux-setup-storage && pkg install openssl-tool python -y && pip install yt-dlp
```


## 🚀 How To Use?
- Copy and paste this below command in linux terminal or termux
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh -o cbootanim.sh && chmod +x cbootanim.sh && ./cbootanim.sh
```

> [!Tip] 
> - Choose either YouTube video or local video as the source
> - Select desired resolution for YouTube videos
> - Script generates a flashable Magisk module
> - Flash created zip in Magisk, KernelSU, or aPatch
> - Recommended to select "loop animation" if your video is too short or if its a gif.



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
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/boot2mp4.sh -o boot2mp4.sh
chmod +x boot2mp4.sh
./boot2mp4.sh
```






Also see - https://github.com/rhythmcache/video-to-bootanimation


## License

    This Program Is Free Software. You can redistribute
    it
    and/or modify it under the terms of the GNU General
    Public
    License as published by the Free Software Foundation, either version 3
    of the License , or (at your option) 
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

- dont use releases section to download scripts. they are unmaintained
