use anyhow::{Context, Result, bail};
use clap::{Parser, ValueEnum};
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;
use zip::CompressionMethod;
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

fn get_ffmpeg_path() -> String {
    std::env::var("FFMPEG_PATH").unwrap_or_else(|_| "ffmpeg".to_string())
}

fn get_ffprobe_path() -> String {
    std::env::var("FFPROBE_PATH").unwrap_or_else(|_| "ffprobe".to_string())
}

fn get_video_properties(video_path: &Path) -> Result<VideoProperties> {
    let ffprobe = get_ffprobe_path();

    // Get width
    let width_output = Command::new(&ffprobe)
        .args([
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

    // Get height
    let height_output = Command::new(&ffprobe)
        .args([
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

    // Get frame rate
    let fps_output = Command::new(&ffprobe)
        .args([
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

    // Get duration
    let duration_output = Command::new(&ffprobe)
        .args([
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

    // Check for audio
    let audio_output = Command::new(&ffprobe)
        .args([
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
) -> Result<()> {
    let desc_path = result_dir.join("desc.txt");
    let mut file = File::create(desc_path)?;

    writeln!(file, "{} {} {}", width, height, fps)?;

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

            // Add all files in this part directory
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

    // validate background color if provided
    let background = if let Some(ref bg) = cli.background {
        Some(validate_color(bg)?)
    } else {
        None
    };

    // get video properties
    println!("Analyzing video...");
    let props = get_video_properties(&cli.input)?;

    println!("Video properties:");
    println!("  Resolution: {}x{}", props.width, props.height);
    println!("  FPS: {}", props.fps);
    println!("  Duration: {:.2}s", props.duration);
    println!("  Has audio: {}", props.has_audio);

    // determine output resolution and fps
    let width = cli.width.unwrap_or(props.width);
    let height = cli.height.unwrap_or(props.height);
    let fps = cli.fps.unwrap_or(props.fps);

    println!("\nOutput configuration:");
    println!("  Resolution: {}x{}", width, height);
    println!("  FPS: {}", fps);
    println!("  Loop mode: {:?}", cli.loop_mode);
    if let Some(ref bg) = background {
        println!("  Background: {}", bg);
    }

    // check audio requirements
    if cli.with_audio && !props.has_audio {
        eprintln!("Warning: Audio requested but video has no audio stream");
    }

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
    if cli.with_audio && props.has_audio {
        fs::create_dir_all(&audio_dir)?;
        extract_audio_blocks(&cli.input, &audio_dir, fps, props.duration)?;
    }

    // organize frames into parts
    let num_parts = organize_frames_into_parts(&frames_dir, &result_dir, cli.max_frames)?;
    println!("Created {} parts", num_parts + 1);

    // add audio to parts if requested
    if cli.with_audio && props.has_audio {
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
    )?;

    // create bootanimation.zip
    create_bootanimation_zip(&result_dir, &cli.output)?;

    println!(
        "Successfully created bootanimation: {}",
        cli.output.display()
    );

    Ok(())
}
