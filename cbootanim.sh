#!/bin/bash
# Bootanimation creator script by github.com/rhythmcache
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
check_termux_environment() {
    if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && [ -x "$(command -v termux-setup-storage)" ]; then
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

if ! command -v zip &> /dev/null; then
    echo "zip not found. Installing..."
    install_package "zip" || { echo "Failed to install zip."; exit 1; }
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip not found. Installing..."
    install_package "unzip" || { echo "Failed to install unzip."; exit 1; }
fi
get_video_properties() {
    local video_file="$1"
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video_file")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video_file")
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$video_file" | bc)
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
read -p "Enter your choice (1 or 2): " source_choice
echo -e "${NC}"

if [[ "$source_choice" == "1" ]]; then
    if ! command -v yt-dlp &> /dev/null; then
        echo "yt-dlp not found. Installing..."
        install_package "yt-dlp" || { echo "Failed to install yt-dlp. Plz Install it Manually. "; exit 1; }
    fi
    echo -e "${BRIGHT_YELLOW}"
    read -p "Enter YouTube video link: " yt_url
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
    read -p "Enter the format code for the desired resolution: " format_code
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
    read -p "PATH: " video
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
read -p "Enter your choice (1 or 2): " config_choice
echo -e "${NC}"

if [[ "$config_choice" == "1" ]]; then
    get_video_properties "$video"
    echo "Using video properties:"
    echo "Resolution: ${width}x${height}"
    echo "FPS: $fps"
    
    # Prompt for audio inclusion
    echo -e "${BRIGHT_YELLOW}"
    read -p "Do you want to include audio with the bootanimation? (y/n): " include_audio
    echo -e "${NC}"

    if [[ "$include_audio" =~ ^[Yy]$ ]]; then
        echo "Audio will be included in the bootanimation."
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
   - If your video is too short or if it is a GIF, choose 3.
   - If you are unsure, choose 1. "

    echo -e "${BRIGHT_YELLOW}"
    read -p "Select Your Desired Option (1, 2, or 3): " loop_option
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
    read -p "Enter output resolution (e.g., 1080x1920): " resolution
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
    read -p "Enter frame rate you want to put in bootanimation: " fps
    echo -e "${NC}"
    
    # Loop Option Prompt
    echo -e "${BRIGHT_YELLOW}Select BootAnimation Behaviour:${NC}"
    sleep 1
    echo " - 1. Bootanimation should stop if the device completes boot successfully.
 - 2. Bootanimation should play its full length, no matter what.
 - 3. Keep looping the animation until the device boots.
   - If your video is too short or if it is a GIF, choose '3'.
   - If you are unsure, choose 1."

    echo -e "${BRIGHT_YELLOW}"
    read -p "Select Your Desired Option (1, 2, or 3): " loop_option
    echo -e "${NC}"
    
    if [[ "$loop_option" != "1" && "$loop_option" != "2" && "$loop_option" != "3" ]]; then
        echo "Error: Invalid option selected. Please select 1, 2, or 3."
        exit 1
    fi
fi

# Prompt for output path after loop option is specified
echo -e "${BRIGHT_YELLOW} Enter path to save the Magisk module (e.g., /path/to/module/name.zip) ${NC}"
echo -e "${BRIGHT_YELLOW}"
read -p "PATH: " output_path
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
frame_count=$(ls -1 "$TMP_DIR/frames" | wc -l)
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

  for part_dir in "$TMP_DIR/result/part"*; do
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
    echo "p 1 0 part$i" >> "$desc_file"
  done
  elif [[ "$loop_option" == "2" ]]; then
  for i in $(seq 0 "$part_index"); do
  echo "c 1 0 part$i" >> "$desc_file"
  done
else
  for i in $(seq 0 "$part_index"); do
    echo "c 0 0 part$i" >> "$desc_file"
  done
fi

sleep 1
echo -e "${BRIGHT_CYAN}=========================================${NC}"

# Zip the bootanimation
echo " > > > Creating bootanimation.zip..."
cd "$TMP_DIR/result" && zip -r -0 "$output_zip" ./* > /dev/null 2>&1 || { echo "Error creating zip file."; exit 1; }
echo -e "${GREEN} > > > animation written successfully${NC}"

#Writing Module
echo -e "${BRIGHT_CYAN} > > > Writing Module${NC}"
mkdir -p "./magisk_module/animation"
mod="./magisk_module"
mkdir -p "$mod/META-INF/com/google/android/"

# Write Customize.sh
cat <<'EOF' > "$mod/customize.sh"
# This Installer is a part of Bootanimation-Creator-Script
# https://github.com/rhythmcache
# rhythmcache.t.me
if [ -f "/system/product/media/bootanimation.zip" ]; then
    mkdir -p "$MODPATH/system/product/media"
    cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/system/product/media/"
    ui_print "Installing bootanimation to product/media"
    echo "description=bootanimation installed at /system/product/media , if it isn't working, report it to @ximistuffschat on tg" >> "$MODPATH/module.prop"
elif [ -f "/system/media/bootanimation.zip" ]; then
    mkdir -p "$MODPATH/system/media"
    cp -f "$MODPATH/animation/bootanimation.zip" "$MODPATH/system/media/"
    ui_print "Installing bootanimation to system/media"
    echo "description=bootanimation installed at /system/media, if it isn't working, report it to @ximistuffschat on tg" >> "$MODPATH/module.prop"
else
    ui_print "Failed to install. Bootanimation file not found in system/product/media or system/media."
    abort
fi
ui_print ""
ui_print "[*] Installation Complete ! "
ui_print ""
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
rm -rf "$MODPATH/animation"

EOF
# Create or overwrite the file "module.prop" with the content below
cat <<'EOF' > "$mod/module.prop"
id=cbootanimation
name=Bootanimation-Creator-Script
version=1.0
versionCode=26
author=rhythmcache.t.me | github.com/rhythmcache
EOF
#If written
echo -e "${BRIGHT_CYAN} > > > Created props${NC}"

#  update-binary
echo " > > > Writing update-binary"
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
echo -e "${BRIGHT_CYAN} > > > update-binary written succesfully${NC}"
sleep 1 

# Updater Script
echo " > > > writing updater-script"
cat <<'EOF' > "$mod/META-INF/com/google/android/updater-script"
#MAGISK
EOF
echo -e "${BRIGHT_CYAN} > > > written succesfully${NC}"

# Copy the bootanimation.zip into the animation folder
if [ -d "$mod/animation" ]; then
cp "$output_zip" "$mod/animation/bootanimation.zip"
echo " > > > Creating Magisk Module."
# creating module
cd "$mod" && zip -r "$output_path" ./* > /dev/null 2>&1 || { echo "Error creating module zip file."; exit 1; }
sleep 1
echo -e "${BRIGHT_CYAN}=====================================================${NC}"
echo -e "${WHITE}         -Magisk-Module ${NC}"
echo -e "${WHITE}         created at $output_path ${NC}"
echo -e "${BRIGHT_CYAN}==================================================== ${NC}"
sleep 1

# Clean up temporary files
echo " Removing Temporary Files "
rm -rf "$TMP_DIR"
rm -rf "$mod"
echo -e "${GREEN}Process Complete${NC}"
echo -e "${BRIGHT_CYAN} > > > Report Bugs at @ximistuffschat${NC}"

exit 0
else
  echo "Error: Animation folder not found in $TMP_DIR/module."
  sleep 1
  echo -e "${BRIGHT_CYAN}Report Bugs at @ximistuffschat${NC}"
  exit 1
fi
