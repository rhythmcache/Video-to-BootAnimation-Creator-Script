#!/bin/bash

# Set color variables
WHITE='\033[1;37m'
BRIGHT_YELLOW='\033[1;33m'
BRIGHT_RED='\033[1;31m'
BRIGHT_CYAN='\033[1;36m'
GREEN='\033[0;32m'
NC='\033[0m'

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
sleep 1
echo -e "${BRIGHT_CYAN}========================================${NC}"
echo -e "${WHITE}                 by  rhythmcache              ${NC}"
echo -e "${BRIGHT_CYAN}========================================${NC}"
sleep 2


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

# Check for ffmpeg and zip and unzip binaries and install if missing
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
echo "Available resolutions (MP4 only):"
yt_dlp_resolutions=$(echo "$yt_dlp_info" | grep -E '^[0-9]+ ' | grep -i "mp4" | awk '{print $1, $2, $3, $NF}')

if [[ -z "$yt_dlp_resolutions" ]]; then
  echo "No MP4 formats available for this video."
  exit 1
fi

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


echo -e "${GREEN}"
read -p "Enter output resolution (e.g., 1080x1920): " resolution
echo -e "${NC}"
width=$(echo "$resolution" | cut -d'x' -f1)
height=$(echo "$resolution" | cut -d'x' -f2)

echo -e "${GREEN}"
read -p "Enter frame rate you want to put in bootanimation: " fps
echo -e "${NC}"

echo -e "${GREEN}"
read -p "Enter path to save the Magisk module (e.g., /path/to/module/name.zip): " output_path
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

# Temporary directory setup
TMP_DIR="$(pwd)/bootanim"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/frames" "$TMP_DIR/result"
desc_file="$TMP_DIR/result/desc.txt"
output_zip="./bootanimation.zip"

sleep 1
echo -e "${BRIGHT_CYAN}========================================${NC}"
echo -e "${WHITE}            Running Core Script               ${NC}"
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
mkdir -p "$mod//META-INF/com/google/android/"

# Create or overwrite the file "install" with the content below
cat <<'EOF' > "$mod/install.sh"
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=false
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"
REPLACE="
"
print_modname() {
ui_print "=================="
ui_print "Bootanimation"
ui_print "=================="
}
on_install() {
unzip -o "$ZIPFILE" 'animation/*' -d $MODPATH >&2
if [ -f "/system/product/media/bootanimation.zip" ]; then
mkdir -p $MODPATH/system/product/media
cp -f $MODPATH/animation/bootanimation.zip $MODPATH/system/product/media/
ui_print "Installing bootanimation to product/media"
elif [ -f "/system/media/bootanimation.zip" ]; then
mkdir -p $MODPATH/system/media
cp -f $MODPATH/animation/bootanimation.zip $MODPATH/system/media/
ui_print " [*] Installing bootanimation to system/media"
else
ui_print "Failed to install. Please report in the support group."
exit 1
fi
ui_print ""
ui_print " [*] Done!"
ui_print ""
}
set_permissions() {
set_perm_recursive $MODPATH/system 0 0 0755 0644
}
rm -rf $MODPATH/animation
unity_custom() {
: # Leave this empty unless adding custom installation/uninstallation logic
}
EOF
# Create or overwrite the file "module.prop" with the content below
cat <<'EOF' > "$mod/module.prop"
id=CBootanimation
name=Bootanimation-Creator-Script
version=2.0
versionCode=23
author=@coldnw
description=follow @ximistuffs on telegram
EOF
#If written
echo -e "${BRIGHT_CYAN} > > > Created props${NC}"

