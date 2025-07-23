# .onedriveignore 

This Vibe-Coded repository provides tools to help you control which files and folders are synced with OneDrive, using a `.onedriveignore` file and a PowerShell script for selective syncing. Useful to keep projects in antivirus exclusion folders but still need an automatic backup for your work related "stuff".

## How to Set Up OneDrive Sync with Ignore Rules

### 1. Create a Symlink to Your Folder in OneDrive

To make OneDrive sync a folder from another location (outside the OneDrive folder), create a symbolic link (symlink) between your actual folder and a target folder within OneDrive.

**Example command (Windows):**
```sh
mklink /D "onedrive\linkfolder" "C:\Originalfolder"
```
- `"onedrive\linkfolder"`: Path where you want the link to appear in your OneDrive folder.
- `"C:\Originalfolder"`: Path to the actual folder you want to sync.

> **Run this command in Command Prompt as Administrator.**

### 2. Add a `.onedriveignore` File

Create a `.onedriveignore` file in your folder to specify patterns for files and directories you want OneDrive to ignore.

**Example `.onedriveignore`:**
```
*.log
temp/
secrets.txt
```

### 3. Add the SyncWithIgnore.ps1 Script

Place the `SyncWithIgnore.ps1` PowerShell script in your folder. This script will automate syncing by reading your `.onedriveignore` file and ensuring OneDrive ignores the specified files/folders.

### 4. Run the PowerShell Script

Before running the script, set the execution policy for the session to allow local scripts:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
```

Then, run the script:

```powershell
.\SyncWithIgnore.ps1
```

This process will apply the ignore rules and sync your files accordingly.

## Contributing

Contributions are welcome! If you have suggestions or improvements, feel free to submit a pull request or open an issue.

## License

This repository is licensed under the MIT License.
