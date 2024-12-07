# BootAnimation-Creator-Script

A  Termux/Linux script that converts YouTube videos or local video files into Android-compatible bootanimation Magisk modules.

---

## Features
- Convert `YouTube` videos or `local` video files into boot animations.
- can scale bootanimations to the desired resolution and fps

## Requirements
- **FFmpeg**: Used for extracting frames from the video.
- **Zip**: Used for creating the `bootanimation.zip`.
- **yt-dlp**: Download YouTube videos (if selected as input).
---




## How To Use ?

### Termux Users
- Since yt-dlp is not available in Termux's repositories, you need to install it using Python if you want to use the YouTube to bootanimation converter.

- To install yt-dlp on Termux, run the following commands:
```
pkg install openssl-tool python -y
pip install yt-dlp
```
- copy and paste this on termux or Linux terminal
- Choose either YouTube video or local video as the source.
- For YouTube videos, select the desired resolution to download.
- The script will generate a flashable Magisk module.
- Flash created zip in magisk or kernel su or aPatch
- - Recommended to select "loop animation" if your video is too short or if its a gif
```
curl -sSL https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V2/cbootanim.sh -o cbootanim.sh
chmod +x cbootanim.sh
./cbootanim.sh
```

- If you want to create just a bootanimation.zip from video  , use this

```
curl -sSL https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V2/genbootanim.sh -o genbootanim.sh
chmod +x genbootanim.sh
./genbootanim.sh
```


## Convert Bootanimation.zip to video

- Converts bootanimation.zip into video
- Not Guaranteed to work with every Bootanimation.zip
```
curl -sSL https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V1/boot2mp4.sh -o boot2mp4.sh
chmod +x boot2mp4.sh
./boot2mp4.sh
```




Also see - https://github.com/rhythmcache/video-to-bootanimation


If you find any bugs , report here https://t.me/ximistuffschat

## License
This project is licensed under the GNU General Public License v3.0.
