# Beat Saber Sync

Sync Beat Saber custom songs from a Windows PC to a Steam Frame.

The recommended way to use the project is the Windows GUI. It handles configuration, SSH setup, connection testing and synchronization.

Unofficial hobby project, not affiliated with or endorsed by Valve.

## Features

* Detects new custom songs.
* Detects modified custom songs.
* Transfers only pending songs.
* Real-time synchronization status.
* GUI configuration and synchronization.
* Automatic SSH key setup.
* SSH connection test.
* No synchronization software is required on the Steam Frame.
* Command-line synchronization is also available.

## Current status

This project is currently **experimental**.

It has been tested successfully with:

* Windows 11
* Windows PowerShell
* Beat Saber 1.40.8
* 1 Windows PC
* 1 Steam Frame
* Local network SSH/SCP transfers

It has not been tested with multiple PCs, multiple Steam Frames, other Beat Saber versions, or other Windows configurations.

Compatibility with other setups is not guaranteed.

## Requirements

### Windows PC

* Windows 10 or Windows 11
* PowerShell
* OpenSSH (`ssh`, `scp` and `ssh-keygen`)
* Beat Saber installed
* Beat Saber custom songs installed locally

Windows 11 is the only Windows version currently tested.

### Steam Frame

* Beat Saber installed
* SSH access enabled
* Network connectivity to the Windows PC

No synchronization software is required on the Steam Frame.

## Installation

Open PowerShell and move to your user directory:

```powershell
cd $env:USERPROFILE
```

Clone the repository:

```powershell
git clone https://github.com/TheCakeIsALie7/BeatSaberSyncWithFrame.git
cd BeatSaberSyncWithFrame
```

## GUI

Start the application:

```powershell
powershell -ExecutionPolicy Bypass -File ".\src\BeatSaberSync-GUI.ps1"
```

The GUI lets you configure:

* Local Beat Saber `CustomLevels` folder
* Steam Frame IP or hostname
* SSH user
* Remote `CustomLevels` path
* SSH private key

The local folder must be the actual Beat Saber `CustomLevels` folder. The GUI validates this automatically.

The default SSH user is `steamos`, but it can be changed.

The default remote path is the standard Steam Frame Beat Saber `CustomLevels` directory, but it can be changed.

## First-time SSH setup

The GUI can configure SSH automatically.

1. Enter the Steam Frame IP or hostname.
2. Check the SSH user.
3. Check the SSH private key path.
4. Click **Set up SSH**.
5. A PowerShell window opens.
6. Enter the Steam Frame SSH password.
7. The public key is installed automatically.
8. Close the setup window.
9. Click **Test SSH**.

After setup, synchronization uses SSH key authentication and does not require the password again.

The SSH password is not stored by the application.

## Synchronization

Click **SYNC** in the GUI.

The application displays:

```text
Songs: 473
Pending: 1
Copied: 0

Syncing: Example Song
```

When synchronization finishes:

```text
Songs: 473
Pending: 0
Copied: 1

Sync complete
```

Only new or changed songs are transferred.

The synchronization state is stored locally on the Windows PC.

## Command-line usage

The synchronization engine can also be run directly:

```powershell
powershell -ExecutionPolicy Bypass -File ".\src\sync-beatsaber.ps1"
```

It uses `config/config.json`.

## Manual configuration

Copy the example configuration:

```powershell
Copy-Item ".\config\config.example.json" ".\config\config.json"
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

### Configuration fields

| Property    | Description                             |
| ----------- | --------------------------------------- |
| `source`    | Local Beat Saber `CustomLevels` folder  |
| `frameHost` | Steam Frame IP address or hostname      |
| `frameUser` | SSH user on the Steam Frame             |
| `framePath` | Remote Beat Saber `CustomLevels` folder |
| `sshKey`    | Path to the SSH private key             |

## How synchronization works

For each song, the synchronization engine stores:

* Song folder name
* Number of files
* Total file size
* Latest file modification timestamp

A song is transferred when it is new or its stored metadata has changed.

Songs are transferred from Windows to the Steam Frame using SCP.

## Local data

The following files are generated locally:

```text
config/config.json
data/sync-state.txt
data/songs.manifest
```

These files are excluded from Git.

## Troubleshooting

### CustomLevels is marked invalid

The selected folder must be the actual Beat Saber `CustomLevels` directory.

The folder itself must be named:

```text
CustomLevels
```

Its location can be anywhere on the PC.

### SSH setup fails

Check:

* Frame IP or hostname
* SSH user
* Frame connectivity
* SSH availability on the Frame
* Frame SSH password

Manual connection test:

```powershell
ssh FRAME_SSH_USER@FRAME_IP
```

### SSH test fails

Run **Set up SSH** first, then **Test SSH**.

The GUI uses the configured private key for authentication.

### OpenSSH is missing

Check:

```powershell
Get-Command ssh
Get-Command scp
Get-Command ssh-keygen
```

## Limitations

* Tested on one Windows PC.
* Tested with one Steam Frame.
* Tested with Beat Saber 1.40.8.
* Windows 10 has not been tested.
* Synchronization state is local to the Windows PC.
* Deleted songs are not automatically removed from the Frame.
* No conflict resolution is implemented.
* The GUI is launched through PowerShell rather than a compiled executable.

## Contributing

Bug reports, compatibility reports and improvements are welcome.

If you test the project on another PC, Steam Frame or Beat Saber version, please report the configuration and whether synchronization worked correctly.

## License

MIT License.

See [LICENSE](LICENSE) for the full license text.