#  update-binary
echo " > > > Writing update-binary"
cat <<'EOF' > "$mod/META-INF/com/google/android/update-binary"
umask 022
TMPDIR=/dev/tmp
PERSISTDIR=/sbin/.magisk/mirror/persist
rm -rf $TMPDIR 2>/dev/null
mkdir -p $TMPDIR
ui_print() { echo "$1"; }
require_new_magisk() {
ui_print "*******************************"
ui_print " Please install Magisk v19.0+! "
ui_print "*******************************"
exit 1
}
is_legacy_script() {
unzip -l "$ZIPFILE" install.sh | grep -q install.sh
return $?
}
print_modname() {
local len
len=`echo -n $MODNAME | wc -c`
len=$((len + 2))
local pounds=`printf "%${len}s" | tr ' ' '*'`
ui_print "$pounds"
ui_print " $MODNAME "
ui_print "$pounds"
ui_print "*******************"
ui_print " Powered by Magisk "
ui_print "*******************"
}
OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null
if [ -f /data/adb/magisk/util_functions.sh ]; then
. /data/adb/magisk/util_functions.sh
NVBASE=/data/adb
else
require_new_magisk
fi
setup_flashable
mount_partitions
api_level_arch_detect
$BOOTMODE && boot_actions || recovery_actions
unzip -o "$ZIPFILE" module.prop -d $TMPDIR >&2
[ ! -f $TMPDIR/module.prop ] && abort "! Unable to extract zip file!"
$BOOTMODE && MODDIRNAME=modules_update || MODDIRNAME=modules
MODULEROOT=$NVBASE/$MODDIRNAME
MODID=`grep_prop id $TMPDIR/module.prop`
MODPATH=$MODULEROOT/$MODID
MODNAME=`grep_prop name $TMPDIR/module.prop`
rm -rf $MODPATH 2>/dev/null
mkdir -p $MODPATH
if is_legacy_script; then
unzip -oj "$ZIPFILE" module.prop install.sh uninstall.sh 'common/*' -d $TMPDIR >&2
. $TMPDIR/install.sh
print_modname
on_install
[ -f $TMPDIR/uninstall.sh ] && cp -af $TMPDIR/uninstall.sh $MODPATH/uninstall.sh
$SKIPMOUNT && touch $MODPATH/skip_mount
$PROPFILE && cp -af $TMPDIR/system.prop $MODPATH/system.prop
cp -af $TMPDIR/module.prop $MODPATH/module.prop
$POSTFSDATA && cp -af $TMPDIR/post-fs-data.sh $MODPATH/post-fs-data.sh
$LATESTARTSERVICE && cp -af $TMPDIR/service.sh $MODPATH/service.sh
ui_print "- Setting permissions"
set_permissions
else
print_modname
unzip -o "$ZIPFILE" customize.sh -d $MODPATH >&2
if ! grep -q '^SKIPUNZIP=1$' $MODPATH/customize.sh 2>/dev/null; then
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" -x 'META-INF/*' -d $MODPATH >&2
set_perm_recursive $MODPATH 0 0 0755 0644
fi
[ -f $MODPATH/customize.sh ] && . $MODPATH/customize.sh
fi
for TARGET in $REPLACE; do
ui_print "- Replace target: $TARGET"
mktouch $MODPATH$TARGET/.replace
done
if $BOOTMODE; then
mktouch $NVBASE/modules/$MODID/update
cp -af $MODPATH/module.prop $NVBASE/modules/$MODID/module.prop
fi
if [ -f $MODPATH/sepolicy.rule -a -e $PERSISTDIR ]; then
ui_print "- Installing custom sepolicy patch"
PERSISTMOD=$PERSISTDIR/magisk/$MODID
mkdir -p $PERSISTMOD
cp -af $MODPATH/sepolicy.rule $PERSISTMOD/sepolicy.rule
fi
rm -rf \
$MODPATH/system/placeholder $MODPATH/customize.sh \
$MODPATH/README.md $MODPATH/.git* 2>/dev/null
cd /
$BOOTMODE || recovery_cleanup
rm -rf $TMPDIR
ui_print "- Done"
exit 0
EOF
#written
echo -e "${BRIGHT_CYAN} > > > update-binary written succesfully${NC}"
sleep 1 
echo " > > > writing updater-script"

#
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
echo -e "${BRIGHT_CYAN}=========================================================================${NC}"
echo -e "${WHITE}         Magisk-Module created at $output_path                                 ${NC}"
echo -e "${BRIGHT_CYAN}======================================================================== ${NC}"
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
