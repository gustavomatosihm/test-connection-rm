[CmdletBinding()]
param(
    [string]$ConfigFile = "",
    [string]$Username = "",
    [string]$CredentialFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfigFile) {
    $localConfig = Join-Path $PSScriptRoot 'rm.config.local.json'
    $defaultConfig = Join-Path $PSScriptRoot 'rm.config.json'
    if (Test-Path $localConfig) {
        $ConfigFile = $localConfig
    }
    elseif (Test-Path $defaultConfig) {
        $ConfigFile = $defaultConfig
    }
    else {
        throw "Arquivo de configuração não encontrado. Crie rm.config.json ou rm.config.local.json."
    }
}

if (-not (Test-Path $ConfigFile)) {
    throw "Arquivo de configuração não localizado: $ConfigFile"
}

if (-not $CredentialFile) {
    $config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
    $CredentialFile = $config.Authentication.CredentialFile
    if (-not $CredentialFile) {
        $CredentialFile = Join-Path $PSScriptRoot 'rm.credentials.json'
    }
}

if (-not [System.IO.Path]::IsPathRooted($CredentialFile)) {
    $CredentialFile = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $ConfigFile) $CredentialFile))
}

$config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
$targetUser = $Username
if (-not $targetUser) {
    if ($config.Authentication.Username -and $config.Authentication.Username -ne 'CHANGE_ME') {
        $targetUser = $config.Authentication.Username
    }
}

if (-not $targetUser) {
    $targetUser = Read-Host 'Informe o usuário do Dataserver RM'
}

Write-Host "Configurando credencial do Dataserver RM para usuario: $targetUser"
$securePassword = Read-Host 'Informe a senha' -AsSecureString

$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
}
finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}

$fileDirectory = Split-Path -Parent $CredentialFile
if (-not (Test-Path $fileDirectory)) {
    New-Item -ItemType Directory -Path $fileDirectory -Force | Out-Null
}

$bytes = [System.Text.Encoding]::UTF8.GetBytes($plainPassword)
$protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect($bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$payload = [ordered]@{
    Username = $targetUser
    PasswordProtected = [Convert]::ToBase64String($protectedBytes)
}

$payload | ConvertTo-Json | Set-Content -Path $CredentialFile -Encoding UTF8
Write-Host "Credencial salva com sucesso em: $CredentialFile"
