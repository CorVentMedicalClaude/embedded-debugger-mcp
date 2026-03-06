# setup.ps1 - Install Rust toolchain and C compiler locally into tools/
#
# Usage: .\scripts\setup.ps1
# All tools are installed under the project's tools/ directory.

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\env.ps1"

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ToolsDir = "$ProjectRoot\tools"

# Create tools directory
if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir | Out-Null
}

# ---- Detect C compiler ----
$HasMSVC = $false
$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -property installationPath 2>$null
    if ($vsPath) { $HasMSVC = $true }
}

if ($HasMSVC) {
    $hostTriple = "x86_64-pc-windows-msvc"
    Write-Host "MSVC detected. Rust will use MSVC target." -ForegroundColor Green
} else {
    $hostTriple = "x86_64-pc-windows-gnu"
    Write-Host "No MSVC detected. Will use MinGW (GNU) target." -ForegroundColor Yellow
}

# ---- Install Rust ----
$cargoExe = "$env:CARGO_HOME\bin\cargo.exe"
if (Test-Path $cargoExe) {
    Write-Host "Rust already installed. Updating..." -ForegroundColor Cyan
    & rustup update stable
} else {
    Write-Host "Downloading rustup-init.exe..." -ForegroundColor Cyan
    $rustupInit = "$ToolsDir\rustup-init.exe"
    $rustupUrl = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupInit -UseBasicParsing

    Write-Host "Installing Rust (target: $hostTriple)..." -ForegroundColor Cyan
    & $rustupInit -y --default-toolchain stable --default-host $hostTriple --no-modify-path

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Rust installation failed."
        exit 1
    }

    # Clean up installer
    Remove-Item $rustupInit -Force
}

# Verify Rust
Write-Host ""
Write-Host "Rust installation:" -ForegroundColor Cyan
& "$env:CARGO_HOME\bin\rustc.exe" --version
& "$env:CARGO_HOME\bin\cargo.exe" --version

# ---- Install MinGW if needed ----
if (-not $HasMSVC) {
    $mingwGcc = "$ToolsDir\mingw64\bin\gcc.exe"
    if (Test-Path $mingwGcc) {
        Write-Host "MinGW already installed." -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Downloading portable MinGW-w64 (this may take a few minutes)..." -ForegroundColor Cyan

        # Pinned MinGW-w64 release from winlibs (GCC 14.2.0, UCRT, x86_64)
        $mingwUrl = "https://github.com/brechtsanders/winlibs_mingw/releases/download/14.2.0posix-19.1.1-12.0.0-ucrt-r2/winlibs-x86_64-posix-seh-gcc-14.2.0-mingw-w64ucrt-12.0.0-r2.zip"
        $mingwZip = "$ToolsDir\mingw64.zip"

        Invoke-WebRequest -Uri $mingwUrl -OutFile $mingwZip -UseBasicParsing

        Write-Host "Extracting MinGW-w64..." -ForegroundColor Cyan
        Expand-Archive -Path $mingwZip -DestinationPath $ToolsDir -Force

        # Clean up zip
        Remove-Item $mingwZip -Force

        if (Test-Path $mingwGcc) {
            Write-Host "MinGW installed successfully." -ForegroundColor Green
        } else {
            Write-Error "MinGW extraction failed - gcc.exe not found at expected path."
            exit 1
        }
    }

    # Add MinGW to PATH for this session
    $mingwBin = "$ToolsDir\mingw64\bin"
    if ($env:PATH -notlike "*$mingwBin*") {
        $env:PATH = "$mingwBin;$env:PATH"
    }
    $env:CC = "gcc"

    Write-Host "MinGW GCC:" -ForegroundColor Cyan
    & gcc --version | Select-Object -First 1
}

Write-Host ""
Write-Host "Setup complete! Run .\scripts\build.ps1 to build the project." -ForegroundColor Green
