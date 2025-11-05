use clap::Parser;
use std::env;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;
use zip::ZipArchive;

#[derive(Parser)]
#[command(name = "bootanimation-converter")]
#[command(version = "1.0")]
#[command(about = "Converts Android bootanimation.zip to MP4 video", long_about = None)]
struct Cli {
    /// Input bootanimation.zip file
    #[arg(short, long)]
    input: PathBuf,

    /// Output MP4 file
    #[arg(short, long)]
    output: PathBuf,

    /// Include audio from bootanimation if available
    #[arg(long)]
    with_audio: bool,
}

struct Config {
    zip_path: PathBuf,
    output_path: PathBuf,
    with_audio: bool,
}

struct BootAnimDesc {
    width: u32,
    height: u32,
    fps: u32,
}

struct PartInfo {
    path: PathBuf,
    audio_path: Option<PathBuf>,
    frame_count: u32,
}

fn main() {
    let cli = Cli::parse();

    let config = Config {
        zip_path: cli.input,
        output_path: cli.output,
        with_audio: cli.with_audio,
    };

    if let Err(e) = run(config) {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

fn run(config: Config) -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let work_dir = temp_dir.path();

    let extract_dir = work_dir.join("extracted");
    let frames_dir = work_dir.join("frames");

    println!("Extracting bootanimation.zip...");
    extract_zip(&config.zip_path, &extract_dir)?;

    let desc = parse_desc(&extract_dir.join("desc.txt"))?;
    let resolution = format!("{}x{}", desc.width, desc.height);
    println!("Resolution: {}, FPS: {}", resolution, desc.fps);

    fs::create_dir_all(&frames_dir)?;

    // collect all part directories
    let part_infos = collect_parts(&extract_dir)?;

    if part_infos.is_empty() {
        return Err("No valid parts found in bootanimation".into());
    }

    // detect frame extension
    let extension = detect_frame_extension(&part_infos[0].path)?;
    println!("Detected frame format: {}", extension.to_uppercase());

    // copy ALL frames into one directory with sequential numbering
    println!("Collecting and renaming all frames...");
    let mut frame_counter = 1;
    let mut updated_parts = Vec::new();

    for part in part_infos {
        let start_frame = frame_counter;
        frame_counter = copy_frames_sequential(&part.path, &frames_dir, &extension, frame_counter)?;
        let end_frame = frame_counter - 1;
        let frame_count = end_frame - start_frame + 1;

        println!("  {} frames from {}", frame_count, part.path.display());

        updated_parts.push(PartInfo {
            path: part.path.clone(),
            audio_path: part.audio_path.clone(),
            frame_count,
        });
    }

    let total_frames = frame_counter - 1;
    println!("Total frames collected: {}", total_frames);

    // check if we have audio
    let has_audio = config.with_audio && updated_parts.iter().any(|p| p.audio_path.is_some());

    if has_audio {
        println!("Processing with audio...");
        process_with_audio(
            &frames_dir,
            &updated_parts,
            &config.output_path,
            &work_dir,
            &resolution,
            desc.fps,
            &extension,
        )?;
    } else {
        if config.with_audio {
            println!("No audio found, processing without audio...");
        } else {
            println!("Generating video without audio...");
        }
        generate_video_no_audio(
            &frames_dir,
            &config.output_path,
            &resolution,
            desc.fps,
            &extension,
        )?;
    }

    println!(
        "Video successfully generated at {}",
        config.output_path.display()
    );

    Ok(())
}

fn extract_zip(zip_path: &Path, extract_dir: &Path) -> Result<(), Box<dyn std::error::Error>> {
    fs::create_dir_all(extract_dir)?;
    let file = fs::File::open(zip_path)?;
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
            let mut outfile = fs::File::create(&outpath)?;
            std::io::copy(&mut file, &mut outfile)?;
        }
    }
    Ok(())
}

