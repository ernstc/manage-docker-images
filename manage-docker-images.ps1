<#
.SYNOPSIS
    Downloads, exports, and imports Docker images to a local registry.

.DESCRIPTION
    This script combines the functionality of download-and-export-images.ps1 and import-images.ps1.
    It can download Docker images from a JSON file, export them to tar files, 
    and then import them into a local container registry.

.PARAMETER JsonFilePath
    Path to the JSON file containing the list of Docker images to process.
    Default is "./docker-images.json".

.PARAMETER ExportedImagesDir
    Path to the directory for storing the exported Docker images.
    Default is "./exported-images".

.PARAMETER RegistryURL
    URL of the target container registry for importing images.
    Default is "http://localhost:6150".

.PARAMETER SkipDownload
    Skip the download and export phase, only perform image import.

.PARAMETER SkipImport
    Skip the import phase, only perform download and export.

.EXAMPLE
    .\manage-docker-images.ps1 
    # Executes both download/export and import phases with default parameters

.EXAMPLE
    .\manage-docker-images.ps1 -JsonFilePath "C:\my-images.json" -ExportedImagesDir "C:\my-images" -RegistryURL "http://registry.local:5000"
    # Uses custom paths and registry URL

.EXAMPLE
    .\manage-docker-images.ps1 -SkipDownload
    # Only imports already exported images

.EXAMPLE
    .\manage-docker-images.ps1 -SkipImport
    # Only downloads and exports images, skips import
#>

param (
    [string]$JsonFilePath = "./docker-images.json",
    [string]$ExportedImagesDir = "./exported-images",
    [string]$RegistryURL = "http://localhost:6150",
    [switch]$SkipDownload,
    [switch]$SkipImport
)

# Function to display section headers
function Write-SectionHeader {
    param([string]$Title)
    Write-Host "`n---------------------------------------------" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "---------------------------------------------" -ForegroundColor Cyan
}

# Step 1: Download and export images
if (-not $SkipDownload) {
    Write-SectionHeader "PHASE 1: DOWNLOADING AND EXPORTING IMAGES"  

    # Invoke the download-and-export-images.ps1 script
    $scriptPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "download-and-export-images.ps1"

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Error "Script download-and-export-images.ps1 not found at $scriptPath"
        exit 1
    }

    & $scriptPath -jsonFilePath $JsonFilePath -outputDir $ExportedImagesDir

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

# Step 2: Import images to registry
if (-not $SkipImport) {
    Write-SectionHeader "PHASE 2: IMPORTING IMAGES TO REGISTRY"
    
    # Invoke the import-images.ps1 script
    $scriptPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "import-images.ps1"

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Error "Script import-images.ps1 not found at $scriptPath"
        exit 1
    }

    & $scriptPath -ExportedImagesDir $ExportedImagesDir -RegistryURL $RegistryURL
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($SkipDownload -and $SkipImport) {
    Write-Warning "Both download and import phases were skipped. No action taken."
}

Write-Host "`nScript execution completed." -ForegroundColor Cyan
