use anyhow::{Context, Result, bail};
use clap::{Parser, ValueEnum};
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;
use zip::{CompressionMethod, ZipArchive};
use zip::write::FileOptions;

#[derive(Parser)]
#[command(name = "vid2boot")]
#[command(about = "Convert videos to Android bootanimation", long_about = None)]
struct Cli {
    /// Input video file path
    #[arg(short, long)]
    input: PathBuf,

    /// Output bootanimation.zip path
    #[arg(short, long)]
    output: PathBuf,

    /// Read configuration from existing bootanimation.zip
    #[arg(short, long)]
    config_from: Option<PathBuf>,

    /// Output width (optional, uses video width if not specified)
    #[arg(short = 'W', long)]
    width: Option<u32>,

    /// Output height (optional, uses video height if not specified)
    #[arg(short = 'H', long)]
    height: Option<u32>,

    /// Frame rate (optional, uses video fps if not specified)
    #[arg(short, long)]
    fps: Option<u32>,

    /// Animation loop behavior
    #[arg(short, long, value_enum, default_value = "stop-on-boot")]
    loop_mode: LoopMode,

    /// Background color in hex format (e.g., #FFFFFF or FFFFFF)
    #[arg(short, long)]
    background: Option<String>,

    /// Include audio (creates audio.wav in each part)
    #[arg(long)]
    with_audio: bool,

    /// Maximum frames per part (default: 400)
    #[arg(long, default_value = "400")]
    max_frames: u32,

    /// Image format for frames
    #[arg(long, value_enum, default_value = "jpg")]
    format: ImageFormat,
}

#[derive(Debug, Copy, Clone, PartialEq, Eq, ValueEnum)]
enum LoopMode {
    /// Stop animation when boot completes (p flag)
    StopOnBoot,
    /// Play full length regardless of boot (c 1 flag)
    PlayFull,
    /// Loop infinitely until boot (c 0 flag)
    LoopInfinite,
}

#[derive(Copy, Clone, PartialEq, Eq, ValueEnum)]
enum ImageFormat {
    Jpg,
    Png,
}

struct VideoProperties {
    width: u32,
    height: u32,
    fps: u32,
    duration: f64,
    has_audio: bool,
}

struct BootAnimConfig {
    width: u32,
    height: u32,
    fps: u32,
    is_global_format: bool,
    offset_x: u32,
    offset_y: u32,
}

fn get_ffmpeg_path() -> String {
    std::env::var("FFMPEG_PATH").unwrap_or_else(|_| "ffmpeg".to_string())
}

fn get_ffprobe_path() -> String {
    std::env::var("FFPROBE_PATH").unwrap_or_else(|_| "ffprobe".to_string())
}

fn get_video_properties(video_path: &Path) -> Result<VideoProperties> {
    let ffprobe = get_ffprobe_path();

    // get width
    let width_output = Command::new(&ffprobe)
        .args([
            "-hide_banner",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=width",
            "-of",
            "csv=p=0",
        ])
        .arg(video_path)
        .output()
        .context("Failed to get video width")?;

    let width: u32 = String::from_utf8_lossy(&width_output.stdout)
        .trim()
        .parse()
        .context("Failed to parse width")?;

    // get height
    let height_output = Command::new(&ffprobe)
        .args([
            "-hide_banner",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=height",
            "-of",
            "csv=p=0",
        ])
        .arg(video_path)
        .output()
        .context("Failed to get video height")?;

    let height: u32 = String::from_utf8_lossy(&height_output.stdout)
        .trim()
        .parse()
        .context("Failed to parse height")?;

    // get frame rate
    let fps_output = Command::new(&ffprobe)
        .args([
            "-hide_banner",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=r_frame_rate",
            "-of",
            "csv=p=0",
        ])
        .arg(video_path)
        .output()
        .context("Failed to get frame rate")?;

    let fps_str = String::from_utf8_lossy(&fps_output.stdout)
        .trim()
        .to_string();
    let fps = if fps_str.contains('/') {
        let parts: Vec<&str> = fps_str.split('/').collect();
        let numerator: f64 = parts[0].parse().context("Failed to parse fps numerator")?;
        let denominator: f64 = parts[1]
            .parse()
            .context("Failed to parse fps denominator")?;
        (numerator / denominator).round() as u32
    } else {
        fps_str.parse().context("Failed to parse fps")?
    };

    // get duration
    let duration_output = Command::new(&ffprobe)
        .args([
            "-hide_banner",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "csv=p=0",
        ])
        .arg(video_path)
        .output()
        .context("Failed to get video duration")?;

    let duration: f64 = String::from_utf8_lossy(&duration_output.stdout)
        .trim()
        .parse()
        .context("Failed to parse duration")?;

    // check for audio
    let audio_output = Command::new(&ffprobe)
        .args([
            "-hide_banner",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_type",
            "-select_streams",
            "a",
            "-of",
            "csv=p=0",
        ])
        .arg(video_path)
        .output()
        .context("Failed to check for audio")?;

    let has_audio = !String::from_utf8_lossy(&audio_output.stdout)
        .trim()
        .is_empty();

    Ok(VideoProperties {
        width,
        height,
        fps,
        duration,
        has_audio,
    })
}

