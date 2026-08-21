param(
    [Parameter(Position=0)]
    [ValidateSet('status','list','use','add-chatgpt','remove')]
    [string]$Command = 'status',

    [Parameter(Position=1)]
    [string]$Profile,

    [string]$MasterAlias
)

$ErrorActionPreference = 'Stop'

if (-not $MasterAlias) {
    $ConfigPath = Join-Path $PSScriptRoot 'codex-auth.config.json'
    if (Test-Path $ConfigPath) {
        $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $MasterAlias = $cfg.master_alias
    }
}

if (-not $MasterAlias) {
    throw 'Master SSH alias is not configured. Run install-windows.ps1 -MasterAlias <alias>.'
}

if ($Command -in @('use','add-chatgpt','remove')) {
    if ([string]::IsNullOrWhiteSpace($Profile) -or $Profile -notmatch '^[A-Za-z0-9._-]+$') {
        throw 'A valid profile name is required.'
    }
}

$Remote = '~/.codex-auth-manager/bin/codex-auth'
$Args = @($MasterAlias, $Remote, $Command)
if ($Profile) { $Args += $Profile }

if ($Command -eq 'add-chatgpt') {
    & ssh -tt @Args
} else {
    & ssh @Args
}

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