fn parse_desc(desc_path: &Path) -> Result<BootAnimDesc, Box<dyn std::error::Error>> {
    let content = fs::read_to_string(desc_path)?;

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        let parts: Vec<&str> = trimmed.split_whitespace().collect();

        if parts.is_empty() {
            continue;
        }

        if parts[0] == "g" && parts.len() >= 6 {
            // global format: g width height offsetx offsety fps
            return Ok(BootAnimDesc {
                width: parts[1].parse()?,
                height: parts[2].parse()?,
                fps: parts[5].parse()?,
            });
        } else if parts.len() >= 3 {
            // original format: width height fps
            return Ok(BootAnimDesc {
                width: parts[0].parse()?,
                height: parts[1].parse()?,
                fps: parts[2].parse()?,
            });
        }
    }

    Err("Unable to parse desc.txt".into())
}

fn collect_parts(extract_dir: &Path) -> Result<Vec<PartInfo>, Box<dyn std::error::Error>> {
    let mut parts = Vec::new();

    if let Ok(entries) = fs::read_dir(extract_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let audio_path = path.join("audio.wav");
                let audio = if audio_path.exists() {
                    Some(audio_path)
                } else {
                    None
                };

                parts.push(PartInfo {
                    path,
                    audio_path: audio,
                    frame_count: 0, // will be updated later
                });
            }
        }
    }

    // sort parts by directory name
    parts.sort_by(|a, b| a.path.file_name().cmp(&b.path.file_name()));

    Ok(parts)
}

fn detect_frame_extension(dir: &Path) -> Result<String, Box<dyn std::error::Error>> {
    let mut png_count = 0;
    let mut jpg_count = 0;

    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                let ext_lower = ext.to_string_lossy().to_lowercase();
                if ext_lower == "png" {
                    png_count += 1;
                } else if ext_lower == "jpg" || ext_lower == "jpeg" {
                    jpg_count += 1;
                }
            }
        }
    }

    if png_count > 0 {
        Ok("png".to_string())
    } else if jpg_count > 0 {
        Ok("jpg".to_string())
    } else {
        Err("No valid frames (PNG or JPG) found".into())
    }
}

fn copy_frames_sequential(
    src_dir: &Path,
    dst_dir: &Path,
    extension: &str,
    start_counter: u32,
) -> Result<u32, Box<dyn std::error::Error>> {
    let mut frames: Vec<PathBuf> = Vec::new();

    if let Ok(entries) = fs::read_dir(src_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if ext.to_string_lossy().to_lowercase() == extension {
                    frames.push(path);
                }
            }
        }
    }

    // sort by extracting the last contiguous numeric sequence from filename
    frames.sort_by(|a, b| {
        let num_a = extract_last_number(a);
        let num_b = extract_last_number(b);
        num_a.cmp(&num_b)
    });

    let mut counter = start_counter;
    for frame in frames.iter() {
        let new_name = format!("{:05}.{}", counter, extension);
        fs::copy(frame, dst_dir.join(new_name))?;
        counter += 1;
    }

    Ok(counter)
}

fn extract_last_number(path: &Path) -> u32 {
    let filename = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");

    // find the last contiguous sequence of digits
    let mut last_num = String::new();
    let mut current_num = String::new();

    for ch in filename.chars() {
        if ch.is_ascii_digit() {
            current_num.push(ch);
        } else {
            if !current_num.is_empty() {
                last_num = current_num.clone();
                current_num.clear();
            }
        }
    }

    // if we ended with digits, that's our number
    if !current_num.is_empty() {
        last_num = current_num;
    }

    // parse the numeric part, default to 0 if no digits found
    last_num.parse().unwrap_or(0)
}

