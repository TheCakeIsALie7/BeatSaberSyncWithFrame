Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ConfigFile = Join-Path $RepoRoot "config\config.json"
$SyncScript = Join-Path $ScriptDir "sync-beatsaber.ps1"

$DefaultRemotePath = "/home/steamos/.local/share/Steam/steamapps/common/Beat Saber/Beat Saber_Data/CustomLevels"
$DefaultKeyPath = Join-Path $env:USERPROFILE ".ssh\id_ed25519_frame_bs"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Beat Saber Sync"
$form.Size = New-Object System.Drawing.Size(760, 580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

function Add-Label($Text, $X, $Y) {
    $Control = New-Object System.Windows.Forms.Label
    $Control.Text = $Text
    $Control.Location = New-Object System.Drawing.Point($X, $Y)
    $Control.AutoSize = $true
    [void]$form.Controls.Add($Control)
    return $Control
}

function Add-TextBox($X, $Y, $Width) {
    $Control = New-Object System.Windows.Forms.TextBox
    $Control.Location = New-Object System.Drawing.Point($X, $Y)
    $Control.Size = New-Object System.Drawing.Size($Width, 24)
    [void]$form.Controls.Add($Control)
    return $Control
}

[void](Add-Label "Beat Saber Sync" 20 20)

[void](Add-Label "CustomLevels" 20 65)
$txtSource = Add-TextBox 20 90 610

$sourceStatus = Add-Label "Select your Beat Saber CustomLevels folder." 20 118
$sourceStatus.ForeColor = [System.Drawing.Color]::Red

$btnSource = New-Object System.Windows.Forms.Button
$btnSource.Text = "Browse..."
$btnSource.Location = New-Object System.Drawing.Point(640, 89)
$btnSource.Size = New-Object System.Drawing.Size(90, 26)
[void]$form.Controls.Add($btnSource)

[void](Add-Label "Frame IP / Hostname" 20 150)
$txtHost = Add-TextBox 20 175 300

[void](Add-Label "SSH User" 350 150)
$txtUser = Add-TextBox 350 175 160
$txtUser.Text = "steamos"

[void](Add-Label "Frame CustomLevels Path" 20 220)
$txtRemote = Add-TextBox 20 245 710
$txtRemote.Text = $DefaultRemotePath

[void](Add-Label "SSH Private Key" 20 290)
$txtKey = Add-TextBox 20 315 610
$txtKey.Text = $DefaultKeyPath

$btnKey = New-Object System.Windows.Forms.Button
$btnKey.Text = "Browse..."
$btnKey.Location = New-Object System.Drawing.Point(640, 314)
$btnKey.Size = New-Object System.Drawing.Size(90, 26)
[void]$form.Controls.Add($btnKey)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save"
$btnSave.Location = New-Object System.Drawing.Point(20, 365)
$btnSave.Size = New-Object System.Drawing.Size(130, 34)
[void]$form.Controls.Add($btnSave)

$btnSetup = New-Object System.Windows.Forms.Button
$btnSetup.Text = "Set up SSH"
$btnSetup.Location = New-Object System.Drawing.Point(165, 365)
$btnSetup.Size = New-Object System.Drawing.Size(130, 34)
[void]$form.Controls.Add($btnSetup)

$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Test SSH"
$btnTest.Location = New-Object System.Drawing.Point(310, 365)
$btnTest.Size = New-Object System.Drawing.Size(130, 34)
[void]$form.Controls.Add($btnTest)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "SYNC"
$btnSync.Location = New-Object System.Drawing.Point(455, 365)
$btnSync.Size = New-Object System.Drawing.Size(140, 34)
[void]$form.Controls.Add($btnSync)

$status = Add-Label "Ready" 20 420

$lblSongs = Add-Label "Songs: 0" 20 455
$lblPending = Add-Label "Pending: 0" 180 455
$lblCopied = Add-Label "Copied: 0" 340 455

$current = Add-Label "Ready" 20 490
$current.MaximumSize = New-Object System.Drawing.Size(710, 35)

$output = New-Object System.Windows.Forms.TextBox
$output.Location = New-Object System.Drawing.Point(20, 525)
$output.Size = New-Object System.Drawing.Size(710, 25)
$output.ReadOnly = $true
$output.BorderStyle = [System.Windows.Forms.BorderStyle]::None
[void]$form.Controls.Add($output)

$script:SyncProcess = $null
$script:LogFile = $null
$script:SyncCompleteSeen = $false
$script:SyncCompleteSeen = $false
$script:LastCopied = 0
$script:LastPending = 0
$script:LastSongs = 0
$script:ProcessedOk = [System.Collections.Generic.HashSet[string]]::new()
$script:ProcessedFailed = [System.Collections.Generic.HashSet[string]]::new()

function Set-Status($Text) {
    $status.Text = $Text
    $form.Refresh()
}

function Validate-Source {
    $Path = $txtSource.Text.Trim()

    if (-not $Path) {
        $sourceStatus.Text = "Select your Beat Saber CustomLevels folder."
        $sourceStatus.ForeColor = [System.Drawing.Color]::Red
        $txtSource.BackColor = [System.Drawing.Color]::MistyRose
        return $false
    }

    try {
        $Item = Get-Item -LiteralPath $Path -ErrorAction Stop

        if (-not $Item.PSIsContainer -or $Item.Name -ne "CustomLevels") {
            throw "Invalid folder"
        }

        $sourceStatus.Text = "CustomLevels folder OK"
        $sourceStatus.ForeColor = [System.Drawing.Color]::Green
        $txtSource.BackColor = [System.Drawing.Color]::White
        return $true
    }
    catch {
        $sourceStatus.Text = "Invalid folder. Select the Beat Saber CustomLevels folder."
        $sourceStatus.ForeColor = [System.Drawing.Color]::Red
        $txtSource.BackColor = [System.Drawing.Color]::MistyRose
        return $false
    }
}

function Get-Config {
    [ordered]@{
        source = $txtSource.Text.Trim()
        frameHost = $txtHost.Text.Trim()
        frameUser = $txtUser.Text.Trim()
        framePath = $txtRemote.Text.Trim()
        sshKey = $txtKey.Text.Trim()
    }
}

function Save-Config {
    if (-not (Validate-Source)) {
        throw "Select a valid Beat Saber CustomLevels folder."
    }

    $Config = Get-Config

    if (-not $Config.frameHost) {
        throw "Enter the Steam Frame IP or hostname."
    }

    if (-not $Config.frameUser) {
        throw "Enter the Steam Frame SSH user."
    }

    if (-not $Config.framePath) {
        throw "Enter the Steam Frame CustomLevels path."
    }

    if (-not $Config.sshKey) {
        throw "Enter the SSH private key path."
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $ConfigFile) -Force | Out-Null
    $Config | ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
}

if (Test-Path -LiteralPath $ConfigFile) {
    try {
        $Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json

        if ($Config.source) { $txtSource.Text = $Config.source }
        if ($Config.frameHost) { $txtHost.Text = $Config.frameHost }
        if ($Config.frameUser) { $txtUser.Text = $Config.frameUser }
        if ($Config.framePath) { $txtRemote.Text = $Config.framePath }
        if ($Config.sshKey) { $txtKey.Text = $Config.sshKey }
    }
    catch {}
}

Validate-Source | Out-Null

$btnSource.Add_Click({
    $Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $Dialog.Description = "Select Beat Saber CustomLevels"

    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtSource.Text = $Dialog.SelectedPath
    }
})

