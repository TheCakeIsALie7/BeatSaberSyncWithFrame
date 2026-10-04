# Beat Saber Sync

Incremental Windows-to-Steam Frame synchronization for Beat Saber custom songs.

## Features

- Detects new and modified songs.
- Transfers only pending songs using SCP.
- Uses SSH key authentication.
- Runs entirely from Windows.
- Maintains local synchronization state.
- Excludes built-in Beat Saber song folders.

## Requirements

- Windows 10/11 and PowerShell.
- OpenSSH client (ssh and scp).
- Beat Saber custom songs on the Windows PC.
- SSH access to the Steam Frame.

## Configuration

Copy config/config.example.json to config/config.json.

Configure source, frameHost, frameUser, framePath and sshKey in config.json.

## SSH authentication

Add the public key to the Steam Frame authorized_keys file.

Test the connection:

    ssh -o IdentitiesOnly=yes -i "$env:USERPROFILE\.ssh\id_ed25519_frame" steamos@FRAME_IP "echo SSH_OK"

## Usage

Run from the repository root:

    powershell -ExecutionPolicy Bypass -File ".\src\sync-beatsaber.ps1"

The script compares local song metadata with saved synchronization state and transfers new or changed songs.

## Local data

- data/sync-state.txt: synchronization state.
- data/songs.manifest: generated song manifest.

Personal configuration and local state are excluded from Git.

## License

MIT
