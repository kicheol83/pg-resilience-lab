param(
    [Parameter(Position = 0)][string]$Command = "help",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
if (-not $env:COMPOSE_BAKE) { $env:COMPOSE_BAKE = "false" }

function Invoke-Compose {
    param([string[]]$Arguments)
    $files = @("-f", "compose.yaml")
    if ($env:LAB_COMPOSE_FILES) {
        foreach ($f in $env:LAB_COMPOSE_FILES.Split(";")) { if ($f) { $files += @("-f", $f) } }
    }
    & docker compose @files @Arguments
    if ($LASTEXITCODE -ne 0) { throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

function New-LabPassword {
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $body = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return "Lab$body-7x"
}

function Initialize-Lab {
    if (Test-Path .env) {
        Write-Host ".env already exists; delete it to generate new passwords"
        return
    }
    $lines = foreach ($k in @("REPMGR_PASSWORD", "LEDGER_OWNER_PASSWORD", "LEDGER_APP_PASSWORD", "LEDGER_RO_PASSWORD", "PGMONITOR_PASSWORD")) {
        "$k=$(New-LabPassword)"
    }
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ".env"), (($lines -join "`n") + "`n"))
    Write-Host "wrote .env with random passwords"
}

function Start-Lab {
    if (-not (Test-Path .env)) { Initialize-Lab }
    Invoke-Compose @("--profile", "tools", "--profile", "upgrade", "build")
    Invoke-Compose @("up", "-d", "certs", "pg1", "pg2", "pg3", "witness", "backup", "haproxy", "redis", "migrate", "api")
    Invoke-Compose @("run", "--rm", "runner", "post-up")
}

switch ($Command) {
    "init" { Initialize-Lab }
    "up" { Start-Lab }
    "down" { Invoke-Compose @("down") }
    "reset" {
        Invoke-Compose @("--profile", "upgrade", "down", "-v", "--remove-orphans")
        Start-Lab
    }
    "upgrade-node" { Invoke-Compose @("--profile", "upgrade", "up", "-d", "pg18") }
    "logs" { Invoke-Compose (@("logs", "-f", "--tail", "100") + $Rest) }
    "ps" { Invoke-Compose @("ps") }
    "help" {
        Write-Host "usage: .\lab.ps1 {init|up|down|reset|ps|logs [svc]|upgrade-node|<runner command>}"
        Invoke-Compose @("run", "--rm", "runner", "help")
    }
    default { Invoke-Compose (@("run", "--rm", "runner", $Command) + $Rest) }
}
