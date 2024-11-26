# BootAnimation-Creator-Script
A Termux/Linux Script which can convert videos into Bootanimation Magisk Module.


## Features
- Converts videos into Android-compatible boot animations.
- can scale video to the desired resolution and fps

## Requirements
- **FFmpeg**: Used for extracting frames from the video.
- **Zip Utility**: Used for creating the `bootanimation.zip`.
- **Chocolatey (Windows)**: to install ffmpeg and zip automatically on Windows.
---


## How To Use ?
- copy and paste this on termux or Linux terminal
- creates a flashable magisk module
- Flash created zip in magisk or kernel su or aPatch
- - Recommended to select "loop animation" if your video is too short or if its a gif
```
curl -sSL https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V1/cbootanim.sh -o cbootanim.sh
chmod +x cbootanim.sh
./cbootanim.sh
```

- If you want to create just a bootanimation.zip from video  , use this

```
curl -sSL https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V1/genbootanim.sh -o genbootanim.sh
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

### On Windows
#### Steps:
- Just copy and paste this in Windows Powershell
```
   Invoke-WebRequest -Uri "https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script/releases/download/V1/winbootnc.ps1" -OutFile "$env:TEMP\winbootnc.ps1"; & "$env:TEMP\winbootnc.ps1"
```



Also see - https://github.com/rhythmcache/video-to-bootanimation


If you find any bugs , report here https://t.me/ximistuffschat

## License
This project is licensed under the GNU General Public License v3.0.
