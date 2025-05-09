#!/bin/bash
# Bootanimation creator script by github.com/rhythmcache
# Telegram @rhythmcache
TMP_DIR="$(pwd)/bootanim"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/frames" "$TMP_DIR/result"
desc_file="$TMP_DIR/result/desc.txt"
output_zip="./bootanimation.zip"
WHITE='\033[1;37m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_RED='\033[1;31m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
NC='\033[0m'
rm -f downloaded_video.*
check_termux_environment() {
    if echo "$PREFIX" | grep -q "com.termux"; then
        echo -e "${BRIGHT_RED}Termux Detected${NC}"
        echo -e "${BRIGHT_RED}Checking Internal Storage Access${NC}"
        if [ -r /storage/emulated/0/ ] && [ -w /storage/emulated/0/ ]; then
            echo -e "${GREEN}Internal Storage Is Accessible..${NC}"
        else
            echo "Internal Storage is not fully accessible. Setting up storage..."
            termux-setup-storage
        fi
    fi
}
check_termux_environment
echo -e "${BRIGHT_CYAN}"
echo "░█▀▄░█▀█░█▀█░▀█▀░█▀█░█▀█░▀█▀░█▄█░█▀█░▀█▀░▀█▀░█▀█░█▀█"
echo "░█▀▄░█░█░█░█░░█░░█▀█░█░█░░█░░█░█░█▀█░░█░░░█░░█░█░█░█"
echo "░▀▀░░▀▀▀░▀▀▀░░▀░░▀░▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀"
echo -e "${NC}"
echo -e "${BRIGHT_YELLOW}"
echo "░█▀▀░█▀▄░█▀▀░█▀█░▀█▀░█▀█░█▀▄"
echo "░█░░░█▀▄░█▀▀░█▀█░░█░░█░█░█▀▄"
echo "░▀▀▀░▀░▀░▀▀▀░▀░▀░░▀░░▀▀▀░▀░▀"
echo -e "${NC}"
sleep 1
echo -e "${BRIGHT_CYAN}========================================${NC}"
echo -e "${WHITE}                 by  rhythmcache              ${NC}"
echo -e "${BRIGHT_CYAN}========================================${NC}"
sleep 2
install_package() {
  local package="$1"

  if command -v pkg &> /dev/null; then
    echo "Termux detected"
    if [ "$package" == "yt-dlp" ]; then
      if ! command -v yt-dlp &> /dev/null; then
        echo "yt-dlp not found. Installing via pip..."
        pkg install python openssl-tool -y
        pip install yt-dlp
      fi
    else
      pkg update && pkg install -y "$package"
    fi
  elif command -v dnf &> /dev/null; then
    sudo dnf install -y "$package"
  elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm "$package"
  elif command -v zypper &> /dev/null; then
    sudo zypper install -y "$package"
  elif command -v yum &> /dev/null; then
    sudo yum install -y "$package"
  elif command -v apk &> /dev/null; then
    sudo apk add "$package"
  elif command -v apt &> /dev/null; then  # Other Linux distros
    sudo apt update && sudo apt install -y "$package"
  else
    echo "Error: Unsupported package manager. Please install $package manually."
    exit 1
  fi
}

if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Installing..."
    install_package "ffmpeg" || { echo "Failed to install ffmpeg."; exit 1; }
fi
if ! command -v bc &> /dev/null; then
    echo "bc not found. Installing..."
    install_package "bc" || { echo "Failed to install bc. Please install it manually."; exit 1; }
fi
if ! command -v zip &> /dev/null; then
    echo "zip not found. Installing..."
    install_package "zip" || { echo "Failed to install zip."; exit 1; }
fi


get_video_properties() {
    local video_file="$1"

    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video_file")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video_file")
    frame_rate=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$video_file")

    if [[ -z "$width" || -z "$height" || -z "$frame_rate" ]]; then
        echo "Error: Could not retrieve video properties (width, height, or frame_rate)." >&2
        return 1
    fi

    if [[ "$frame_rate" == */* ]]; then
        numerator=$(echo "$frame_rate" | cut -d'/' -f1)
        denominator=$(echo "$frame_rate" | cut -d'/' -f2)
        fps=$(echo "($numerator + $denominator/2) / $denominator" | bc)
    else
        fps=$frame_rate
    fi

    return 0
}

########################
extract_audio_blocks() {
    local video="$1"
    local output_dir="$TMP_DIR/audio"
    mkdir -p "$output_dir"
    get_video_properties "$video"
    if [[ -z "$fps" || "$fps" -eq 0 ]]; then
        echo "Error: Invalid frame rate (fps) detected: $fps" >&2
        return 1
    fi
    local has_audio
    has_audio=$(ffprobe -v error -show_entries stream=codec_type -select_streams a -of csv=p=0 "$video")
    if [[ -z "$has_audio" ]]; then
        echo "Warning: No audio stream found in the video. Skipping audio extraction " >&2
        return 0
    fi
    local frame_block_duration
    frame_block_duration=$(bc <<< "scale=2; 400 / $fps")
    local duration
    duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$video")
    if [[ -z "$duration" ]]; then
        echo "Error: Could not determine the duration of the video." >&2
        return 1
    fi
    local start_time=0
    local part=0
    while (( $(echo "$start_time < $duration" | bc -l) )); do
        local output_audio="$output_dir/audio${part}.wav"
       ffmpeg -y -i "$video" -ss "$start_time" -t "$frame_block_duration" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$output_audio" 2>&1 | \
    grep -i -e "audio" -e "wav" || {
        echo -e "Error: Failed to extract audio for block $part. " >&2 
    }
        start_time=$(bc <<< "$start_time + $frame_block_duration")
        part=$((part + 1))
    done
    echo -e "${BRIGHT_CYAN} Audio extraction completed successfully. ${NC}"
    return 0
}
#########################

echo -e "${GREEN}Choose video source:${NC}"
echo "1. YouTube Video"
echo "2. Local Video"

echo -e "${BRIGHT_CYAN}"
read -r -p "Enter your choice (1 or 2): " source_choice
echo -e "${NC}"

if [[ "$source_choice" == "1" ]]; then
    if ! command -v yt-dlp &> /dev/null; then
        echo "yt-dlp not found. Installing..."
        install_package "yt-dlp" || { echo "Failed to install yt-dlp. Plz Install it Manually. "; exit 1; }
    fi
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Enter YouTube video link: " yt_url
    echo -e "${NC}"

    # List available resolutions
    echo "Fetching available resolutions..."
    yt_dlp_info=$(yt-dlp -F "$yt_url")
    echo "Available resolutions (MP4 only):"
    yt_dlp_resolutions=$(echo "$yt_dlp_info" | grep -E '^[0-9]+ ' | grep -i "mp4" | awk '{print $1, $2, $3, $NF}')

    if [[ -z "$yt_dlp_resolutions" ]]; then
        echo "No MP4 formats available for this video."
        exit 1
    fi

    echo "$yt_dlp_resolutions"
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Enter the format code for the desired resolution: " format_code
    echo -e "${NC}"

    # Download video
    yt_dlp_output="downloaded_video.mp4"
    yt-dlp -f "$format_code" -o "$yt_dlp_output" "$yt_url" || {
        echo "Error downloading video from YouTube."
        exit 1
    }
    video="$yt_dlp_output"
elif [[ "$source_choice" == "2" ]]; then
    # Local video selected
    echo -e "${BRIGHT_YELLOW} Enter video path (e.g. /path/to/video.mp4) ${NC}"
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "=> PATH: " video
    echo -e "${NC}"
    if [ ! -f "$video" ]; then
        echo "Error: Video file does not exist."
        exit 1
    fi
else
    echo "Invalid choice. Exiting."
    exit 1
fi

echo -e "${BRIGHT_YELLOW}Choose configuration type to create bootanimation:${NC}"

echo "1. Use Video's Default Resolution and FPS"
echo "2. Custom configuration"
echo -e "${BRIGHT_CYAN}"
read -r -p "Enter your choice (1 or 2): " config_choice
echo -e "${NC}"

if [[ "$config_choice" == "1" ]]; then
    get_video_properties "$video"
    echo "Using video properties:"
    echo "Resolution: ${width}x${height}"
    echo "FPS: $fps"
    
    # Prompt for audio inclusion
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Do you want to include audio with the bootanimation? (y/n): " include_audio
    echo -e "${NC}"

    if [[ "$include_audio" =~ ^[Yy]$ ]]; then
        echo "Audio will be included in the bootanimation."
        echo -e "${BRIGHT_RED} => ⚠️ Warning: Not all ROMs/devices support audio in bootanimations. Proceed at your own risk. ${NC}"
    
        extract_audio_blocks "$video"
    else
        echo "Audio will not be included."
    fi

    # Loop prompt for default configuration
    echo -e "${BRIGHT_YELLOW}Select BootAnimation Behaviour:${NC}"
    sleep 1
    echo " - 1. Bootanimation should stop if the device completes boot successfully.
 - 2. Bootanimation should play its full length, no matter what.
 - 3. Keep looping the animation until the device boots.
   => If your video is too short or if it is a GIF, choose 3.
   => If you are unsure, choose 1. "

    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Select Your Desired Option (1, 2, or 3): " loop_option
    echo -e "${NC}"
    
    if [[ "$loop_option" != "1" && "$loop_option" != "2" && "$loop_option" != "3" ]]; then
        echo "Error: Invalid option selected. Please select 1, 2, or 3."
        exit 1
    fi

else
    # Custom configuration
    echo "Custom configuration selected. Audio will be disabled by default."
    
    # Resolution Input
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Enter output resolution (e.g., 1080x1920): " resolution
    echo -e "${NC}"

    # Validate Resolution
    if [[ ! "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo -e "{BRIGHT_RED}Error: Invalid resolution format. Please use the format 'widthxheight' (e.g., 1080x1920). {NC}"
        exit 1
    fi
    width=$(echo "$resolution" | cut -d'x' -f1)
    height=$(echo "$resolution" | cut -d'x' -f2)

    # Frame Rate Input
    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Enter frame rate you want to put in bootanimation: " fps
    echo -e "${NC}"
    
    # Loop Option Prompt
    echo -e "${BRIGHT_YELLOW}Select BootAnimation Behaviour:${NC}"
    sleep 1
    echo " - 1. Bootanimation should stop if the device completes boot successfully.
 - 2. Bootanimation should play its full length, no matter what.
 - 3. Keep looping the animation until the device boots.
   => If your video is too short or if it is a GIF, choose '3'.
   => If you are unsure, choose 1."

    echo -e "${BRIGHT_YELLOW}"
    read -r -p "Select Your Desired Option (1, 2, or 3): " loop_option
    echo -e "${NC}"
    
    if [[ "$loop_option" != "1" && "$loop_option" != "2" && "$loop_option" != "3" ]]; then
        echo "Error: Invalid option selected. Please select 1, 2, or 3."
        exit 1
    fi
fi

# Prompt the user for the background color code
echo -e "${BRIGHT_CYAN}Select Background Color${NC}"
echo -e "${BRIGHT_RED} Leave Empty If you are not Sure ${NC}"
echo -e "${BRIGHT_YELLOW}"
read -r -p "=> Enter Background Color Code (e.g #FFFFFF) :" BC
echo -e "${NC}"
if [[ -n "$BC" ]]; then
    if [[ ! "$BC" =~ ^#?([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$ ]]; then
        echo -e "${BRIGHT_RED}Error: Invalid color code format.${NC}"
        exit 1
    fi
    BC="#${BC#\#}"
fi
# Prompt for output path 
echo -e "${BRIGHT_YELLOW} Enter path to save the Magisk module (e.g., /path/to/module/name.zip) ${NC}"
echo -e "${BRIGHT_YELLOW}"
read -r -p "=> PATH: " output_path
echo -e "${NC}"
if [[ ! "${output_path}" =~ \.zip$ ]]; then
    output_path="${output_path%/}/CreatedMagiskModule.zip"
fi
echo -e "${NC}"
sleep 1
echo -e "${BRIGHT_CYAN}========================================${NC}"
echo -e "${WHITE}               PROCESSING VIDEO               ${NC}"
echo -e "${BRIGHT_CYAN}========================================${NC}"
# Generate frames with ffmpeg
ffmpeg -i "$video" -vf "scale=${width}:${height}" "$TMP_DIR/frames/%06d.jpg" 2>&1 | \
grep --line-buffered -o 'frame=.*' | \
while IFS= read -r line; do
    echo "$line"
done

echo "Processing completed."


# Count frames
frame_count=$(find "$TMP_DIR/frames" -mindepth 1 -maxdepth 1 -type f | wc -l)
if [ "$frame_count" -eq 0 ]; then
    echo "Error: No frames generated. Exiting."
    echo "If you are using Termux, make sure you grant storage permissions by running:"
    echo " 'termux-setup-storage' "
    echo "and ensure the video file is correct"
    exit 1
fi
echo "Processed $frame_count frames."
echo -e "${GREEN} Arranging Frames ${NC}"
echo "$width $height $fps" > "$desc_file"

# Maximum frames per part
max_frames=400
part_index=0
frame_index=0

# Prepare initial part directory
mkdir -p "$TMP_DIR/result/part$part_index"

# Pack frames into parts
for frame in "$TMP_DIR/frames"/*.jpg; do
  mv "$frame" "$TMP_DIR/result/part$part_index/"
  frame_index=$((frame_index + 1))

  # If the maximum frames per part is reached, create a new part
  if [ "$frame_index" -ge "$max_frames" ]; then
    frame_index=0
    part_index=$((part_index + 1))
    mkdir -p "$TMP_DIR/result/part$part_index"
  fi
done

# audio
if [[ "$include_audio" =~ ^[Yy]$ ]]; then
  echo "Including audio for each part..."
  audio_index=0

  for part_dir in $(find "$TMP_DIR/result" -type d -name "part*" | sort -V); do
    audio_file="$TMP_DIR/audio/audio${audio_index}.wav"
    if [ -f "$audio_file" ]; then
      mv "$audio_file" "$part_dir/audio.wav"
      echo "Added audio${audio_index}.wav to $part_dir/audio.wav"
    else
      echo -e "${BRIGHT_RED} Warning: Expected audio file $audio_file not found. Video has no audio ? ${NC}"
    fi
    audio_index=$((audio_index + 1))
  done
else
  echo "Audio not selected. Skipping audio processing."
fi

# Create desc.txt and handle looping
if [[ "$loop_option" == "1" ]]; then
  for i in $(seq 0 "$part_index"); do
    echo "p 1 0 part$i${BC:+ $BC}" >> "$desc_file"
  done
elif [[ "$loop_option" == "2" ]]; then
  for i in $(seq 0 "$part_index"); do
    echo "c 1 0 part$i${BC:+ $BC}" >> "$desc_file"
  done
else
  for i in $(seq 0 "$part_index"); do
    echo "c 0 0 part$i${BC:+ $BC}" >> "$desc_file"
  done
fi

sleep 1
echo -e "${BRIGHT_CYAN}=========================================${NC}"

# Zip the bootanimation
echo " => Creating bootanimation.zip..."
if cd "$TMP_DIR/result" && zip -q -r -0 "$output_zip" ./*; then
    :
else
    echo "Error creating zip file."
    exit 1
fi
echo -e "${GREEN} => Animation Written Successfully ✅${NC}"

#Writing Module
echo -e "${BRIGHT_CYAN} => Writing Module${NC}"
mkdir -p "./magisk_module/animation"
mod="./magisk_module"
mkdir -p "$mod/META-INF/com/google/android/"
mkdir -p "$mod/webroot"

# Write Customize.sh
cat <<'EOF' > "$mod/customize.sh"
# This Installer is a part of Bootanimation-Creator-Script
# https://github.com/rhythmcache
# rhythmcache.t.me
ui_print " => This Module Was Created Using BootAnimation-Creator-Script"

# Function to install bootanimation files
install_bootanimation() {
    local target_dir="$1"
    mkdir -p "$MODPATH/$target_dir"
    if [ -f "/$target_dir/bootanimation.zip" ] && [ -f "/$target_dir/bootanimation-dark.zip" ]; then
        cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/$target_dir/bootanimation.zip"
        cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/$target_dir/bootanimation-dark.zip"
        echo "description=Bootanimations installed at $target_dir" >> "$MODPATH/module.prop"
    elif [ -f "/$target_dir/bootanimation.zip" ]; then
        cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/$target_dir/bootanimation.zip"
        echo "description=Bootanimation installed at $target_dir" >> "$MODPATH/module.prop"
    elif [ -f "/$target_dir/bootanimation-dark.zip" ]; then
        cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/$target_dir/bootanimation-dark.zip"
        echo "description=Bootanimation-dark.zip installed at $target_dir" >> "$MODPATH/module.prop"
    else
        return 1
    fi
}
if [ -f "/system/product/media/bootanimation.zip" ] || [ -f "/system/product/media/bootanimation-dark.zip" ]; then
    install_bootanimation "system/product/media"
elif [ -f "/system/media/bootanimation.zip" ] || [ -f "/system/media/bootanimation-dark.zip" ]; then
    install_bootanimation "system/media"
else
    ui_print "Failed to install. Your device is not currently supported."
    abort
fi
ui_print ""
ui_print ""
set_perm_recursive "$MODPATH" 0 0 0755 0644
rm -rf "$MODPATH/animation"
ui_print "[*] Installation Complete!"
EOF
# Create index.html
###########
cat <<'EOF' > "$mod/webroot/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bootanimation Creator Script</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            background-color: #000000;
            color: #ffffff;
            margin: 0;
            padding: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            overflow: hidden;
        }
        .window {
            background: rgba(18, 18, 18, 0.9);
            border-radius: 12px;
            width: 80%;
            max-width: 350px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 8px 16px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.08);
        }
        .window-header {
            display: flex;
            justify-content: flex-end;
            margin-bottom: 15px;
        }
        .button {
            width: 10px;
            height: 10px;
            margin-left: 6px;
            border-radius: 50%;
            cursor: pointer;
        }
        .button.red { background-color: #ff5f56; }
        .button.yellow { background-color: #ffbd2e; }
        .button.green { background-color: #27c93f; }
        .header {
            font-size: 20px;
            font-weight: bold;
            color: #bb86fc;
            margin-bottom: 8px;
        }
        .subheading {
            font-size: 14px;
            color: #b0bec5;
            margin-bottom: 15px;
        }
        .icons {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }
        .icon, .play-icon {
            padding: 12px;
            border-radius: 10px;
            background-color: #333333;
            color: #ffffff;
            font-size: 14px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.2);
        }
        .icon:hover, .play-icon:hover {
            background-color: #444444;
            transform: translateY(-2px);
        }
        .play-icon {
            margin-top: 12px;
        }
        .play-warning {
            font-size: 12px;
            color: #b0bec5;
            margin-top: 8px;
        }
        .ksu-dialog {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: #121212; /* Opaque black */
    padding: 10px;
    border-radius: 6px;
    text-align: center;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
    display: none;
    z-index: 1000;
    font-size: 12px;
}
.ksu-dialog button {
    background: #222222;
    color: #ffffff;
    border: none;
    padding: 5px 10px;
    border-radius: 4px;
    cursor: pointer;
    margin-top: 5px;
    font-size: 12px;
}
    </style>
</head>
<body>
    <div class="window">
        <div class="window-header">
            <div class="button red"></div>
            <div class="button yellow"></div>
            <div class="button green"></div>
        </div>
        <div class="header">Hi There</div>
        <div class="subheading">Bootanimation-Creator-Script</div>
        <div class="icons">
            <div class="icon" onclick="openLink('https://github.com/rhythmcache/Video-to-BootAnimation-Creator-Script')">GitHub Page</div>
            <div class="icon" onclick="openLink('https://rhythmcache.t.me')">Telegram</div>
        </div>
        <div class="play-icon" onclick="playBootAnimation()">Preview Current Bootanimation</div>
        <div class="play-warning">
            Preview may not work on some devices or if you chose "Bootanimation Behaviour 1" while creating bootanimation.
        </div>
    </div>
    <div id="ksuDialog" class="ksu-dialog">
        <p>KernelSU API access is required. Grant access?</p>
        <button id="requestKsuApiButton">Grant Access</button>
    </div>

    <script>
        function openLink(url) {
            if (typeof ksu !== 'undefined' && ksu.exec) {
                ksu.exec(`am start -a android.intent.action.VIEW -d "${url}"`);
            } else {
                window.open(url, '_blank');
            }
        }
        function playBootAnimation() {
            if (typeof ksu !== 'undefined' && ksu.exec) {
                ksu.exec('bootanimation');
            }
        }
        async function initializeEnvironment() {
            try {
                if (typeof ksu === 'undefined' && typeof mmrl === 'undefined' && typeof $cbootanimation === 'undefined') {
                    return;
                }
                if (typeof ksu === 'undefined' || !ksu.exec) {
                    if (typeof mmrl !== 'undefined' && typeof $cbootanimation !== 'undefined') {
                        const ksuDialog = document.getElementById('ksuDialog');
                        ksuDialog.style.display = 'flex';
                        document.getElementById('requestKsuApiButton').addEventListener('click', async () => {
                            try {
                                await $cbootanimation.requestAdvancedKernelSUAPI();
                                ksuDialog.style.display = 'none';
                                initializeEnvironment();
                            } catch {}
                        });
                    }
                    return;
                }
            } catch {}
        }
        initializeEnvironment();
    </script>
</body>
</html>
EOF
###########
cat <<'EOF' > "$mod/module.prop"
id=cbootanimation
name=Bootanimation-Creator-Script
version=2
versionCode=30
author=rhythmcache.t.me | github.com/rhythmcache
EOF
#If written
echo -e "${BRIGHT_CYAN} => Created Props${NC}"

#  update-binary
echo " => Writing update-binary"
cat <<'EOF' > "$mod/META-INF/com/google/android/update-binary"
#!/sbin/sh

#################
# Initialization
#################

umask 022

# echo before loading util_functions
ui_print() { echo "$1"; }

require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}

#########################
# Load util_functions.sh
#########################

OUTFD=$2
ZIPFILE=$3

mount /data 2>/dev/null

[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk

install_module
exit 0
#######
EOF
#written
echo -e "${BRIGHT_CYAN} => update-binary Written Succesfully${NC}"
sleep 1 

# Updater Script
echo " => writing updater-script"
cat <<'EOF' > "$mod/META-INF/com/google/android/updater-script"
#MAGISK
EOF
echo -e "${BRIGHT_CYAN} => Written Succesfully${NC}"

# Copy the bootanimation.zip into the animation folder
if [ -d "$mod/animation" ]; then
cp "$output_zip" "$mod/animation/bootanimation.zip"
echo " => Creating Magisk Module."
# creating module
if cd "$mod" && zip -q -r "$output_path" ./*; then
    :
else
    echo "Error creating module zip file."
    exit 1
fi

sleep 1
echo -e "${BRIGHT_CYAN}=====================================================${NC}"
echo -e "${WHITE}         -Magisk-Module ${NC}"
echo -e "${WHITE}         created at $output_path ${NC}"
echo -e "${BRIGHT_CYAN}==================================================== ${NC}"
sleep 1

# Clean up temporary files
echo " => Removing Temporary Files "
rm -rf "$TMP_DIR"
rm -rf "$mod"
echo -e "${BRIGHT_CYAN} => Process Complete${NC}"
exit 0
else
  echo "Error: Animation folder not found in $TMP_DIR/module."
  sleep 1
  echo -e "${BRIGHT_CYAN}Report Bugs at @xlmlchat${NC}"
  exit 1
fi
