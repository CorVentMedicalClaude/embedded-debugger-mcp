# build.ps1 - Build the project using the local toolchain
#
# Usage:
#   .\scripts\build.ps1              # cargo build --release
#   .\scripts\build.ps1 test         # cargo test
#   .\scripts\build.ps1 clippy       # cargo clippy
#   .\scripts\build.ps1 <any args>   # cargo <any args>

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\env.ps1"

$cargoExe = "$env:CARGO_HOME\bin\cargo.exe"
if (-not (Test-Path $cargoExe)) {
    Write-Error "Cargo not found. Run .\scripts\setup.ps1 first."
    exit 1
}

if ($args.Count -eq 0) {
    Write-Host "Running: cargo build --release" -ForegroundColor Cyan
    & $cargoExe build --release
} else {
    Write-Host "Running: cargo $args" -ForegroundColor Cyan
    & $cargoExe @args
}

exit $LASTEXITCODE