fn read_config_from_bootanimation(zip_path: &Path) -> Result<BootAnimConfig> {
    println!("Reading configuration from {}...", zip_path.display());
    
    let temp_dir = TempDir::new()?;
    let extract_dir = temp_dir.path();
    
    // extract the zip
    let file = File::open(zip_path).context("Failed to open bootanimation.zip")?;
    let mut archive = ZipArchive::new(file)?;
    
    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        let outpath = extract_dir.join(file.mangled_name());
        
        if file.name().ends_with('/') {
            fs::create_dir_all(&outpath)?;
        } else {
            if let Some(p) = outpath.parent() {
                fs::create_dir_all(p)?;
            }
            let mut outfile = File::create(&outpath)?;
            std::io::copy(&mut file, &mut outfile)?;
        }
    }
    
    // parse desc.txt
    let desc_path = extract_dir.join("desc.txt");
    if !desc_path.exists() {
        bail!("desc.txt not found in bootanimation.zip");
    }
    
    let content = fs::read_to_string(&desc_path)?;
    
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        
        if parts.is_empty() {
            continue;
        }
        
        // parse first line (dimensions and fps)
        if parts[0] == "g" && parts.len() >= 6 {
            // global format: g width height offsetx offsety fps
            let width = parts[1].parse().context("Failed to parse width")?;
            let height = parts[2].parse().context("Failed to parse height")?;
            let offset_x = parts[3].parse().context("Failed to parse offset_x")?;
            let offset_y = parts[4].parse().context("Failed to parse offset_y")?;
            let fps = parts[5].parse().context("Failed to parse fps")?;
            
            println!("Loaded configuration (global format):");
            println!("  Resolution: {}x{}", width, height);
            println!("  Offsets: x={}, y={}", offset_x, offset_y);
            println!("  FPS: {}", fps);
            
            return Ok(BootAnimConfig {
                width,
                height,
                fps,
                is_global_format: true,
                offset_x,
                offset_y,
            });
        } else if parts.len() >= 3 {
            // original format: width height fps
            let width = parts[0].parse().context("Failed to parse width")?;
            let height = parts[1].parse().context("Failed to parse height")?;
            let fps = parts[2].parse().context("Failed to parse fps")?;
            
            println!("Loaded configuration (standard format):");
            println!("  Resolution: {}x{}", width, height);
            println!("  FPS: {}", fps);
            
            return Ok(BootAnimConfig {
                width,
                height,
                fps,
                is_global_format: false,
                offset_x: 0,
                offset_y: 0,
            });
        }
    }
    
    bail!("Unable to parse desc.txt")
}

