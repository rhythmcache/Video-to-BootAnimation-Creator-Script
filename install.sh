#!/data/data/com.termux/files/usr/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored text
print_color() {
    local color=$1
    local text=$2
    echo -e "${color}${text}${NC}"
}

# Check if running in Termux
if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
    print_color "$RED" "⚠️ This script must be run in Termux. Exiting."
    exit 1
fi

print_color "$GREEN" "✓ Running in Termux. Proceeding..."

if [ -r /storage/emulated/0/ ] && [ -w /storage/emulated/0/ ]; then
            echo -e "${GREEN}Internal Storage Is Accessible..${NC}"
        else
            echo "Internal Storage is not fully accessible. Setting up storage..."
            termux-setup-storage
        fi

# Function to install a package
install_package() {
    if ! command -v "$1" &> /dev/null; then
        print_color "$CYAN" "📦 Installing $1..."
        pkg install -y "$1"
    else
        print_color "$GREEN" "✓ $1 is already installed."
    fi
}

# Install ffmpeg (required)
install_package ffmpeg
install_package zip
install_package unzip

# Ask user about Python installation
print_color "$YELLOW" "📝 Note: Python is only needed if you want to use YouTube to video converter."
read -p "$(echo -e "${BLUE}Do you want to install Python? (y/n): ${NC}")" install_python

if [[ $install_python =~ ^[Yy]$ ]]; then
    install_package python
    install_package openssl-tool
    
    print_color "$CYAN" "📦 Installing yt-dlp..."
    pip install yt-dlp
    print_color "$GREEN" "✓ yt-dlp installed successfully!"
else
    print_color "$YELLOW" "⚠️ Skipping Python and related packages installation."
fi

# Download and rename files
REPO_URL="https://raw.githubusercontent.com/rhythmcache/Video-to-BootAnimation-Creator-Script/main"
FILES=("cbootanim.sh:vid2boot" "boot2mp4.sh:boot2vid")
BIN_DIR="$PREFIX/bin"

for FILE_PAIR in "${FILES[@]}"; do
    OLD_NAME="${FILE_PAIR%%:*}"
    NEW_NAME="${FILE_PAIR#*:}"
    
    print_color "$CYAN" "📥 Downloading $OLD_NAME..."
    curl -fsSL "$REPO_URL/$OLD_NAME" -o "$BIN_DIR/$NEW_NAME"
    chmod +x "$BIN_DIR/$NEW_NAME"
    print_color "$GREEN" "✓ Installed as $NEW_NAME"
done

print_color "$GREEN" "✨ All done!"
print_color "$CYAN" "You can now use 'vid2boot' and 'boot2vid' to start the tool."
