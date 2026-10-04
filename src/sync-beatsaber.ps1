$ConfigFile = "$PSScriptRoot\..\config\config.json"
$DataDir = "$PSScriptRoot\..\data"
$StateFile = "$DataDir\sync-state.txt"
$ManifestFile = "$DataDir\songs.manifest"
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $ConfigFile)) {
    throw "Configuration file not found: $ConfigFile"
}

$Config = Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json

$Source = $Config.source
$FrameHost = $Config.frameHost
$FrameUser = $Config.frameUser
$FramePath = $Config.framePath

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Source directory not found: $Source"
}

$Songs = @{}

Get-ChildItem -LiteralPath $Source -Directory |
    Where-Object { $_.Name -notmatch '\(Built in\)$' } |
    ForEach-Object {
        $Files = Get-ChildItem -LiteralPath $_.FullName -File -Recurse
        $Size = ($Files | Measure-Object -Property Length -Sum).Sum
        $MTime = ($Files | ForEach-Object { $_.LastWriteTimeUtc } | Measure-Object -Maximum).Maximum
        $Timestamp = ([DateTimeOffset]$MTime).ToUnixTimeSeconds()

        $Songs[$_.Name] = "$($_.Name)`t$($Files.Count)`t$Size`t$Timestamp"
    }

$Songs.Values |
    Sort-Object |
    Set-Content -LiteralPath $ManifestFile -Encoding UTF8

$Synced = @{}

if (Test-Path -LiteralPath $StateFile) {
    Get-Content -LiteralPath $StateFile | ForEach-Object {
        $Parts = $_ -split "`t", 4

        if ($Parts.Count -eq 4) {
            $Synced[$Parts[0]] = $_
        }
    }
}

$Pending = @()

foreach ($Name in $Songs.Keys) {
    if (-not $Synced.ContainsKey($Name)) {
        $Pending += $Name
    }
    elseif ($Synced[$Name] -ne $Songs[$Name]) {
        $Pending += $Name
    }
}

Write-Host ""
Write-Host "Source : $Source"
Write-Host "Frame  : $FrameUser@$FrameHost"
Write-Host "Songs  : $($Songs.Count)"
Write-Host "Synced : $($Synced.Count)"
Write-Host "Pending: $($Pending.Count)"
Write-Host ""

foreach ($Name in ($Pending | Sort-Object)) {
    Write-Host "SYNC: $Name"

    $LocalPath = Join-Path $Source $Name
    $RemotePath = "$FrameUser@$FrameHost`:$FramePath/"

    & scp -o IdentitiesOnly=yes -i $Config.sshKey -r $LocalPath $RemotePath

    if ($LASTEXITCODE -eq 0) {
        $Synced[$Name] = $Songs[$Name]
        Write-Host "OK: $Name"
    }
    else {
        Write-Host "FAILED: $Name"
    }

    Write-Host ""
}

$Synced.Values |
    Sort-Object |
    Set-Content -LiteralPath $StateFile -Encoding UTF8

Write-Host "Sync complete"