fn process_with_audio(
    frames_dir: &Path,
    parts: &[PartInfo],
    output: &Path,
    work_dir: &Path,
    resolution: &str,
    fps: u32,
    extension: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut part_videos = Vec::new();
    let mut current_frame = 1;

    for (idx, part) in parts.iter().enumerate() {
        if let Some(audio_path) = &part.audio_path {
            println!(
                "Processing part {} with audio ({} frames)",
                idx, part.frame_count
            );

            let start_frame = current_frame;
            let end_frame = current_frame + part.frame_count - 1;

            let part_video = work_dir.join(format!("part{}.mp4", idx));
            generate_video_segment(
                frames_dir,
                audio_path,
                &part_video,
                resolution,
                fps,
                extension,
                start_frame,
                end_frame,
            )?;

            part_videos.push(part_video);
            current_frame = end_frame + 1;
        } else {
            println!(
                "Processing part {} without audio ({} frames)",
                idx, part.frame_count
            );

            let start_frame = current_frame;
            let end_frame = current_frame + part.frame_count - 1;

            let part_video = work_dir.join(format!("part{}.mp4", idx));
            generate_video_segment_no_audio(
                frames_dir,
                &part_video,
                resolution,
                fps,
                extension,
                start_frame,
                end_frame,
            )?;

            part_videos.push(part_video);
            current_frame = end_frame + 1;
        }
    }

    if part_videos.len() > 1 {
        println!("Merging {} video parts...", part_videos.len());
        merge_videos(&part_videos, output, work_dir)?;
    } else if part_videos.len() == 1 {
        fs::copy(&part_videos[0], output)?;
    }

    Ok(())
}

fn generate_video_segment(
    frames_dir: &Path,
    audio_path: &Path,
    output: &Path,
    resolution: &str,
    fps: u32,
    extension: &str,
    start_frame: u32,
    end_frame: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    let ffmpeg = get_ffmpeg_path();
    let pattern = frames_dir.join(format!("%05d.{}", extension));

    let status = Command::new(&ffmpeg)
        .args(&[
            "-hide_banner",
            "-y",
            "-start_number",
            &start_frame.to_string(),
            "-framerate",
            &fps.to_string(),
            "-i",
            pattern.to_str().unwrap(),
            "-i",
            audio_path.to_str().unwrap(),
            "-frames:v",
            &(end_frame - start_frame + 1).to_string(),
            "-shortest",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-s",
            resolution,
            "-c:a",
            "aac",
            output.to_str().unwrap(),
        ])
        .status()?;

    if !status.success() {
        return Err("FFmpeg failed to generate video segment".into());
    }

    Ok(())
}

fn generate_video_segment_no_audio(
    frames_dir: &Path,
    output: &Path,
    resolution: &str,
    fps: u32,
    extension: &str,
    start_frame: u32,
    end_frame: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    let ffmpeg = get_ffmpeg_path();
    let pattern = frames_dir.join(format!("%05d.{}", extension));

    let status = Command::new(&ffmpeg)
        .args(&[
            "-hide_banner",
            "-y",
            "-start_number",
            &start_frame.to_string(),
            "-framerate",
            &fps.to_string(),
            "-i",
            pattern.to_str().unwrap(),
            "-frames:v",
            &(end_frame - start_frame + 1).to_string(),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-s",
            resolution,
            output.to_str().unwrap(),
        ])
        .status()?;

    if !status.success() {
        return Err("FFmpeg failed to generate video segment".into());
    }

    Ok(())
}

fn generate_video_no_audio(
    frames_dir: &Path,
    output: &Path,
    resolution: &str,
    fps: u32,
    extension: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let ffmpeg = get_ffmpeg_path();
    let pattern = frames_dir.join(format!("%05d.{}", extension));

    let status = Command::new(&ffmpeg)
        .args(&[
            "-hide_banner",
            "-y",
            "-framerate",
            &fps.to_string(),
            "-i",
            pattern.to_str().unwrap(),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-s",
            resolution,
            output.to_str().unwrap(),
        ])
        .status()?;

    if !status.success() {
        return Err("FFmpeg failed to generate video".into());
    }

    Ok(())
}

fn merge_videos(
    videos: &[PathBuf],
    output: &Path,
    work_dir: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let concat_file = work_dir.join("concat_list.txt");
    let mut file = fs::File::create(&concat_file)?;

    for video in videos {
        writeln!(file, "file '{}'", video.display())?;
    }
    drop(file);

    let ffmpeg = get_ffmpeg_path();
    let status = Command::new(&ffmpeg)
        .args(&[
            "-hide_banner",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            concat_file.to_str().unwrap(),
            "-c",
            "copy",
            output.to_str().unwrap(),
        ])
        .status()?;

    if !status.success() {
        return Err("FFmpeg failed to merge videos".into());
    }

    Ok(())
}

fn get_ffmpeg_path() -> String {
    env::var("FFMPEG_PATH").unwrap_or_else(|_| "ffmpeg".to_string())
}
