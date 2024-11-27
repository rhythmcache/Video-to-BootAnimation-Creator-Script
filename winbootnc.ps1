# Set color variables
$GREEN = [ConsoleColor]::Green
$NC = [ConsoleColor]::Reset
$RED = [ConsoleColor]::Red

# Check for admin privileges
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script needs to be run as Administrator. Relaunching with elevated privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Display ASCII art in green color
Write-Host " _                 _              _                 _   _             " -ForegroundColor $GREEN
Write-Host "| |__   ___   ___ | |_ __ _ _ __ (_)_ __ ___   __ _| |_(_) ___  _ __  " -ForegroundColor $GREEN
Write-Host "| '_ \ / _ \ / _ \| __/ _\` | '_ \| | '_ \` _ \ / _\` | __| |/ _ \| '_ \ " -ForegroundColor $GREEN
Write-Host "| |_) | (_) | (_) | || (_| | | | | | | | | | | (_| | |_| | (_) | | | |" -ForegroundColor $GREEN
Write-Host "|_.__/ \___/ \___/ \__\__,_|_| |_|_|_| |_| |_|\__,_|\__|_|\___/|_| |_|" -ForegroundColor $GREEN
Write-Host "        ___               _             " -ForegroundColor $GREEN
Write-Host "  / __\ __ ___  __ _| |_ ___  _ __ " -ForegroundColor $GREEN
Write-Host " / / | '__/ _ \/ _\` | __/ _ \| '__|" -ForegroundColor $GREEN
Write-Host "/ /__| | |  __/ (_| | || (_) | |   " -ForegroundColor $GREEN
Write-Host "\____/_|  \___|\__,_|\__\___/|_|   " -ForegroundColor $GREEN
Write-Host ""

# Function to normalize input paths
Function Normalize-Path {
    param ($path)
    # Remove surrounding quotes if present
    if ($path.StartsWith('"') -and $path.EndsWith('"')) {
        $path = $path.Trim('"')
    }
    # Normalize backslashes
    return $path.Replace("\", "\\")
}

# Function to install Chocolatey
Function Install-Choco {
    try {
        Write-Host "Chocolatey not found. Installing Chocolatey..." -ForegroundColor $GREEN
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        if (Get-Command "choco" -ErrorAction SilentlyContinue) {
            Write-Host "Chocolatey installed successfully." -ForegroundColor $GREEN
        } else {
            Write-Host "Failed to install Chocolatey. Please install it manually." -ForegroundColor $RED
            exit 1
        }
    } catch {
        Write-Host "Error installing Chocolatey: $_" -ForegroundColor $RED
        exit 1
    }
}

# Function to install a package
Function Install-Package {
    param($package)
    try {
        if (Get-Command "choco" -ErrorAction SilentlyContinue) {
            choco install $package -y
        } else {
            Write-Host "Chocolatey not found. Attempting to install..." -ForegroundColor $GREEN
            Install-Choco
            choco install $package -y
        }
    } catch {
        Write-Host "Error installing package: $package" -ForegroundColor $RED
        exit 1
    }
}

# Prompt for video parameters with green text
$video = Read-Host "Enter video path (e.g., C:\path\to\video.mp4)"
$video = Normalize-Path $video
if (-not (Test-Path $video)) {
    Write-Host "Error: Video file does not exist."
    exit 1
}

$resolution = Read-Host "Enter output resolution (e.g., 1080x1920)"
$width, $height = $resolution.Split('x')

$fps = Read-Host "Enter frame rate you want to put in bootanimation"
$output_path = Read-Host "Enter output path (e.g., C:\path\to\output.zip)"
$output_path = Normalize-Path $output_path

# Prompt for looping option
$loop_option = Read-Host "Loop animation? (1 for yes, 2 for no)"
if ($loop_option -ne "1" -and $loop_option -ne "2") {
    Write-Host "Error: Invalid option selected. Please select 1 or 2."
    exit 1
}

# Temporary directory setup for processing
$TMP_DIR = "C:\TMPDIR"
Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
New-Item -Path $TMP_DIR -ItemType Directory
New-Item -Path "$TMP_DIR\frames" -ItemType Directory
New-Item -Path "$TMP_DIR\result" -ItemType Directory
$desc_file = "$TMP_DIR\result\desc.txt"

# Generate frames with ffmpeg
ffmpeg -i $video -vf "scale=${width}:${height}" "$TMP_DIR\frames\%06d.jpg"
if ($?) {
    Write-Host "Frames generated successfully." -ForegroundColor $GREEN
} else {
    Write-Host "Error generating frames from video."
    exit 1
}

# Count frames
$frame_count = (Get-ChildItem "$TMP_DIR\frames" | Measure-Object).Count
if ($frame_count -eq 0) {
    Write-Host "No frames generated. Exiting."
    exit 1
}
Write-Host "Processed $frame_count frames." -ForegroundColor $GREEN

# Pack frames into parts if more than 400 frames
$max_frames = 400
$part_index = 0
$frame_index = 0

New-Item -Path "$TMP_DIR\result\part$part_index" -ItemType Directory
Get-ChildItem "$TMP_DIR\frames\*.jpg" | ForEach-Object {
    Move-Item $_.FullName -Destination "$TMP_DIR\result\part$part_index\"
    $frame_index++
    if ($frame_index -ge $max_frames) {
        $frame_index = 0
        $part_index++
        New-Item -Path "$TMP_DIR\result\part$part_index" -ItemType Directory
    }
}
# Create desc.txt with resolution and fps
"$width $height $fps" | Out-File $desc_file -Force

# Create loop content
if ($loop_option -eq "1") {
    $content = 0..$part_index | ForEach-Object {
        "c 0 0 part$_"
    }
} else {
    $content = 0..$part_index | ForEach-Object {
        "p 1 0 part$_"
    }
}
# Append loop content to the file
Add-Content -Path $desc_file -Value $content

# Convert line endings to Unix (LF)
(Get-Content -Path $desc_file -Raw) -replace "`r", "" | Set-Content -Path $desc_file -Force -NoNewline

Write-Host "Creating bootanimation.zip..." -ForegroundColor $GREEN

#
Set-Location -Path "$TMP_DIR\result"

# Create the ZIP file from the current directory's contents
Write-Host "Creating bootanimation.zip ..." -ForegroundColor $GREEN
Start-Process -NoNewWindow -Wait -FilePath "zip" -ArgumentList "-r0", "`"$output_path`"", "." -PassThru

# Check for errors
if ($LASTEXITCODE -eq 0) {
    Write-Host "Bootanimation created at $output_path" -ForegroundColor $GREEN
} else {
    Write-Host "Error: Failed to create the ZIP file." -ForegroundColor $RED
    exit 1
}

# Return to the original directory
Set-Location -Path $PWD


Start-Sleep -Seconds 1
Set-Location -Path "C:\Users\Admin"



# Clean up
Remove-Item -Recurse -Force $TMP_DIR
while ($true) {
    Write-Host "Process completed"
    Start-Sleep -Seconds 1  # Wait for 1 second before printing again
    if ($host.UI.RawUI.KeyAvailable) {
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  # Read the key press (without displaying it)
        break  # Exit the loop when any key is pressed
    }
}