fn extract_frames(
    video_path: &Path,
    output_dir: &Path,
    width: u32,
    height: u32,
    format: ImageFormat,
) -> Result<()> {
    let ffmpeg = get_ffmpeg_path();
    let ext = match format {
        ImageFormat::Jpg => "jpg",
        ImageFormat::Png => "png",
    };

    let output_pattern = output_dir.join(format!("%06d.{}", ext));

    println!("Extracting frames from video...");
    let status = Command::new(&ffmpeg)
        .args([
            "-hide_banner",
            "-i",
            video_path.to_str().unwrap(),
            "-vf",
            &format!("scale={}:{}", width, height),
        ])
        .arg(output_pattern)
        .status()
        .context("Failed to extract frames")?;

    if !status.success() {
        bail!("FFmpeg failed to extract frames");
    }

    Ok(())
}

fn extract_audio_blocks(
    video_path: &Path,
    output_dir: &Path,
    fps: u32,
    duration: f64,
) -> Result<()> {
    if fps == 0 {
        bail!("Invalid fps: 0");
    }

    let frame_block_duration = 400.0 / fps as f64;
    let mut start_time = 0.0;
    let mut part = 0;

    println!("Extracting audio blocks...");

    let ffmpeg = get_ffmpeg_path();

    while start_time < duration {
        let output_audio = output_dir.join(format!("audio{}.wav", part));

        let status = Command::new(&ffmpeg)
            .args([
                "-hide_banner",
                "-y",
                "-i",
                video_path.to_str().unwrap(),
                "-ss",
                &start_time.to_string(),
                "-t",
                &frame_block_duration.to_string(),
                "-vn",
                "-acodec",
                "pcm_s16le",
                "-ar",
                "44100",
                "-ac",
                "2",
            ])
            .arg(&output_audio)
            .status()
            .context(format!("Failed to extract audio block {}", part))?;

        if !status.success() {
            eprintln!("Warning: Failed to extract audio for block {}", part);
        }

        start_time += frame_block_duration;
        part += 1;
    }

    Ok(())
}

fn validate_color(color: &str) -> Result<String> {
    let color = color.trim_start_matches('#');

    if color.len() != 6 && color.len() != 3 {
        bail!("Invalid color format. Use #RRGGBB or #RGB");
    }

    if !color.chars().all(|c| c.is_ascii_hexdigit()) {
        bail!("Invalid hex color code");
    }

    Ok(format!("#{}", color))
}

fn organize_frames_into_parts(
    frames_dir: &Path,
    result_dir: &Path,
    max_frames: u32,
) -> Result<u32> {
    println!("Organizing frames into parts...");

    let mut frames: Vec<PathBuf> = fs::read_dir(frames_dir)?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| path.is_file())
        .collect();

    frames.sort();

    if frames.is_empty() {
        bail!("No frames found to process");
    }

    let mut part_index = 0;
    let mut frame_index = 0;
    let mut part_dir = result_dir.join(format!("part{}", part_index));
    fs::create_dir_all(&part_dir)?;

    for frame in frames {
        let dest = part_dir.join(frame.file_name().unwrap());
        fs::rename(&frame, &dest)?;

        frame_index += 1;

        if frame_index >= max_frames {
            frame_index = 0;
            part_index += 1;
            part_dir = result_dir.join(format!("part{}", part_index));
            fs::create_dir_all(&part_dir)?;
        }
    }

    Ok(part_index)
}

fn add_audio_to_parts(audio_dir: &Path, result_dir: &Path, num_parts: u32) -> Result<()> {
    println!("Adding audio to parts...");

    for part_idx in 0..=num_parts {
        let audio_file = audio_dir.join(format!("audio{}.wav", part_idx));
        let part_dir = result_dir.join(format!("part{}", part_idx));
        let dest_audio = part_dir.join("audio.wav");

        if audio_file.exists() {
            fs::copy(&audio_file, &dest_audio)
                .context(format!("Failed to copy audio for part {}", part_idx))?;
            println!("Added audio to part{}", part_idx);
        } else {
            eprintln!("Warning: Audio file {} not found", audio_file.display());
        }
    }

    Ok(())
}

