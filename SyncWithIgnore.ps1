# === CONFIGURATION ===
$LocalProject = "C:\OriginalFolder"
$OneDriveProject = "$env:User\OneDrive - Company\Linkfolder"
$IgnoreFile = Join-Path $LocalProject ".onedriveignore"

# === VALIDATION ===
if (-not (Test-Path $IgnoreFile)) {
    Write-Error ".onedriveignore not found at $IgnoreFile"
    exit 1
}

# Read patterns and separate folder vs file patterns
$rawPatterns = Get-Content $IgnoreFile | Where-Object {
    ($_ -and ($_ -notmatch "^\s*#"))
}

$folderPatterns = @()
$filePatterns = @()

foreach ($pattern in $rawPatterns) {
    $p = $pattern.Trim()
    if ($p.EndsWith("/") -or $p.EndsWith("\")) {
        $folderPatterns += $p.TrimEnd('/','\')
    } else {
        $filePatterns += $p
    }
}

# Get all folders and files once
Write-Host "Scanning folders..."
$allFolders = Get-ChildItem -Path $LocalProject -Recurse -Directory -Force -ErrorAction SilentlyContinue
Write-Host "Scanning files..."
$allFiles = Get-ChildItem -Path $LocalProject -Recurse -File -Force -ErrorAction SilentlyContinue

# Function to convert wildcard pattern to regex
function WildcardToRegex($pattern) {
    # Escape regex special chars except * and ?
    $escaped = [Regex]::Escape($pattern) -replace '\\\*', '.*' -replace '\\\?', '.'
    return "^$escaped$"
}

# Process folder patterns
foreach ($fp in $folderPatterns) {
    $regex = WildcardToRegex $fp

    $matches = $allFolders | Where-Object {
        $_.FullName.Substring($LocalProject.Length).TrimStart('\') -match $regex
    }

    foreach ($folder in $matches) {
        $relativePath = $folder.FullName.Substring($LocalProject.Length).TrimStart('\')
        $source = $folder.FullName
        $destination = Join-Path $OneDriveProject $relativePath

        # Remove existing folder (if not symlink)
        if ((Test-Path $destination) -and -not (Get-Item $destination).Attributes.ToString().Contains("ReparsePoint")) {
            Remove-Item -Path $destination -Recurse -Force
            Write-Host "Removed folder: $destination"
        }

        # Ensure parent directory exists
        $parent = Split-Path $destination
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        # Create symlink if not exists
        if (-not (Test-Path $destination)) {
            cmd /c mklink /D "`"$destination`"" "`"$source`"" | Out-Null
            Write-Host "Symlinked folder: $destination -> $source"
        }
    }
}

# Process file patterns
foreach ($fp in $filePatterns) {
    $regex = WildcardToRegex $fp

    $matches = $allFiles | Where-Object {
        $_.Name -match $regex
    }

    foreach ($file in $matches) {
        $relativePath = $file.FullName.Substring($LocalProject.Length).TrimStart('\')
        $destination = Join-Path $OneDriveProject $relativePath

        if (Test-Path $destination) {
            Remove-Item -Path $destination -Force
            Write-Host "Removed file: $destination"
        }
    }
}

Write-Host "Done processing .onedriveignore."
