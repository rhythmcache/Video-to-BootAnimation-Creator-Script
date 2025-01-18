# BootAnimation-Creator-Script

 An Interactive Bash script that converts YouTube videos or local video files into Android-compatible bootanimation Magisk modules. It Can Also convert bootanimations into mp4 videos. 

 
[![Telegram](https://img.shields.io/badge/Telegram-Join%20Chat-blue?style=flat-square&logo=telegram)](https://t.me/ximistuffschat)

##  Features

- Convert `YouTube` or `local` video files into boot animations
-  Scale bootanimations to desired resolution and FPS

##  Requirements

> **Warning**: Ensure these dependencies are installed. Though the script will attempt to install missing dependencies.

- **FFmpeg and FFprobe**: Used for extracting information and frames from the video
- **Zip**: Used for creating the `bootanimation.zip`
- **yt-dlp**: Download YouTube videos (if selected as input)


###  Termux-Specific Setup
- Since `Termux` doesn't have yt-dlp in their repositories , you need to run this commands first if you want to use youtube to bootanimation converter
```
termux-setup-storage && pkg install -y openssl-tool python && pip install yt-dlp
```


# How To Use?
- Copy and paste any one of below command in `linux terminal` or `termux`
```
bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh)
```
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh -o cbootanim.sh && chmod +x cbootanim.sh && ./cbootanim.sh
```

> [!Tip] 
> - Choose either `YouTube` video or `local video` as the source
> - Select desired resolution for `YouTube` videos
> - Choose custom configuration or video default configuration to create `bootanimation`
> - Script generates a flashable Magisk module
> - Flash created zip in Magisk, KernelSU, or aPatch
> - Recommended to select `loop animation` if your video is too short or if its a gif.
> - if you need just a `bootanimation.zip` , you can extract it from the created magisk modyle


## Install Permanently on `Termux`

- Copy/Paste this below command on Termux to install this tool permanently on Termux. You can use `vid2boot` to start the video to bootanimation converter and `boot2vid` to use bootanimation to video converter
```
bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh)
```





# Limitations 
- May not work on Some Phones like OnePlus , Samsung and other highly modified roms


---
## Convert Bootanimation.zip to video

- Converts bootanimation.zip into video
- Not Guaranteed to work with every Bootanimation.zip
```
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/boot2mp4.sh -o boot2mp4.sh
chmod +x boot2mp4.sh
./boot2mp4.sh
```


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

