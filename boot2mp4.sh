#!/bin/bash

# Function to install a package if not present
install_package() {
  local package="$1"

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
  elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y "$package"
  else
    echo "Error: Unsupported package manager. Please install $package manually."
    exit 1
  fi
}

# Check for ffmpeg and unzip binaries, install if missing
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Installing..."
    install_package "ffmpeg" || { echo "Failed to install ffmpeg."; exit 1; }
fi

if ! command -v unzip &> /dev/null; then
    echo "unzip not found. Installing..."
    install_package "unzip" || { echo "Failed to install unzip."; exit 1; }
fi

# Define green color for text
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Prompt for bootanimation zip and output video path with green color
echo -e "${GREEN}Enter bootanimation zip path (e.g., /path/to/bootanimation.zip):${NC}"
read -p "" zip_path
if [ ! -f "$zip_path" ]; then
    echo "Error: Zip file does not exist."
    exit 1
fi

echo -e "${GREEN}Enter output video path (e.g., /path/to/output.mp4):${NC}"
read -p "" output_video

# Temporary directory setup for extraction in the current directory
TMP_DIR="./bootanim_extract"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/frames"
unzip -q "$zip_path" -d "$TMP_DIR" || { echo "Error unzipping file."; exit 1; }

# Read desc.txt
desc_file="$TMP_DIR/desc.txt"
if [ ! -f "$desc_file" ]; then
    echo "Error: desc.txt not found in bootanimation.zip."
    exit 1
fi

# Parse width, height, and fps from desc.txt
read width height fps < <(head -n 1 "$desc_file")
echo "Resolution: ${width}x${height}, FPS: $fps"

# Collect frames from all part directories (both jpg and png formats)
counter=0
for part in "$TMP_DIR"/part*/; do
    for ext in jpg png; do
        for frame in "$part"*.$ext; do
            if [ -f "$frame" ]; then
                # Rename frames in sequential order for ffmpeg
                printf -v new_frame "$TMP_DIR/frames/frame%09d.$ext" "$counter"
                cp "$frame" "$new_frame"
                counter=$((counter + 1))
            fi
        done
    done
done

# Check if any frames were copied
if [ "$counter" -eq 0 ]; then
    echo "Error: No frames found in bootanimation.zip."
    echo "Check the structure of the extracted files manually."
    rm -rf "$TMP_DIR"
    exit 1
fi

# Generate video with ffmpeg
echo "Creating video from frames..."
ffmpeg -framerate "$fps" -i "$TMP_DIR/frames/frame%09d.jpg" -s "${width}x${height}" -c:v libx264 -pix_fmt yuv420p "$output_video" || {
    echo "Error creating video from frames."
    rm -rf "$TMP_DIR"
    exit 1
}

# Clean up
rm -rf "$TMP_DIR"
echo "Video created at $output_video"
