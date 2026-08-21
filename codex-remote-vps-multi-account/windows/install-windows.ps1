param(
    [Parameter(Mandatory=$true)]
    [string]$MasterAlias,

    [string]$InstallDir = (Join-Path $HOME 'bin'),

    [switch]$SkipPathUpdate
)

$ErrorActionPreference = 'Stop'

if ($MasterAlias -notmatch '^[A-Za-z0-9._-]+$') {
    throw 'MasterAlias must be an SSH config alias using letters, numbers, dot, underscore, or hyphen.'
}

$Source = Join-Path $PSScriptRoot 'codex-auth.ps1'
if (-not (Test-Path $Source)) { throw "Missing source helper: $Source" }

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Force $Source (Join-Path $InstallDir 'codex-auth.ps1')

@{ master_alias = $MasterAlias } |
    ConvertTo-Json |
    Set-Content -Encoding UTF8 (Join-Path $InstallDir 'codex-auth.config.json')

$Cmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0codex-auth.ps1" %*
'@
Set-Content -Encoding ASCII (Join-Path $InstallDir 'codex-auth.cmd') $Cmd

if (-not $SkipPathUpdate) {
    $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
    $Parts = @($UserPath -split ';' | Where-Object { $_ })
    if ($Parts -notcontains $InstallDir) {
        $NewPath = (($Parts + $InstallDir) -join ';')
        [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
        Write-Host 'USER_PATH_UPDATED=YES'
    } else {
        Write-Host 'USER_PATH_UPDATED=NO_ALREADY_PRESENT'
    }
}

Write-Host "WINDOWS_HELPER_INSTALLED=$InstallDir"
Write-Host "MASTER_ALIAS=$MasterAlias"
Write-Host 'Open a new PowerShell window, then run: codex-auth status'
