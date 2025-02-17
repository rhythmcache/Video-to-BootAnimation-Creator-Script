#include <iostream>
#include <string>
#include <filesystem>
#include <cstdlib>
#include <fstream>
#include <array>
#include <sstream>
#include <vector>
#include <cstring>
#include <sys/stat.h>
#include <unistd.h>

namespace fs = std::filesystem;

struct Config {
    std::string input_video;
    std::string output_path;
    std::string resolution;
    int fps = 0;
    bool quiet = false;
    bool is_oos = false;
    std::string ffmpeg_path = "ffmpeg";
    std::string zip_path = "zip";
    int offset_x = 0;
    int offset_y = 0;
    int width = 0;
    int height = 0;
    std::string frame_format = "jpg";  // Default frame format
};

bool checkCommand(const std::string& cmd) {
    std::string check_cmd = "command -v " + cmd + " >/dev/null 2>&1";
    return system(check_cmd.c_str()) == 0;
}

bool isWritable(const std::string& path) {
    return access(path.c_str(), W_OK) == 0;
}

std::string getTmpDir(const Config& config) {
    std::string current_dir = fs::current_path().string();
    if (isWritable(current_dir)) {
        return current_dir + "/bootanim";
    }
    
    fs::path output_path = config.output_path;
    std::string parent_path = output_path.parent_path().string();
    if (!parent_path.empty() && isWritable(parent_path)) {
        return parent_path + "/bootanim";
    }
    
    throw std::runtime_error("No writable directory found for temporary files");
}

void parseResolution(Config& config) {
    size_t pos = config.resolution.find('x');
    if (pos == std::string::npos) {
        throw std::runtime_error("Invalid resolution format. Use widthxheight (e.g., 1080x2400)");
    }
    
    config.width = std::stoi(config.resolution.substr(0, pos));
    config.height = std::stoi(config.resolution.substr(pos + 1));
}

void validateConfig(Config& config) {
    if (config.input_video.empty()) {
        throw std::runtime_error("Input video path is required (-i)");
    }
    if (!fs::exists(config.input_video)) {
        throw std::runtime_error("Input video file does not exist");
    }
    
    if (config.output_path.empty()) {
        config.output_path = "bootanimation.zip";
    } else if (fs::path(config.output_path).extension().empty()) {
        config.output_path += "/bootanimation.zip";
    }
    
    if (config.resolution.empty()) {
        throw std::runtime_error("Resolution is required (-r)");
    }
    parseResolution(config);
    
    if (config.fps <= 0) {
        throw std::runtime_error("FPS must be positive (-f)");
    }
    
    // Validate frame format
    if (config.frame_format != "jpg" && config.frame_format != "png") {
        throw std::runtime_error("Frame format must be either 'jpg' or 'png'");
    }
    
    // Check for ffmpeg and zip availability
    if (!fs::exists(config.ffmpeg_path) && !checkCommand("ffmpeg")) {
        throw std::runtime_error("ffmpeg not found in PATH and custom path not valid");
    }
    if (!fs::exists(config.zip_path) && !checkCommand("zip")) {
        throw std::runtime_error("zip not found in PATH and custom path not valid");
    }
}

