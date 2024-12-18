RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_package_manager() {
    if command -v pkg &> /dev/null; then
        echo "termux"
    elif command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

install_dependencies() {
    PACKAGE_MANAGER=$(get_package_manager)

    case $PACKAGE_MANAGER in
        "termux")
            echo -e "${YELLOW}Termux detected. Installing ffmpeg and unzip...${NC}"
            pkg install -y ffmpeg unzip
            ;;
        "apt")
            echo -e "${YELLOW}Debian-based (Ubuntu, etc.) detected. Installing ffmpeg and unzip...${NC}"
            sudo apt update && sudo apt install -y ffmpeg unzip
            ;;
        "dnf")
            echo -e "${YELLOW}Red Hat-based (CentOS, Fedora, etc.) detected. Installing ffmpeg and unzip...${NC}"
            sudo dnf install -y ffmpeg unzip
            ;;
        "pacman")
            echo -e "${YELLOW}Arch-based (Arch, Manjaro, etc.) detected. Installing ffmpeg and unzip...${NC}"
            sudo pacman -S --noconfirm ffmpeg unzip
            ;;
        "apk")
            echo -e "${YELLOW}Alpine Linux detected. Installing ffmpeg and unzip...${NC}"
            sudo apk add ffmpeg unzip
            ;;
        "zypper")
            echo -e "${YELLOW}openSUSE detected. Installing ffmpeg and unzip...${NC}"
            sudo zypper install -y ffmpeg unzip
            ;;
        *)
            echo -e "${RED}Unknown or unsupported package manager. Please install ffmpeg and unzip manually.${NC}"
            exit 1
            ;;
    esac
}

install_dependencies

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
unzip -o "$zip_path" -d "$extract_dir" || { echo -e "${RED}Failed to unzip bootanimation.zip${NC}"; exit 1; }

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
        printf -v new_name "%05d.${base_name##*.}" $((10#$num_part))
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
ffmpeg -y -framerate "$fps" -i "$frames_dir/%05d.png" -s "$resolution" -pix_fmt yuv420p "$output_path" || {
    echo -e "${RED}Failed to generate video.${NC}"
    exit 1
}

echo -e "${GREEN}Video successfully generated at $output_path.${NC}"