fn create_desc_file(
    result_dir: &Path,
    width: u32,
    height: u32,
    fps: u32,
    num_parts: u32,
    loop_mode: LoopMode,
    background: Option<&str>,
    use_global_format: bool,
    offset_x: u32,
    offset_y: u32,
) -> Result<()> {
    let desc_path = result_dir.join("desc.txt");
    let mut file = File::create(desc_path)?;

    // write first line based on format type
    if use_global_format {
        writeln!(file, "g {} {} {} {} {}", width, height, offset_x, offset_y, fps)?;
    } else {
        writeln!(file, "{} {} {}", width, height, fps)?;
    }

    for part_idx in 0..=num_parts {
        let line = match loop_mode {
            LoopMode::StopOnBoot => {
                if let Some(bg) = background {
                    format!("p 1 0 part{} {}", part_idx, bg)
                } else {
                    format!("p 1 0 part{}", part_idx)
                }
            }
            LoopMode::PlayFull => {
                if let Some(bg) = background {
                    format!("c 1 0 part{} {}", part_idx, bg)
                } else {
                    format!("c 1 0 part{}", part_idx)
                }
            }
            LoopMode::LoopInfinite => {
                if let Some(bg) = background {
                    format!("c 0 0 part{} {}", part_idx, bg)
                } else {
                    format!("c 0 0 part{}", part_idx)
                }
            }
        };
        writeln!(file, "{}", line)?;
    }

    Ok(())
}