$txtSource.Add_TextChanged({
    Validate-Source | Out-Null
})

$btnKey.Add_Click({
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    $Dialog.Title = "Select SSH private key"

    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtKey.Text = $Dialog.FileName
    }
})

$btnSave.Add_Click({
    try {
        Save-Config
        Set-Status "Configuration saved"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Configuration error")
    }
})

$btnSetup.Add_Click({
    try {
        $HostName = $txtHost.Text.Trim()
        $UserName = $txtUser.Text.Trim()
        $KeyPath = $txtKey.Text.Trim()

        if (-not $HostName) { throw "Enter the Steam Frame IP or hostname." }
        if (-not $UserName) { throw "Enter the Steam Frame SSH user." }
        if (-not $KeyPath) { throw "Enter the SSH private key path." }

        $KeyDirectory = Split-Path -Parent $KeyPath
        New-Item -ItemType Directory -Path $KeyDirectory -Force | Out-Null

        if (-not (Test-Path -LiteralPath $KeyPath)) {
            Set-Status "Generating SSH key..."

            & ssh-keygen -t ed25519 -f $KeyPath

            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $KeyPath)) {
                throw "SSH key generation failed."
            }
        }

        Save-Config

        $PublicKeyPath = "$KeyPath.pub"
        $Target = "$UserName@$HostName"
        $HelperPath = Join-Path $env:TEMP "BeatSaberSync-SSH-Setup.ps1"

        $Helper = @"
`$PublicKey = Get-Content -LiteralPath '$PublicKeyPath' -Raw
`$PublicKey | ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new '$Target' 'mkdir -p ~/.ssh; chmod 700 ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
if (`$LASTEXITCODE -eq 0) {
    Write-Host "SSH key installed successfully."
} else {
    Write-Host "SSH setup failed."
}
Read-Host "Press Enter to close"
"@

        Set-Content -LiteralPath $HelperPath -Value $Helper -Encoding UTF8

        Start-Process powershell.exe -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-NoExit",
            "-File",
            $HelperPath
        )

        Set-Status "SSH setup started"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "SSH setup error")
    }
})

$btnTest.Add_Click({
    try {
        Save-Config
        $Config = Get-Config

        Set-Status "Testing SSH..."

        $Result = & ssh `
            -o BatchMode=yes `
            -o ConnectTimeout=10 `
            -o IdentitiesOnly=yes `
            -i $Config.sshKey `
            "$($Config.frameUser)@$($Config.frameHost)" `
            "echo SSH_OK" 2>&1

        if ($LASTEXITCODE -eq 0 -and ($Result -join "").Trim() -eq "SSH_OK") {
            Set-Status "SSH connection OK"
        }
        else {
            Set-Status "SSH connection failed"
        }
    }
    catch {
        Set-Status "SSH connection failed"
    }
})

$btnSync.Add_Click({
    try {
        if ($script:SyncProcess -and -not $script:SyncProcess.HasExited) {
            return
        }

        Save-Config

        $script:LastCopied = 0
        $script:LastPending = 0
        $script:LastSongs = 0
        $script:SyncCompleteSeen = $false
        $script:ProcessedOk.Clear()
        $script:ProcessedFailed.Clear()

        $script:LogFile = Join-Path $env:TEMP "BeatSaberSync-$([Guid]::NewGuid().ToString('N')).log"
        $script:ErrorFile = "$script:LogFile.err"

        Remove-Item $script:LogFile,$script:ErrorFile -Force -ErrorAction SilentlyContinue

        $Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$SyncScript`""

        $script:SyncProcess = Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList $Arguments `
            -WorkingDirectory $RepoRoot `
            -RedirectStandardOutput $script:LogFile `
            -RedirectStandardError $script:ErrorFile `
            -WindowStyle Hidden `
            -PassThru

        $btnSync.Enabled = $false
        $btnSave.Enabled = $false
        $btnSetup.Enabled = $false
        $btnTest.Enabled = $false

        Set-Status "Sync running..."
        $current.Text = "Starting..."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Sync error")
    }
})

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 300

$Timer.Add_Tick({
    if (-not $script:SyncProcess -or -not $script:LogFile) {
        return
    }

    if (Test-Path -LiteralPath $script:LogFile) {
        $Lines = Get-Content -LiteralPath $script:LogFile -ErrorAction SilentlyContinue

        foreach ($Line in $Lines) {
            if ($Line -match '^\s*Songs\s*:\s*(\d+)') {
                $script:LastSongs = [int]$Matches[1]
            }

            if ($Line -match '^\s*Pending:\s*(\d+)') {
                $script:LastPending = [int]$Matches[1]
            }

            if ($Line -match '^\s*SYNC:\s*(.+)$') {
                $current.Text = "Syncing: $($Matches[1])"
            }

            if ($Line -match '^\s*OK:\s*(.+)$') {
                $Name = $Matches[1]

                if ($script:ProcessedOk.Add($Name)) {
                    $script:LastCopied++
                    $script:LastPending = [Math]::Max(0, $script:LastPending - 1)
                }
            }

            if ($Line -match '^\s*FAILED:\s*(.+)$') {
                $script:ProcessedFailed.Add($Matches[1]) | Out-Null
            }

            if ($Line -match 'Sync complete') {
                $script:SyncCompleteSeen = $true
                Set-Status "Sync complete"
                $current.Text = "Sync complete"
            }
        }

        $lblSongs.Text = "Songs: $script:LastSongs"
        $lblPending.Text = "Pending: $script:LastPending"
        $lblCopied.Text = "Copied: $script:LastCopied"
    }

    if ($script:SyncProcess.HasExited) {
        if (Test-Path -LiteralPath $script:ErrorFile) {
            $Errors = Get-Content -LiteralPath $script:ErrorFile -ErrorAction SilentlyContinue

            if ($Errors.Count -gt 0) {
                $output.Text = ($Errors | Select-Object -Last 1)
            }
        }

        if ($script:SyncCompleteSeen -or $script:SyncProcess.ExitCode -eq 0) {
            Set-Status "Sync complete"
        }
        else {
            Set-Status "Sync failed"
        }

        $btnSync.Enabled = $true
        $btnSave.Enabled = $true
        $btnSetup.Enabled = $true
        $btnTest.Enabled = $true

        $script:SyncProcess.Dispose()
        $script:SyncProcess = $null
    }
})

$Timer.Start()

$form.Add_Shown({
    $form.Activate()
})

[void]$form.ShowDialog()
