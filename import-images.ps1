<#
.SYNOPSIS
    Imports exported Docker images into a local container registry.

.DESCRIPTION
    This script processes Docker image files from a specified directory,
    loads them into Docker, tags them for the target registry, and pushes them.
    It parses filenames to extract image names and tags based on specified conventions.

.PARAMETER ExportedImagesDir
    Path to the directory containing the exported Docker images.
    Default is "exported-images" in the current directory.

.PARAMETER RegistryURL
    URL of the target container registry.
    Default is "http://localhost:6150".

.EXAMPLE
    .\import-images.ps1 
    # Uses default parameters

.EXAMPLE
    .\import-images.ps1 -ExportedImagesDir "C:\my-images" -RegistryURL "http://registry.local:5000"
    # Uses custom directory and registry URL
#>

param (
    [Parameter(Position=0)]
    [string]$ExportedImagesDir = "exported-images",
    
    [Parameter(Position=1)]
    [string]$RegistryURL = "http://localhost:6150"
)

# Extract hostname without protocol and port for Docker tagging
$registryHost = $RegistryURL -replace "https?://", ""

# Create directory if it doesn't exist
if (-not (Test-Path -Path $ExportedImagesDir)) {
    Write-Error "Directory $ExportedImagesDir does not exist!"
    exit 1
}

# Get all .tar files in the specified directory
$imageFiles = Get-ChildItem -Path $ExportedImagesDir -Filter "*.tar"

if ($imageFiles.Count -eq 0) {
    Write-Warning "No .tar files found in $ExportedImagesDir"
    exit 0
}

Write-Host "Found $($imageFiles.Count) Docker image files to process" -ForegroundColor Cyan
Write-Host "Target registry: $RegistryURL" -ForegroundColor Cyan
Write-Host "---------------------------------------------" -ForegroundColor Cyan

foreach ($file in $imageFiles) {
    Write-Host "Processing file: $($file.Name)" -ForegroundColor Green
    
    # Parse the filename to extract image name and tag
    $filenameWithoutExtension = $file.BaseName
    
    # Split at @ to separate image name and tag
    $parts = $filenameWithoutExtension -split '@'
    $imageName = $parts[0]
    $tag = $parts[1]
    
    if (-not $tag) {
        $tag = "latest"
    }

    # Handle special case where image name contains multiple underscores
    if ($imageName -like "*____*") {
        # Extract the part after the last ____
        $nameParts = $imageName -split '____'
        $imageName = $nameParts[1]
    }
    
    # Replace double underscore with slash for image name
    $imageName = $imageName -replace '__', '/'
    
    Write-Host "  Image Name: $imageName" -ForegroundColor Yellow
    Write-Host "  Tag: $tag" -ForegroundColor Yellow
    
    # Load the image
    Write-Host "  Loading image from $($file.FullName)..." -ForegroundColor DarkCyan
    docker load -i $file.FullName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to load image from $($file.FullName)"
        continue
    }
    
    # Tag the image for the new registry
    $sourceImageName = $filenameWithoutExtension -replace '____', '/' -replace '__', '/' -replace '@', ':'
    $targetImageName = "${registryHost}/${imageName}:${tag}"
    
    Write-Host "  Tagging ""$sourceImageName"" as ""$targetImageName""..." -ForegroundColor DarkCyan

    docker tag $sourceImageName $targetImageName | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to tag image $sourceImageName as $targetImageName"
        continue
    }
    
    # Push to the new registry
    Write-Host "  Pushing to registry..." -ForegroundColor DarkCyan
    docker push $targetImageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push image $targetImageName to registry"
        continue
    }

    # Remove the target image from local Docker
    Write-Host "  Removing local image $targetImageName..." -ForegroundColor DarkCyan
    docker rmi $targetImageName | Out-Null

    # Remove the source image from local Docker if not in use
    $sourceImageInUse = docker ps -a --filter "ancestor=$sourceImageName" --format "{{.ID}}"
    
    if ($sourceImageInUse) {
        Write-Host "  Source image $sourceImageName is in use, not removing." -ForegroundColor Yellow
    } else {
        Write-Host "  Source image $sourceImageName is not in use, removing..." -ForegroundColor DarkCyan
        docker rmi $sourceImageName | Out-Null
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to remove image $sourceImageName"
        continue
    }
    
    Write-Host "  Successfully processed $($file.Name)" -ForegroundColor Green
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
}

Write-Host "Image import completed!" -ForegroundColor Cyan