fn create_bootanimation_zip(result_dir: &Path, output_path: &Path) -> Result<()> {
    println!("Creating bootanimation.zip...");

    let file = File::create(output_path).context("Failed to create output zip file")?;
    let mut zip = zip::ZipWriter::new(BufWriter::new(file));

    // use 0 compression
    let options = FileOptions::<()>::default().compression_method(CompressionMethod::Stored);

    // add desc.txt
    let desc_path = result_dir.join("desc.txt");
    zip.start_file("desc.txt", options)?;
    let desc_content = fs::read(&desc_path)?;
    zip.write_all(&desc_content)?;

    // walk through all part directories
    for entry in fs::read_dir(result_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir()
            && path
                .file_name()
                .unwrap()
                .to_str()
                .unwrap()
                .starts_with("part")
        {
            let part_name = path.file_name().unwrap().to_str().unwrap();

            // add all files in this part directory
            for file_entry in fs::read_dir(&path)? {
                let file_entry = file_entry?;
                let file_path = file_entry.path();

                if file_path.is_file() {
                    let file_name = file_path.file_name().unwrap().to_str().unwrap();
                    let zip_path = format!("{}/{}", part_name, file_name);

                    zip.start_file(&zip_path, options)?;
                    let content = fs::read(&file_path)?;
                    zip.write_all(&content)?;
                }
            }
        }
    }

    zip.finish()?;
    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    if !cli.input.exists() {
        bail!("Input video file does not exist: {}", cli.input.display());
    }

    // load configuration from existing bootanimation if specified
    let bootanim_config = if let Some(ref config_path) = cli.config_from {
        if !config_path.exists() {
            bail!("Config bootanimation file does not exist: {}", config_path.display());
        }
        Some(read_config_from_bootanimation(config_path)?)
    } else {
        None
    };

    // validate background color if provided
    let background = if let Some(ref bg) = cli.background {
        Some(validate_color(bg)?)
    } else {
        None
    };

    // determine what information we need from video properties
    let need_width = cli.width.is_none() && bootanim_config.as_ref().map(|c| c.width).is_none();
    let need_height = cli.height.is_none() && bootanim_config.as_ref().map(|c| c.height).is_none();
    let need_fps = cli.fps.is_none() && bootanim_config.as_ref().map(|c| c.fps).is_none();
    let need_audio_check = cli.with_audio;

    // only get video properties if we actually need them
    let props = if need_width || need_height || need_fps || need_audio_check {
        println!("Analyzing video...");
        let p = get_video_properties(&cli.input)?;

        println!("Video properties:");
        println!("  Resolution: {}x{}", p.width, p.height);
        println!("  FPS: {}", p.fps);
        println!("  Duration: {:.2}s", p.duration);
        println!("  Has audio: {}", p.has_audio);

        Some(p)
    } else {
        println!("Skipping video analysis (all parameters provided via config/CLI)");
        None
    };

    // determine output resolution and fps
    // priority-> CLI args > config from bootanimation > video properties
    let width = cli.width
        .or_else(|| bootanim_config.as_ref().map(|c| c.width))
        .or_else(|| props.as_ref().map(|p| p.width))
        .ok_or_else(|| anyhow::anyhow!("Width not specified and could not be determined from video"))?;
    
    let height = cli.height
        .or_else(|| bootanim_config.as_ref().map(|c| c.height))
        .or_else(|| props.as_ref().map(|p| p.height))
        .ok_or_else(|| anyhow::anyhow!("Height not specified and could not be determined from video"))?;
    
    let fps = cli.fps
        .or_else(|| bootanim_config.as_ref().map(|c| c.fps))
        .or_else(|| props.as_ref().map(|p| p.fps))
        .ok_or_else(|| anyhow::anyhow!("FPS not specified and could not be determined from video"))?;
    
    let use_global_format = bootanim_config.as_ref().map(|c| c.is_global_format).unwrap_or(false);
    let offset_x = bootanim_config.as_ref().map(|c| c.offset_x).unwrap_or(0);
    let offset_y = bootanim_config.as_ref().map(|c| c.offset_y).unwrap_or(0);

    println!("\nOutput configuration:");
    println!("  Resolution: {}x{}", width, height);
    println!("  FPS: {}", fps);
    println!("  Loop mode: {:?}", cli.loop_mode);
    if use_global_format {
        println!("  Format: global (with offsets x={}, y={})", offset_x, offset_y);
    }
    if let Some(ref bg) = background {
        println!("  Background: {}", bg);
    }

    // check audio requirements
    if cli.with_audio {
        if let Some(ref p) = props {
            if !p.has_audio {
                eprintln!("Warning: Audio requested but video has no audio stream");
            }
        }
    }

    // Get duration for audio extraction if needed
    let duration = if cli.with_audio {
        props.as_ref().map(|p| p.duration).unwrap_or(0.0)
    } else {
        0.0
    };

    let has_audio = cli.with_audio && props.as_ref().map(|p| p.has_audio).unwrap_or(false);

    // create temporary directory
    let temp_dir = TempDir::new()?;
    let frames_dir = temp_dir.path().join("frames");
    let audio_dir = temp_dir.path().join("audio");
    let result_dir = temp_dir.path().join("result");

    fs::create_dir_all(&frames_dir)?;
    fs::create_dir_all(&result_dir)?;

    // extract frames
    extract_frames(&cli.input, &frames_dir, width, height, cli.format)?;

    // extract audio if requested
    if has_audio {
        fs::create_dir_all(&audio_dir)?;
        extract_audio_blocks(&cli.input, &audio_dir, fps, duration)?;
    }

    // organize frames into parts
    let num_parts = organize_frames_into_parts(&frames_dir, &result_dir, cli.max_frames)?;
    println!("Created {} parts", num_parts + 1);

    // add audio to parts if requested
    if has_audio {
        add_audio_to_parts(&audio_dir, &result_dir, num_parts)?;
    }

    // create desc.txt
    create_desc_file(
        &result_dir,
        width,
        height,
        fps,
        num_parts,
        cli.loop_mode,
        background.as_deref(),
        use_global_format,
        offset_x,
        offset_y,
    )?;

    // create bootanimation.zip
    create_bootanimation_zip(&result_dir, &cli.output)?;

    println!(
        "Successfully created bootanimation: {}",
        cli.output.display()
    );

    Ok(())
}
