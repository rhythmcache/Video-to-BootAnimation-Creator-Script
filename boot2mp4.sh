#!/bin/bash
# Copyright (C) 2025 github.com/rhythmcache
#
# This is a free script: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

# The above copyright notice and this license notice shall be included
# in all copies or substantial portions of the Software.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
    apt update && apt install -y "$package"
  else
    echo "Error: Unsupported package manager. Please install $package manually."
    exit 1
  fi
}

if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg not found. Installing..."
    install_package "ffmpeg" || { echo "Failed to install ffmpeg."; exit 1; }
fi

#if ! command -v zip &> /dev/null; then
 #   echo "zip not found. Installing..."
  #  install_package "zip" || { echo "Failed to install zip."; exit 1; }
#fi

if [ $# -eq 2 ]; then
    zip_path="$1"
    output_path="$2"
elif [ $# -eq 0 ]; then
    echo -e "${GREEN}Enter bootanimation zip path (e.g., /path/to/bootanimation.zip):${NC}"
    read zip_path
    echo -e "${GREEN}Enter output video path (e.g., /path/to/output.mp4):${NC}"
    read output_path
else
    echo "Usage: $0 [bootanimation_zip_path output_video_path]"
    echo "Example: $0 /path/to/bootanimation.zip /path/to/output.mp4"
    exit 1
fi

work_dir="$(pwd)/tmp"
mkdir -p "$work_dir"
extract_dir="$work_dir/extracted"
frames_dir="$work_dir/frames"

cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT

echo -e "${YELLOW}Extracting bootanimation.zip...${NC}"
mkdir -p "$extract_dir"
unzip -o "$zip_path" -d "$extract_dir" > /dev/null || { echo -e "${RED}Failed to unzip bootanimation.zip${NC}"; exit 1; }
desc_file="$extract_dir/desc.txt"

if [[ -f "$desc_file" ]]; then
    # Find first non-comment line
    first_line=$(grep -vE '^\s*#' "$desc_file" | head -n 1)
    
    # Check for the global format first
    if [[ "$first_line" == g* ]]; then
        # Parse global format: g width height offsetx offsety fps
        read -r _ width height offsetx offsety fps <<< "$first_line"
        resolution="${width}x${height}"
        echo -e "${GREEN}Resolution: $resolution, FPS: $fps${NC}"
    else
        # Fallback to original format
        read -r width height fps <<< "$first_line"
        resolution="${width}x${height}"
    fi
    
    if [[ -z "$resolution" || -z "$fps" ]]; then
        echo -e "${RED}Error: Unable to extract resolution or frame rate from desc.txt.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Resolution: $resolution, FPS: $fps${NC}"
else
    echo -e "${RED}Error: desc.txt not found in bootanimation zip.${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking for audio...${NC}"
audio_found=false
part_videos=()
for part_dir in "$extract_dir"/*/; do
    if [[ -f "$part_dir/audio.wav" ]]; then
        audio_found=true
        echo -e "${GREEN}Found audio in $part_dir${NC}"
        mkdir -p "$frames_dir"
        part_frames_dir="$frames_dir/$(basename "$part_dir")"
        mkdir -p "$part_frames_dir"
        
        # Copy frames
        jpg_exists=$(find "$part_dir" -type f -iname "*.jpg" | wc -l)
        png_exists=$(find "$part_dir" -type f -iname "*.png" | wc -l)
        if [ "$png_exists" -gt 0 ]; then
            extension="png"
        elif [ "$jpg_exists" -gt 0 ]; then
            extension="jpg"
        else
            echo -e "${RED}No valid frames (PNG or JPG) found in $part_dir. Skipping.${NC}"
            continue
        fi
        
        frame_counter=1
        find "$part_dir" -type f -iname "*.$extension" | sort | while read -r frame; do
            printf -v new_name "%05d.$extension" "$frame_counter"
            cp "$frame" "$part_frames_dir/$new_name"
            ((frame_counter++))
        done
        
        # Generate part video
        part_video="$work_dir/$(basename "$part_dir").mp4"
        ffmpeg -y -framerate "$fps" -i "$part_frames_dir/%05d.$extension" -i "$part_dir/audio.wav" \
            -shortest -c:v libx264 -pix_fmt yuv420p -s "$resolution" -c:a aac "$part_video" || {
            echo -e "${RED}Failed to generate video for $part_dir.${NC}"
            exit 1
        }
        part_videos+=("$part_video")
    fi
done

if [ "$audio_found" = true ]; then
    echo -e "${YELLOW}Merging part videos...${NC}"
    concat_file="$work_dir/concat_list.txt"
    for video in "${part_videos[@]}"; do
        echo "file '$video'" >> "$concat_file"
    done
    ffmpeg -y -f concat -safe 0 -i "$concat_file" -c copy "$output_path" || {
        echo -e "${RED}Failed to merge videos.${NC}"
        exit 1
    }
    echo -e "${GREEN}Video successfully generated  at $output_path.${NC}"
else
    echo -e "${YELLOW}No audio found in bootanimation ?...${NC}"
    # Original frame processing logic
    mkdir -p "$frames_dir"
    frame_counter=1
    jpg_exists=$(find "$extract_dir" -type f -iname "*.jpg" | wc -l)
    png_exists=$(find "$extract_dir" -type f -iname "*.png" | wc -l)
    if [ "$png_exists" -gt 0 ]; then
        extension="png"
    elif [ "$jpg_exists" -gt 0 ]; then
        extension="jpg"
    else
        echo -e "${RED}No valid frames (PNG or JPG) found. Exiting.${NC}"
        exit 1
    fi
    find "$extract_dir" -type f -iname "*.$extension" | sort | while read -r frame; do
        printf -v new_name "%05d.$extension" "$frame_counter"
        cp "$frame" "$frames_dir/$new_name"
        ((frame_counter++))
    done

    echo -e "${YELLOW}Generating video...${NC}"
    if ! ffmpeg -y -framerate "$fps" -i "$frames_dir/%05d.$extension" -s "$resolution" -pix_fmt yuv420p "$output_path" 2>&1 | grep "frame"; then
        echo -e "${RED}Failed to generate video.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Video successfully generated at $output_path.${NC}"
fi
