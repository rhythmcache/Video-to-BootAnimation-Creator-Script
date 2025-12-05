# bootAnimation-tools

Tools to convert videos to Android bootanimations and vice versa. Available as both interactive Bash scripts and CLI binaries.

[![Telegram](https://img.shields.io/badge/Telegram-blue?style=flat-square&logo=telegram)](https://t.me/rhythmcache)

## What's Available

### Interactive Bash Scripts (Recommended for Beginners)
- **User-friendly interactive prompts** - No need to remember commands
- Converts YouTube or local videos to bootanimation Magisk modules
- Automatically installs missing dependencies
- Creates flashable Magisk modules
- Works on Linux and Termux

### CLI Binaries (For Advanced Users)
- **`vid2boot`** - Convert any video to bootanimation.zip
- **`boot2vid`** - Convert bootanimation.zip to MP4 video
- Fast, cross-platform, non-interactive command-line tools
- Requires FFmpeg to be installed manually

## Installation

### Using Interactive Scripts

#### Quick Run (No Installation)
- `vid2boot` (Converts videos into bootanimations.)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh)
```
---

- `boot2vid` (Converts bootanimation.zip into video.)
```bash
bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/boot2mp4.sh)
```

Or download and run:
- `vid2boot`
```bash
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/cbootanim.sh -o cbootanim.sh
chmod +x cbootanim.sh
./cbootanim.sh
```

- `boot2vid`
```bash
curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/boot2mp4.sh -o boot2mp4.sh
chmod +x boot2mp4.sh
./boot2mp4.sh
```


#### Install Permanently on Termux
```bash
bash <(curl -sSL https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main/install.sh)
```

After installation, use `vid2boot` or `boot2vid` commands.

#### Termux-Specific Setup
Since Termux doesn't have yt-dlp in repositories, run this first for YouTube support:
```bash
termux-setup-storage && pkg install -y openssl-tool python && pip install yt-dlp
```

### Installing CLI Binaries

```bash
cargo install bootanimation-tools
```

**Requirements:**
- FFmpeg must be installed and available in PATH
- If FFmpeg is in a custom location, set the environment variable:
  ```bash
  export FFMPEG_PATH=/path/to/ffmpeg
  ```
- FFprobe is also required for some functions to work properly.
 ```bash
 #export the ffprobe path the same way
 export FFPROBE_PATH=/path/to/ffprobe
```
  Or on Windows:
  ```cmd
  set FFMPEG_PATH=C:\path\to\ffmpeg.exe
  ```

  ```cmd
  set FFPROBE_PATH=C:\path\to\ffprobe.exe
  ```

## Usage

### Interactive Script Features
- Step-by-step prompts for all options
- Choose YouTube video or local video as source
- Select desired resolution for YouTube videos
- Choose custom or video default configuration
- Automatically generates flashable Magisk module
- Flash in Magisk, KernelSU, or aPatch
- Select loop animation for short videos or GIFs
- Extract `bootanimation.zip` from the created Magisk module if needed

**Requirements (auto-installed by script):**
- FFmpeg and FFprobe
- Zip
- yt-dlp (for YouTube downloads)

### CLI Binary Usage

#### Convert Video to Bootanimation

```bash
# Basic usage
vid2boot -i input.mp4 -o bootanimation.zip

# Custom resolution and FPS
vid2boot -i input.mp4 -o bootanimation.zip -W 1080 -H 1920 -f 30

# With audio support
vid2boot -i input.mp4 -o bootanimation.zip --with-audio

# Loop infinitely
vid2boot -i input.mp4 -o bootanimation.zip -l loop-infinite

# PNG format with background color
vid2boot -i input.mp4 -o bootanimation.zip --format png -b "#000000"
```

**Options:**
- `-i, --input` - Input video file (required)
- `-o, --output` - Output bootanimation.zip path (required)
- `-W, --width` - Output width (optional, uses video width if not specified)
- `-H, --height` - Output height (optional, uses video height if not specified)
- `-f, --fps` - Frame rate (optional, uses video fps if not specified)
- `-l, --loop-mode` - Loop behavior: `stop-on-boot`, `play-full`, or `loop-infinite` (default: stop-on-boot)
- `--with-audio` - Include audio in bootanimation
- `--max-frames` - Maximum frames per part (default: 400)
- `--format` - Image format: `jpg` or `png` (default: jpg)
- `-b, --background` - Background color in hex format (e.g., #FFFFFF)

#### Convert Bootanimation to Video

```bash
# Basic usage
boot2vid -i bootanimation.zip -o output.mp4

# Include audio if available
boot2vid -i bootanimation.zip -o output.mp4 --with-audio
```

**Options:**
- `-i, --input` - Input bootanimation.zip file (required)
- `-o, --output` - Output MP4 file (required)
- `--with-audio` - Include audio from bootanimation if available

**Note:** CLI binaries are non-interactive and require all arguments to be provided via command-line flags.

## Limitations

- Magisk modules only work for devices using standard `bootanimation.zip` format
- Bootanimation location must be `/system/product/media` or `/system/media/`
- Not all bootanimation.zip files may convert perfectly to video
- CLI binaries require FFmpeg to be manually installed

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