void createBootanimation(const Config& config) {
    std::string tmp_dir = getTmpDir(config);
    std::string frames_dir = tmp_dir + "/frames";
    std::string result_dir = tmp_dir + "/result";
    
    // Create directories
    fs::create_directories(frames_dir);
    fs::create_directories(result_dir);
    
    // Generate frames using ffmpeg
    // Add quality settings based on format
    std::string format_options;
    if (config.frame_format == "jpg") {
        format_options = " -qscale:v 2"; // High quality JPEG
    } else if (config.frame_format == "png") {
        format_options = " -compression_level 3"; // Balanced PNG compression
    }
    
    std::string ffmpeg_cmd = config.ffmpeg_path + " -i \"" + config.input_video + 
                            "\" -vf scale=" + std::to_string(config.width) + ":" + 
                            std::to_string(config.height) + format_options +
                            " \"" + frames_dir + "/%06d." + config.frame_format + "\"";
    if (config.quiet) {
    ffmpeg_cmd += " > /dev/null 2>&1";
    }

    if (system(ffmpeg_cmd.c_str()) != 0) {
        throw std::runtime_error("Failed to generate frames using ffmpeg");
    }
    
    // Create desc.txt
    std::ofstream desc_file(result_dir + "/desc.txt");
    if (!desc_file) {
        throw std::runtime_error("Failed to create desc.txt");
    }
    
    if (config.is_oos) {
        desc_file << "g " << config.width << " " << config.height << " " 
                 << config.offset_x << " " << config.offset_y << " " << config.fps << "\n";
    } else {
        desc_file << config.width << " " << config.height << " " << config.fps << "\n";
    }
    
    // Process frames
    const int max_frames = 400;
    int part_index = 0;
    int frame_index = 0;
    
    fs::create_directory(result_dir + "/part0");
    for (const auto& entry : fs::directory_iterator(frames_dir)) {
        std::string dest_dir = result_dir + "/part" + std::to_string(part_index);
        fs::rename(entry.path(), dest_dir + "/" + entry.path().filename().string());
        
        frame_index++;
        if (frame_index >= max_frames) {
            frame_index = 0;
            part_index++;
            fs::create_directory(result_dir + "/part" + std::to_string(part_index));
        }
    }
    
    // Write part information to desc.txt
    for (int i = 0; i <= part_index; i++) {
        desc_file << "c 1 0 part" << i << "\n";
    }
    desc_file.close();
    
    // Create zip file
    std::string zip_cmd = "cd \"" + result_dir + "\" && " + config.zip_path + 
                         " -r -0 \"" + fs::absolute(config.output_path).string() + "\" .";
     if (config.quiet) {
    zip_cmd += " > /dev/null 2>&1";
    }                      
     if (system(zip_cmd.c_str()) != 0) {
        throw std::runtime_error("Failed to create zip file");
    }
    
    // Cleanup
    fs::remove_all(tmp_dir);
}

void printUsage() {
    std::cout << "Usage: cbootanimation -i <video> -o <output> -r <resolution> -f <fps> [-oos] [--offset <x> <y>] [--ffmpeg <path>] [--zip <path>] [--frames <format>]\n"
              << "Options:\n"
              << "  -i <path>           Input video path\n"
              << "  -o <path>           Output bootanimation.zip path\n"
              << "  -r <width>x<height> Resolution (e.g., 1080x2400)\n"
              << "  -f <fps>            Frames per second\n"
              << "  -oos                Create in Oxygen OS format\n"
              << "  --offset <x> <y>    Set offset (only with -oos)\n"
              << "  --ffmpeg <path>     Custom ffmpeg binary path\n"
              << "  --zip <path>        Custom zip binary path\n"
              << "  --frames <format>   Frame format (jpg or png, default: jpg)\n"
              << "  -q                    quiet the output";
}

int main(int argc, char* argv[]) {
    Config config;
    
    try {
        for (int i = 1; i < argc; i++) {
            std::string arg = argv[i];
            if (arg == "-i" && i + 1 < argc) {
                config.input_video = argv[++i];
            } else if (arg == "-o" && i + 1 < argc) {
                config.output_path = argv[++i];
            } else if (arg == "-r" && i + 1 < argc) {
                config.resolution = argv[++i];
            } else if (arg == "-f" && i + 1 < argc) {
                config.fps = std::stoi(argv[++i]);
            } else if (arg == "-oos") {
                config.is_oos = true;
            } else if (arg == "--offset" && i + 2 < argc) {
                config.offset_x = std::stoi(argv[++i]);
                config.offset_y = std::stoi(argv[++i]);
            } else if (arg == "--ffmpeg" && i + 1 < argc) {
                config.ffmpeg_path = argv[++i];
            } else if (arg == "--zip" && i + 1 < argc) {
                config.zip_path = argv[++i];
            } else if (arg == "--frames" && i + 1 < argc) {
                config.frame_format = argv[++i];
            } else if (arg == "-q" || arg == "--quiet") {
                config.quiet = true;    
            } else if (arg == "--help" || arg == "-h") {
                printUsage();
                return 0;
            }
        }
        
        validateConfig(config);
        createBootanimation(config);
        std::cout << "Bootanimation created successfully at: " << config.output_path << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        printUsage();
        return 1;
    }
    
    return 0;
}
