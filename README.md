# Smart Project Backup with `.onedriveignore` and PowerShell

This vibe coded repo (still too much effort) helps you efficiently back up your important project files and directories to a destination backup folder, using OneDrive as a robust cloud solution. This repository provides a PowerShell script and configuration setup to help you maintain organized, fast backups without including unnecessary files like cache, temp, or build artifacts.

---

## Concept Overview

- **Source Folder:** Your project directory. This is the folder containing all your work.
- **Destination Folder (`-backup`):** The folder where important files and directories are copied for backup. Ideally, this folder is located inside your OneDrive, leveraging fast cloud sync.
- **Logs Folder:** A dedicated location for storing logs about the backup process (added/changed/removed files).

You specify these three locations in the script before running.

---

## Key Features

- **Selective Backup:** Only important files and directories are backed up. Temporary, cache, or unwanted files are excluded.
- **Ignore Rules:** Use a `.onedriveignore` file to define patterns for files and folders to be skipped (similar to `.gitignore`).
- **Efficient Sync:** By placing the backup folder in OneDrive, you benefit from its rapid and reliable sync mechanism.
- **Special Handling for Binary Files:** The script uses hash checks to detect changes in binary files, ensuring only modified binaries are copied.
- **Detailed Logging:** All backup operations are logged—additions, changes, deletions—so you can track and audit the backup process.

---

## How It Works

1. **Configure the Script:**
   - Set your `source folder` (project directory).
   - Set your `destination folder` (inside OneDrive, e.g., `OneDrive\-backup`).
   - Set your `logs folder` for storing backup logs.

2. **Ignore Unwanted Files:**
   - Create a `.onedriveignore` file in your source folder.
   - List patterns for files and folders to exclude from backup (e.g., `*.tmp`, `cache/`, `node_modules/`, etc.).

3. **Run the Backup Script:**
   - Open PowerShell.
   - Set execution policy for the session:
     ```powershell
     Set-ExecutionPolicy RemoteSigned -Scope Process
     ```
   - Execute the script:
     ```powershell
     .\SyncWithIgnore.ps1
     ```
   - The script will:
     - Scan the source folder.
     - Compare files and folders against the destination backup.
     - Obey `.onedriveignore` rules.
     - For binary files, use hash checks to efficiently detect changes.
     - Copy only necessary files and folders.
     - Save a log of all actions performed.

---

## Example `.onedriveignore`

```

# Ignore all 'bin' and 'obj' folders in any subdirectory
**\bin\
**\obj\

# Ignore all hidden Git folders and metadata
**\.git\
**\.vs\
**\.vscode\

# Ignore temporary or intermediate files
*.tmp
*.log
*.bak
*.swp
*.DS_Store
Thumbs.db

# Ignore compiled outputs
*.exe
*.dll
*.pdb
*.class
*.out

# Ignore large files not needed for backup
*.iso
*.zip
*.7z
*.tar.gz

# Ignore cache folders
**\__pycache__\
**\node_modules\
**\.cache\

# Ignore custom folders
Temp\
Scratch\
Drafts\

# Ignore specific project files
my_project\SimulationLogs\
my_project\OldVersions\

```

---

## Running the Script with Administrator Privileges (CMD)

To ensure full access to all files (especially when creating symlinks or accessing protected folders), run the backup script as an administrator using a CMD batch file.

**Example `run_backup_admin.cmd`:**

```batch
@echo off
:: Elevate to admin
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Call PowerShell script
powershell -ExecutionPolicy Bypass -File "C:\Projects\SyncWithIgnore.ps1"

```

- Place this CMD/batch file in the same directory as `SyncWithIgnore.ps1`.
- Double-click it to launch the script with elevated privileges.

---

## Why Use This System?

- **Speed:** OneDrive sync is fast—your backups are quickly available in the cloud.
- **Efficiency:** Only the files that matter are backed up. No clutter.
- **Reliability:** Hash checking ensures that binary files are only copied when changed.
- **Auditability:** Logs provide a clear history of all backup operations.
- **Customizable:** Edit the ignore rules and backup locations to fit any project.

---

## Contributing

Suggestions, improvements, and contributions are welcome! Please open an issue or submit a pull request.

---

## License

This project is licensed under the MIT License.

---

## Questions & Support

For help or questions, please open an issue in this repository.
