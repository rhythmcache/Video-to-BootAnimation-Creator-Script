#!/bin/bash
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

if ! command -v zip &> /dev/null; then
    echo "zip not found. Installing..."
    install_package "zip" || { echo "Failed to install zip."; exit 1; }
fi


echo -e "${GREEN}Enter bootanimation zip path (e.g., /path/to/bootanimation.zip):${NC}"
read zip_path
echo -e "${GREEN}Enter output video path (e.g., /path/to/output.mp4):${NC}"
read output_path

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
    resolution=$(awk 'NR==1 {print $1 "x" $2}' "$desc_file")
    fps=$(awk 'NR==1 {print $3}' "$desc_file")  
    
    if [[ -z "$resolution" || -z "$fps" ]]; then
        echo -e "${RED}Error: Unable to extract resolution or frame rate from desc.txt.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Resolution: $resolution, FPS: $fps${NC}"
else
    echo -e "${RED}Error: desc.txt not found in bootanimation zip.${NC}"
    exit 1
fi

echo -e "${YELLOW}Processing frames...${NC}"
mkdir -p "$frames_dir"
find "$extract_dir" -type f -name "*.jpg" -o -name "*.png" | while read -r frame; do
    base_name=$(basename "$frame")
    num_part=$(echo "$base_name" | grep -oE '[0-9]+')

    if [[ -n $num_part ]]; then
        printf -v new_name "%09d.${base_name##*.}" $((10#$num_part))
        cp "$frame" "$frames_dir/$new_name"
    else
        echo -e "${YELLOW}Warning: Unable to extract sequence number from $base_name, skipping.${NC}"
    fi
done

if [[ $(ls -1 "$frames_dir" | wc -l) -eq 0 ]]; then
    echo -e "${RED}No valid frames found. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}Generating video...${NC}"
if ! ffmpeg -y -framerate "$fps" -i "$frames_dir/%09d.*" -s "$resolution" -pix_fmt yuv420p "$output_path" 2>&1 | grep "frame"; then
    echo -e "${RED}Failed to generate video.${NC}"
    exit 1
fi

echo -e "${GREEN}Video successfully generated at $output_path.${NC}"
