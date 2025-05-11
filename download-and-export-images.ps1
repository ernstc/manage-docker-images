<#
.SYNOPSIS
    Downloads and exports Docker images defined in a JSON file.

.DESCRIPTION
    This script reads a list of Docker images from a JSON configuration file,
    pulls each image from public/private repositories, and exports them as tar files.
    The exported images can later be imported into an offline or private Docker registry.

.PARAMETER jsonFilePath
    Path to the JSON file containing the list of Docker images to process.
    Default is "./docker-images.json" in the current directory.

.PARAMETER outputDir
    Directory where the exported image tar files will be saved.
    Default is "./exported-images" in the current directory.

.EXAMPLE
    .\download-and-export-images.ps1
    # Uses default parameters

.EXAMPLE
    .\download-and-export-images.ps1 -jsonFilePath "C:\config\my-images.json" -outputDir "D:\docker-exports"
    # Uses custom JSON file path and output directory
#>

param (
    [Parameter(Position=0)]
    [string]$jsonFilePath = "./docker-images.json",
    
    [Parameter(Position=1)]
    [string]$outputDir = "./exported-images"
)

# Load the JSON file and parse the image list
if (-Not (Test-Path $jsonFilePath)) {
    Write-Error "File $jsonFilePath not found."
    exit 1
}

Write-Host "Reading Docker image list from $jsonFilePath..." -ForegroundColor Cyan
$jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
$images = $jsonContent.images

if (-Not $images) {
    Write-Error "No images found in $jsonFilePath."
    exit 1
}

Write-Host "Found $($images.Count) Docker images to process" -ForegroundColor Cyan

# Create an output directory for the exported images
if (-Not (Test-Path $outputDir)) {
    Write-Host "Creating output directory: $outputDir" -ForegroundColor DarkCyan
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

Write-Host "Images will be exported to: $outputDir" -ForegroundColor Cyan
Write-Host "---------------------------------------------" -ForegroundColor Cyan

# Loop through each image, pull it, and save it as a tar file
foreach ($image in $images) {
    Write-Host "Processing image: $image" -ForegroundColor Green

    # Pull the Docker image
    Write-Host "  Pulling Docker image..." -ForegroundColor DarkCyan
    docker pull $image
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  Failed to pull image: $image"
        continue
    }

    # Calculate the image file name
    # Handling Docker image path conventions for filesystem compatibility
    Write-Host "  Converting image name for filesystem storage..." -ForegroundColor DarkCyan
    $imageName = $image
    $slashCount = ($image -split "/").Count - 1
    
    # Handle registry path components with special encoding
    if ($slashCount -gt 1) {
        $imageName = $imageName -replace "^([^/]*)/", '${1}____'
    }
    
    # Replace remaining path separators and tag separator with filesystem-safe characters
    $imageName = $imageName -replace "/", "__" -replace ":", "@"
    
    # Generate the tar file path
    $outputFile = Join-Path -Path $outputDir -ChildPath "$imageName.tar"
    Write-Host "  Original image: $image" -ForegroundColor Yellow
    Write-Host "  Output file: $imageName.tar" -ForegroundColor Yellow
    
    # Save the Docker image to a tar file
    Write-Host "  Exporting image to tar file..." -ForegroundColor DarkCyan
    docker save $image -o $outputFile
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  Failed to save image: $image"
        continue
    }

    Write-Host "  Image exported successfully" -ForegroundColor Green
    Write-Host
}

Write-Host "---------------------------------------------" -ForegroundColor Cyan
Write-Host "All images processed successfully!" -ForegroundColor Green
Write-Host "Exported $($images.Count) Docker images to $outputDir" -ForegroundColor Cyan
