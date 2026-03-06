# env.ps1 - Set up local toolchain environment variables
# Dot-source this from other scripts: . "$PSScriptRoot\env.ps1"

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path

$env:RUSTUP_HOME = "$ProjectRoot\tools\rustup"
$env:CARGO_HOME  = "$ProjectRoot\tools\cargo"

# Prepend cargo bin to PATH (avoid duplicates)
$cargoBin = "$env:CARGO_HOME\bin"
if ($env:PATH -notlike "*$cargoBin*") {
    $env:PATH = "$cargoBin;$env:PATH"
}

# Detect C compiler
$script:HasMSVC = $false
$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -property installationPath 2>$null
    if ($vsPath) {
        $script:HasMSVC = $true
        Write-Host "MSVC detected at $vsPath" -ForegroundColor Green
    }
}

if (-not $script:HasMSVC) {
    $mingwBin = "$ProjectRoot\tools\mingw64\bin"
    if (Test-Path "$mingwBin\gcc.exe") {
        if ($env:PATH -notlike "*$mingwBin*") {
            $env:PATH = "$mingwBin;$env:PATH"
        }
        $env:CC = "gcc"
        Write-Host "Using portable MinGW from tools\mingw64" -ForegroundColor Green
    } else {
        Write-Host "WARNING: No C compiler found. Run .\scripts\setup.ps1 first." -ForegroundColor Yellow
    }
}
