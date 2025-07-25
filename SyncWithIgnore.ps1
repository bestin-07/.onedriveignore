# ====== Configuration =======
$Source = "C:\Projects"
$Dest = "C:\Users\user\OneDrive - COMPANY/Projects_Backup"
$IgnoreFile = "$Source\.onedriveignore"

# Enable advanced options
$EnableHashCheckForBin = $true
$DryRun = $false

# ====== Log setup =======
$LogDir = "C:\Users\user\OneDrive - Company\logs"
if (!(Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir ("robocopy_backup_" + (Get-Date -Format "yyyy-MM-dd_HHmmss") + ".log")
$TimestampFile = Join-Path $LogDir "last_backup.txt"

# ====== Load ignore patterns and convert to regex =======
$IgnoreRegexes = @()
if (Test-Path $IgnoreFile) {
    Get-Content $IgnoreFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $line = $line -replace '/', '\'  # Normalize slashes
            if ($line.EndsWith("\")) { $line = $line.TrimEnd('\') }
            $pattern = [Regex]::Escape($line) -replace '\\\*', '.*'
            $IgnoreRegexes += "^$pattern$"
        }
    }
}

# ====== Load last backup time =======
$LastBackupTime = Get-Date "1900-01-01"
if (Test-Path $TimestampFile) {
    try {
        $content = Get-Content $TimestampFile -ErrorAction Stop
        $parsed = [datetime]::Parse($content)
        if ($parsed -ne $null) {
            $LastBackupTime = $parsed
        }
    } catch {
        Write-Warning "Could not parse last backup timestamp, defaulting to 1900-01-01"
    }
}
Write-Host "Last backup was at: $LastBackupTime" -ForegroundColor Yellow

# ====== Cache and hash helpers =======
$ExcludeCache = @{}

function ShouldExclude {
    param([string]$relPath)
    if ($ExcludeCache.ContainsKey($relPath)) {
        return $ExcludeCache[$relPath]
    }
    foreach ($regex in $IgnoreRegexes) {
        if ($relPath -match $regex) {
            $ExcludeCache[$relPath] = $true
            return $true
        }
    }
    $ExcludeCache[$relPath] = $false
    return $false
}

function Get-FileHashString {
    param([string]$path)
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

# ====== State tracking =======
$global:CurrentItem = 0
$global:CopiedFiles = @()
$LogEntries = @()

# ====== Recursive copy with filters =======
function Copy-WithExclude {
    param (
        [string]$SourceDir,
        [string]$DestDir,
        [string]$RootSource
    )

    $rootSourceLength = $RootSource.Length + 1

    Get-ChildItem -Path $SourceDir -Directory -Attributes !ReparsePoint | ForEach-Object {
        $global:CurrentItem++
        $relDir = $_.FullName.Substring($rootSourceLength)
        if (ShouldExclude $relDir) {
            Write-Host "($global:CurrentItem) Skipping folder: $relDir" -ForegroundColor Magenta
            $LogEntries += "SKIPPED FOLDER: $relDir"
            return
        }

        $newDestDir = Join-Path $DestDir $_.Name
        if (!(Test-Path $newDestDir)) {
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path $newDestDir -Force | Out-Null
            }
        }
        Copy-WithExclude -SourceDir $_.FullName -DestDir $newDestDir -RootSource $RootSource
    }

    Get-ChildItem -Path $SourceDir -File -Attributes !ReparsePoint | ForEach-Object {
        $global:CurrentItem++
        $relFile = $_.FullName.Substring($rootSourceLength)

        # Skip hidden or system files
        if ($_.Attributes -band [System.IO.FileAttributes]::Hidden -or
            $_.Attributes -band [System.IO.FileAttributes]::System) {
            return
        }

        if (ShouldExclude $relFile) {
            Write-Host "($global:CurrentItem) Skipping file: $relFile" -ForegroundColor DarkGray
            $LogEntries += "SKIPPED FILE: $relFile"
            return
        }

        $destFile = Join-Path $DestDir $_.Name

        if (!(Test-Path $destFile)) {
            if (-not $DryRun) {
                Copy-Item -Path $_.FullName -Destination $destFile -Force
            }
            Write-Host "($global:CurrentItem) Copied file (new): $relFile" -ForegroundColor Cyan
            $LogEntries += "COPIED FILE (New): $relFile"
            $global:CopiedFiles += $relFile
            return
        }

        if ($_.LastWriteTime -le $LastBackupTime) {
            # Check hash only for .bin files
            if ($EnableHashCheckForBin -and $_.Extension -eq ".bin") {
                $srcHash = Get-FileHashString $_.FullName
                $dstHash = Get-FileHashString $destFile
                if ($srcHash -ne $dstHash) {
                    if (-not $DryRun) {
                        Copy-Item -Path $_.FullName -Destination $destFile -Force
                    }
                    Write-Host "($global:CurrentItem) Copied .bin (hash mismatch): $relFile" -ForegroundColor Yellow
                    $LogEntries += "COPIED FILE (Hash mismatch): $relFile"
                    $global:CopiedFiles += $relFile
                } else {
                    Write-Host "($global:CurrentItem) Skipped .bin (hash match): $relFile" -ForegroundColor DarkGray
                    $LogEntries += "SKIPPED FILE (Hash match): $relFile"
                }
                return
            }

            Write-Host "($global:CurrentItem) Skipped (not modified): $relFile" -ForegroundColor DarkGray
            $LogEntries += "SKIPPED FILE (Not modified): $relFile"
            return
        }

        # Modified timestamp
        $destInfo = Get-Item $destFile
        if ($_.LastWriteTime -gt $destInfo.LastWriteTime) {
            if (-not $DryRun) {
                Copy-Item -Path $_.FullName -Destination $destFile -Force
            }
            Write-Host "($global:CurrentItem) Copied (updated): $relFile" -ForegroundColor Green
            $LogEntries += "COPIED FILE (Updated): $relFile"
            $global:CopiedFiles += $relFile
        } else {
            Write-Host "($global:CurrentItem) Skipped (up-to-date): $relFile" -ForegroundColor DarkGray
            $LogEntries += "SKIPPED FILE (Up-to-date): $relFile"
        }
    }
}

# ====== Sync deletion logic =======
function Sync-Delete-Missing {
    param (
        [string]$SourceDir,
        [string]$DestDir,
        [string]$RootDest
    )

    $rootDestLength = $RootDest.Length + 1

    Get-ChildItem -Path $DestDir -Force | ForEach-Object {
        $relPath = $_.FullName.Substring($rootDestLength)
        $srcPath = Join-Path $SourceDir $relPath

        if (ShouldExclude $relPath) {
            Write-Host "(SYNC) Removing ignored item: $relPath" -ForegroundColor Yellow
            if (-not $DryRun) { Remove-Item $_.FullName -Recurse -Force }
            $LogEntries += "REMOVED IGNORED: $relPath"
            return
        }

        if (!(Test-Path $srcPath)) {
            Write-Host "(SYNC) Removing obsolete: $relPath" -ForegroundColor Red
            if (-not $DryRun) { Remove-Item $_.FullName -Recurse -Force }
            $LogEntries += "REMOVED: $relPath"
        } elseif ($_.PSIsContainer) {
            Sync-Delete-Missing -SourceDir $SourceDir -DestDir $_.FullName -RootDest $RootDest
        }
    }
}

# ====== Start Backup =======
try {
    Write-Host "Backup started at $(Get-Date)" -ForegroundColor Green
    $LogEntries += "Backup started at $(Get-Date)`n"

    Copy-WithExclude -SourceDir $Source -DestDir $Dest -RootSource $Source
    Sync-Delete-Missing -SourceDir $Source -DestDir $Dest -RootDest $Dest

    $LogEntries += "`nBackup finished at $(Get-Date)"
    Write-Host "Backup complete at $(Get-Date)" -ForegroundColor Green

    if (-not $DryRun) {
        (Get-Date).ToString("o") | Out-File -FilePath $TimestampFile -Encoding ascii -Force
    }

    Write-Host "`nTotal modified/copied files: $($global:CopiedFiles.Count)" -ForegroundColor Cyan
    $LogEntries += "`nTotal modified/copied files: $($global:CopiedFiles.Count)"

    if ($global:CopiedFiles.Count -gt 0) {
        Write-Host "List of modified/copied files:" -ForegroundColor Cyan
        $global:CopiedFiles | ForEach-Object { Write-Host $_ }
        $LogEntries += "`nList of modified/copied files:"
        $global:CopiedFiles | ForEach-Object { $LogEntries += $_ }
    } else {
        Write-Host "No files were modified or copied." -ForegroundColor Yellow
        $LogEntries += "`nNo files were modified or copied."
    }

    $LogEntries | Out-File -FilePath $LogFile -Encoding utf8 -Append
}
catch {
    Write-Error "Backup failed: $_"
    $LogEntries += "`nBackup failed at $(Get-Date): $_"
    $LogEntries | Out-File -FilePath $LogFile -Encoding utf8 -Append
    exit 1
}
