# Beat Saber Sync

Incremental synchronization of Beat Saber custom songs from a Windows PC to a Steam Frame using SSH/SCP.

The sync runs entirely on the Windows PC. The Steam Frame only receives the song files.

Unofficial hobby project, not affiliated with or endorsed by Valve.

## Features

* Detects new Beat Saber custom songs.
* Detects modified songs.
* Transfers only new or changed songs.
* Uses SSH key authentication.
* Uses SCP for file transfer.
* Keeps synchronization state locally.
* Does not require any software or scripts running on the Steam Frame.
* Excludes Beat Saber's built-in song folders.

## Current status

This project is currently **experimental**.

It has been tested successfully with:

* 1 Windows PC
* Windows PowerShell
* Beat Saber 1.40.8
* 1 Steam Frame
* SSH/SCP file transfers over a local network

The author has not tested the project on multiple PCs, multiple Steam Frames, other Beat Saber versions, or different Beat Saber installations.

It works on the author's setup, but compatibility with other configurations is not guaranteed.

If you test it on another setup, feedback and bug reports are welcome.

## Requirements

### Windows PC

* Windows 11 (tested); Windows 10 has not been tested
* PowerShell
* OpenSSH client (`ssh` and `scp`)
* Beat Saber installed
* Beat Saber custom songs installed locally

### Steam Frame

* SSH access
* Network connectivity to the Windows PC
* Beat Saber installed

No additional software is required on the Steam Frame.

## Installation

Clone the repository:

```powershell
git clone https://github.com/TheCakeIsALie7/BeatSaberSyncWithFrame.git
cd BeatSaberSyncWithFrame
```

Copy the example configuration:

```powershell
Copy-Item ".\config\config.example.json" ".\config\config.json"
```

Edit the configuration:

```powershell
notepad ".\config\config.json"
```

Example:

```json
{
    "source": "PATH_TO_CUSTOM_LEVELS",
    "frameHost": "FRAME_IP",
    "frameUser": "FRAME_SSH_USER",
    "framePath": "FRAME_CUSTOM_LEVELS_PATH",
    "sshKey": "SSH_PRIVATE_KEY_PATH"
}
```

### Configuration

| Property    | Description                                  |
| ----------- | -------------------------------------------- |
| `source`    | Local Beat Saber `CustomLevels` directory    |
| `frameHost` | IP address or hostname of the Steam Frame    |
| `frameUser` | SSH user on the Steam Frame                  |
| `framePath` | Remote Beat Saber `CustomLevels` directory   |
| `sshKey`    | Private SSH key used to connect to the Frame |

`config.json` is intentionally excluded from Git because it contains machine-specific configuration.

## SSH authentication

The recommended setup is SSH key authentication.

Generate a key on Windows if necessary:

```powershell
ssh-keygen -t ed25519
```

Copy the public key to the Steam Frame's:

```text
~/.ssh/authorized_keys
```

Then test the connection:

```powershell
ssh -o IdentitiesOnly=yes -i "$env:USERPROFILE\.ssh\id_ed25519_frame" steamos@FRAME_IP "echo SSH_OK"
```

The expected result is:

```text
SSH_OK
```

The sync script uses the configured private key automatically.

## Usage

From the repository root, run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\src\sync-beatsaber.ps1"
```

The script scans the local custom song directory and compares each song against the locally stored synchronization state.

For example:

```text
Source : C:\...\CustomLevels
Frame  : steamos@FRAME_IP
Songs  : 469
Synced : 469
Pending: 0

Sync complete
```

If a new or modified song is detected:

```text
SYNC: 54c92 (BRAINWASHED - HicqLlie)
OK: 54c92 (BRAINWASHED - HicqLlie)
```

Only pending songs are transferred.

Running the script again without changes should therefore result in:

```text
Pending: 0
```

## How synchronization works

For each custom song, the script records:

* Song folder name
* Number of files
* Total file size
* Latest file modification timestamp

This information is stored locally in:

```text
data/sync-state.txt
```

A song is transferred when:

* It does not exist in the synchronization state, or
* Its stored metadata has changed.

The song itself is transferred using SCP directly from the Windows PC to the Steam Frame.

## Local files

The following files are generated locally and are not committed to Git:

```text
config/config.json
data/sync-state.txt
data/songs.manifest
```

They contain machine-specific configuration and synchronization state.

## Troubleshooting

### SSH connection fails

Test SSH independently:

```powershell
ssh -o IdentitiesOnly=yes -i "C:\Path\To\Key" steamos@FRAME_IP "echo SSH_OK"
```

If this does not work, fix SSH connectivity before running the sync script.

### SCP is not available

Check:

```powershell
Get-Command scp
```

and:

```powershell
Get-Command ssh
```

Windows OpenSSH can normally be installed through Windows Optional Features.

### A song is not detected as changed

The synchronization check is based on file count, total size and the latest file modification timestamp.

If the contents of a file are changed without affecting those values, the change may not be detected.

## Limitations

This project currently has some limitations:

* Tested only on one Windows PC.
* Tested only with one Steam Frame.
* Tested with Beat Saber 1.40.8.
* No remote synchronization database is maintained on the Frame.
* Deleted local files are not currently removed automatically from the Frame.
* Files deleted from an existing song folder may remain on the Frame.
* The current synchronization state is local to the Windows PC.
* No conflict resolution is implemented.

These limitations may change in future versions.

## Contributing

Bug reports, compatibility reports and improvements are welcome.

If you test the project with a different PC, Steam Frame or Beat Saber version, please report the configuration and whether synchronization worked correctly.

## License

MIT License.

See [LICENSE](LICENSE) for the full license text.
