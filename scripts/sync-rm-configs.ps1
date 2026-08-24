[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$baseConfigFile = Join-Path $scriptDir 'rm.config.json'

if (-not (Test-Path $baseConfigFile)) {
    Write-Host "Warning: rm.config.json not found. Skipping config update."
    exit 0
}

$baseCfg = Get-Content -Raw -Path $baseConfigFile | ConvertFrom-Json
$baseUrl = $baseCfg.Connection.Url

if (-not $baseUrl) {
    Write-Host "Warning: Connection.Url not set in rm.config.json"
    exit 0
}

Write-Host "Updating operation configs with URL: $baseUrl"

@(
    'rm.config.create.json',
    'rm.config.read.json',
    'rm.config.update.json',
    'rm.config.delete.json',
    'rm.config.save.json'
) | ForEach-Object {
    $configFile = Join-Path $scriptDir $_
    if (Test-Path $configFile) {
        $cfg = Get-Content -Raw -Path $configFile | ConvertFrom-Json
        $cfg.ApplicationServerUrl = $baseUrl
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $configFile -Encoding UTF8
        Write-Host "Updated: $_"
    }
}

Write-Host "Done!"
