#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "░█▀▄░█▀█░█▀█░▀█▀░█▀█░█▀█░▀█▀░█▄█░█▀█░▀█▀░▀█▀░█▀█░█▀█"
echo "░█▀▄░█░█░█░█░░█░░█▀█░█░█░░█░░█░█░█▀█░░█░░░█░░█░█░█░█"
echo "░▀▀░░▀▀▀░▀▀▀░░▀░░▀░▀░▀░▀░▀▀▀░▀░▀░▀░▀░░▀░░▀▀▀░▀▀▀░▀░▀"
echo -e "${GREEN}"
echo "░█▀▀░█▀▄░█▀▀░█▀█░▀█▀░█▀█░█▀▄"
echo "░█░░░█▀▄░█▀▀░█▀█░░█░░█░█░█▀▄"
echo "░▀▀▀░▀░▀░▀▀▀░▀░▀░░▀░░▀▀▀░▀░▀"
echo -e "${NC}"
# Function to install a package
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

# Check for ffmpeg and zip binaries and install if missing
if ! command -v ffmpeg &> /dev/null; then
  echo "ffmpeg not found. Installing..."
  install_package "ffmpeg" || { echo "Failed to install ffmpeg."; exit 1; }
fi

if ! command -v zip &> /dev/null; then
  echo "zip not found. Installing..."
  install_package "zip" || { echo "Failed to install zip."; exit 1; }
fi

rm -f downloaded_video.*

# Prompt for video source
echo -e "${GREEN}Choose video source:${NC}"
echo "1. YouTube Video"
echo "2. Local Video"
read -p "Enter your choice (1 or 2): " source_choice

if [[ "$source_choice" == "1" ]]; then
  # YouTube video selected
  if ! command -v yt-dlp &> /dev/null; then
    echo "yt-dlp not found. Installing..."
    install_package "yt-dlp" || { echo "Failed to install yt-dlp."; exit 1; }
  fi

  read -p "Enter YouTube video link: " yt_url

  # List available resolutions
  echo "Fetching available resolutions..."
  yt_dlp_info=$(yt-dlp -F "$yt_url")
  echo "$yt_dlp_info"

  echo "Choose resolution:"
  yt_dlp_resolutions=$(echo "$yt_dlp_info" | grep -E '^[0-9]+ ' | awk '{print $1, $2, $3, $NF}')
  echo "$yt_dlp_resolutions"
  read -p "Enter the format code for the desired resolution: " format_code

  # Download video
  yt_dlp_output="downloaded_video.mp4"
  yt-dlp -f "$format_code" -o "$yt_dlp_output" "$yt_url" || {
    echo "Error downloading video from YouTube."
    exit 1
  }
  video="$yt_dlp_output"
elif [[ "$source_choice" == "2" ]]; then
  # Local video selected
  read -p "Enter video path (e.g., /path/to/video.mp4): " video
  if [ ! -f "$video" ]; then
    echo "Error: Video file does not exist."
    exit 1
  fi
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Continue with bootanimation creation
read -p "Enter output resolution (e.g., 1080x1920): " resolution
width=$(echo "$resolution" | cut -d'x' -f1)
height=$(echo "$resolution" | cut -d'x' -f2)

read -p "Enter frame rate you want to put in bootanimation: " fps
read -p "Enter output path (e.g., /path/to/output.zip): " output_path

read -p "Loop animation? (1 for yes, 2 for no): " loop_option
if [[ "$loop_option" != "1" && "$loop_option" != "2" ]]; then
  echo "Error: Invalid option selected. Please select 1 or 2."
  exit 1
fi

TMP_DIR="$(pwd)/bootanim"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/frames" "$TMP_DIR/result"
desc_file="$TMP_DIR/result/desc.txt"

ffmpeg -i "$video" -vf "scale=${width}:${height}" "$TMP_DIR/frames/%06d.jpg" || {
  echo "Error generating frames from video."
  exit 1
}

frame_count=$(ls -1 "$TMP_DIR/frames" | wc -l)
if [ "$frame_count" -eq 0 ]; then
  echo "No frames generated. Exiting."
  exit 1
fi
echo "Processed $frame_count frames."

echo "$width $height $fps" > "$desc_file"
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

if [[ "$loop_option" == "1" ]]; then
  for i in $(seq 0 "$part_index"); do
    echo "c 0 0 part$i" >> "$desc_file"
  done
else
  for i in $(seq 0 "$part_index"); do
    echo "c 1 0 part$i" >> "$desc_file"
  done
fi

cd "$TMP_DIR/result" || { echo "Error accessing result directory."; exit 1; }
zip -r -0 "$output_path" . || { echo "Error creating zip file."; exit 1; }
echo "Bootanimation created at $output_path"

rm -rf "$TMP_DIR"
echo "Process complete."
