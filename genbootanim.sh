#!/bin/bash

# Set color variables
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Display ASCII art in green color
echo -e "${GREEN}"
echo " _                 _              _                 _   _             "
echo "| |__   ___   ___ | |_ __ _ _ __ (_)_ __ ___   __ _| |_(_) ___  _ __  "
echo "| '_ \ / _ \ / _ \| __/ _\` | '_ \| | '_ \` _ \ / _\` | __| |/ _ \| '_ \ "
echo "| |_) | (_) | (_) | || (_| | | | | | | | | | | (_| | |_| | (_) | | | |"
echo "|_.__/ \___/ \___/ \__\__,_|_| |_|_|_| |_| |_|\__,_|\__|_|\___/|_| |_|"
echo -e "${NC}"
echo -e "${GREEN}"
echo "        ___               _             "
echo "  / __\ __ ___  __ _| |_ ___  _ __ "
echo " / / | '__/ _ \/ _\` | __/ _ \| '__|"
echo "/ /__| | |  __/ (_| | || (_) | |   "
echo "\____/_|  \___|\__,_|\__\___/|_|   "
echo -e "${NC}\n"

# Function to install a package
install_package() {
  local package="$1"
  
  # Detect package manager and install the package
  if command -v pkg &> /dev/null; then
    pkg update && pkg install -y "$package"
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
  elif command -v apt &> /dev/null; then  # Termux package manager
    sudo apt update && sudo apt install -y "$package"
  else
    echo "Error: Unsupported package manager. Please install $package manually."
    exit 1
  fi
}

# Check for ffmpeg and zip binaries and install if missing
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Installing..."
    install_package "ffmpeg" || { echo "Failed to install ffmpeg."; exit 1; }
fi

if ! command -v zip &> /dev/null; then
    echo "zip not found. Installing..."
    install_package "zip" || { echo "Failed to install zip."; exit 1; }
fi

# Prompt for video parameters with green text
echo -e "${GREEN}"
read -p "Enter video path (e.g., /path/to/video.mp4): " video
echo -e "${NC}"
if [ ! -f "$video" ]; then
    echo "Error: Video file does not exist."
    exit 1
fi

echo -e "${GREEN}"
read -p "Enter output resolution (e.g., 1080x1920): " resolution
echo -e "${NC}"
width=$(echo "$resolution" | cut -d'x' -f1)
height=$(echo "$resolution" | cut -d'x' -f2)

echo -e "${GREEN}"
read -p "Enter frame rate you want to put in bootanimation: " fps
echo -e "${NC}"

echo -e "${GREEN}"
read -p "Enter output path (e.g., /path/to/output.zip): " output_path
echo -e "${NC}"

# Prompt for looping option
echo -e "${GREEN}"
read -p "Loop animation? (1 for yes, 2 for no): " loop_option
echo -e "${NC}"

# Check if the entered option is valid
if [[ "$loop_option" != "1" && "$loop_option" != "2" ]]; then
    echo "Error: Invalid option selected. Please select 1 or 2."
    exit 1
fi

# Temporary directory setup for processing
# Get the current directory dynamically and assign it to TMP_DIR
TMP_DIR="$(pwd)/bootanim"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/frames" "$TMP_DIR/result"
desc_file="$TMP_DIR/result/desc.txt"
output_zip="$output_path"

# Generate frames with ffmpeg
ffmpeg -i "$video" -vf "scale=${width}:${height}" "$TMP_DIR/frames/%06d.jpg" || {
    echo "Error generating frames from video."
    exit 1
}

# Count frames
frame_count=$(ls -1 "$TMP_DIR/frames" | wc -l)
if [ "$frame_count" -eq 0 ]; then
    echo "No frames generated. Exiting."
    exit 1
fi
echo "Processed $frame_count frames."

# Create desc.txt
echo "$width $height $fps" > "$desc_file"

# Pack frames into parts if more than 400 frames
max_frames=400
part_index=0
frame_index=0

mkdir -p "$TMP_DIR/result/part$part_index"
for frame in "$TMP_DIR/frames"/*.jpg; do
  mv "$frame" "$TMP_DIR/result/part$part_index/"
  frame_index=$((frame_index + 1))

  if [ "$frame_index" -ge "$max_frames" ]; then
    frame_index=0
    part_index=$((part_index + 1))
    mkdir -p "$TMP_DIR/result/part$part_index"
  fi
done
# Create desc.txt and handle looping
if [[ "$loop_option" == "1" ]]; then
  for i in $(seq 0 "$part_index"); do
    echo "c 0 0 part$i" >> "$desc_file"
  done
else
  # Append part entries in desc.txt
  for i in $(seq 0 "$part_index"); do
    echo "p 1 0 part$i" >> "$desc_file"
  done
fi
# Zip the bootanimation
echo "Creating bootanimation.zip..."
cd "$TMP_DIR/result" || { echo "Error accessing result directory."; exit 1; }
zip -r -0 "$output_zip" . || { echo "Error creating zip file."; exit 1; }
echo "Bootanimation created at $output_zip"

# Clean up
rm -rf "$TMP_DIR"
echo "Process complete."
