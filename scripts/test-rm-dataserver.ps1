[CmdletBinding()]
param(
    [string]$ConfigFile = "",
    [string]$CredentialFile = "",
    [string]$RelativePath = "",
    [string]$Method = "",
    [string]$Body = "",
    [int]$TimeoutSeconds = 0,
    [int]$RetryCount = 0,
    [switch]$ShowConfigOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-PathFromBase {
    param(
        [string]$Path,
        [string]$BasePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Get-CredentialFromFile {
    param(
        [string]$CredentialPath
    )

    if (-not (Test-Path $CredentialPath)) {
        return $null
    }

    $payload = Get-Content -Raw -Path $CredentialPath | ConvertFrom-Json
    $encryptedBytes = [Convert]::FromBase64String($payload.PasswordProtected)
    $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $plainPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

    $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
    return [System.Management.Automation.PSCredential]::new($payload.Username, $securePassword)
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    if (($Object.PSObject.Properties.Name -contains $Name)) {
        return $Object.$Name
    }

    return $Default
}

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

$config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
$serverUrl = Get-PropertyValue -Object $config -Name 'ApplicationServerUrl' -Default (Get-PropertyValue -Object $config -Name 'ServerUrl')
if (-not $serverUrl) { throw 'Configuração sem ApplicationServerUrl/ServerUrl.' }

$dataServer = Get-PropertyValue -Object $config -Name 'DataServer' -Default (Get-PropertyValue -Object $config -Name 'DataSource')
if (-not $dataServer) { throw 'Configuração sem DataServer/DataSource.' }

if (-not $CredentialFile) {
    $authConfig = Get-PropertyValue -Object $config -Name 'Authentication'
    if ($authConfig) {
        $credentialPath = Get-PropertyValue -Object $authConfig -Name 'CredentialFile'
        if ($credentialPath) {
            $CredentialFile = Resolve-PathFromBase -Path $credentialPath -BasePath (Split-Path -Parent $ConfigFile)
        }
    }
    if (-not $CredentialFile -and (Test-Path (Join-Path $PSScriptRoot 'rm.credentials.json'))) {
        $CredentialFile = Join-Path $PSScriptRoot 'rm.credentials.json'
    }
}

if (-not $Method) {
    $Method = Get-PropertyValue -Object $config -Name 'HttpMethod' -Default (Get-PropertyValue -Object $config -Name 'Method' -Default 'GET')
}

if (-not $RelativePath) {
    $RelativePath = Get-PropertyValue -Object $config -Name 'RelativePath' -Default ''
}

if (-not $Body) {
    $requestBody = Get-PropertyValue -Object $config -Name 'RequestBody'
    if ($null -eq $requestBody) {
        $requestConfig = Get-PropertyValue -Object $config -Name 'Request'
        if ($requestConfig) {
            $requestBody = Get-PropertyValue -Object $requestConfig -Name 'Body'
        }
    }
    if ($null -ne $requestBody) { $Body = $requestBody }
}

if ($TimeoutSeconds -eq 0) {
    $TimeoutSeconds = [int](Get-PropertyValue -Object $config -Name 'TimeoutSeconds' -Default 30)
}

if ($RetryCount -eq 0) {
    $RetryCount = [int](Get-PropertyValue -Object $config -Name 'RetryCount' -Default 2)
}

if (-not [string]::IsNullOrWhiteSpace($RelativePath)) {
    $finalUrl = $serverUrl.TrimEnd('/') + '/' + $RelativePath.Trim('/')
}
else {
    $finalUrl = $serverUrl.TrimEnd('/') + '/' + $dataServer.Trim('/')
}

$headers = @{}
$rawHeaders = Get-PropertyValue -Object $config -Name 'Headers'
if ($rawHeaders) {
    foreach ($header in $rawHeaders) {
        if ($header.Name) {
            $headers[$header.Name] = $header.Value
        }
    }
}

$authConfig = Get-PropertyValue -Object $config -Name 'Authentication'
if ($authConfig) {
    $authType = [string](Get-PropertyValue -Object $authConfig -Name 'Type' -Default 'Basic')
    $authType = $authType.ToUpperInvariant()
    $credential = $null
    if ($CredentialFile) {
        $credential = Get-CredentialFromFile -CredentialPath $CredentialFile
    }

    if ($credential -and $authType -eq 'BASIC') {
        $networkCred = [System.Net.NetworkCredential]::new($credential.UserName, $credential.Password)
        $pair = "$($networkCred.UserName):$($networkCred.Password)"
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $headers['Authorization'] = "Basic $encoded"
    }
    elseif (-not $credential) {
        $user = Get-PropertyValue -Object $authConfig -Name 'Username'
        if ($user -and $user -ne 'CHANGE_ME') {
            $pass = Read-Host "Informe a senha para $user" -AsSecureString
            $credential = [System.Management.Automation.PSCredential]::new($user, $pass)
            $networkCred = [System.Net.NetworkCredential]::new($credential.UserName, $credential.Password)
            $pair = "$($networkCred.UserName):$($networkCred.Password)"
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
            $headers['Authorization'] = "Basic $encoded"
        }
    }
}

$configSummary = [ordered]@{
    ApplicationServerUrl = $serverUrl
    DataServer = $dataServer
    Url = $finalUrl
    HttpMethod = $Method
    TimeoutSeconds = $TimeoutSeconds
    RetryCount = $RetryCount
    RelativePath = $RelativePath
    CredentialFile = $CredentialFile
}

if ($ShowConfigOnly) {
    $configSummary | ConvertTo-Json -Depth 5
    return
}

$attempt = 0
$lastError = $null
while ($attempt -le $RetryCount) {
    $attempt++
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        if ($Method -eq 'GET') {
            $response = Invoke-WebRequest -Uri $finalUrl -Method Get -Headers $headers -TimeoutSec $TimeoutSeconds
        }
        else {
            $response = Invoke-WebRequest -Uri $finalUrl -Method $Method -Headers $headers -Body $Body -TimeoutSec $TimeoutSeconds
        }

        $stopwatch.Stop()
        $content = $response.Content

        $samplesDir = Join-Path $PSScriptRoot '..\samples'
        New-Item -ItemType Directory -Path $samplesDir -Force | Out-Null
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $responseFile = Join-Path $samplesDir ("rm-response-$timestamp.txt")
        $content | Set-Content -Path $responseFile -Encoding UTF8

        [pscustomobject]@{
            Url = $finalUrl
            StatusCode = $response.StatusCode
            ElapsedMilliseconds = $stopwatch.ElapsedMilliseconds
            Content = $content
            ResponseFile = $responseFile
        }

        return
    }
    catch {
        $lastError = $_
        $responseBody = $null
        if ($lastError.Exception -and $lastError.Exception.Response) {
            try {
                $stream = $lastError.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Dispose()
                }
            }
            catch {}
        }

        if ($responseBody) {
            $samplesDir = Join-Path $PSScriptRoot '..\samples'
            New-Item -ItemType Directory -Path $samplesDir -Force | Out-Null
            $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $errorFile = Join-Path $samplesDir ("rm-error-$timestamp.txt")
            $responseBody | Set-Content -Path $errorFile -Encoding UTF8
            Write-Warning "Resposta do servidor salva em: $errorFile"
        }

        if ($attempt -le $RetryCount) {
            Write-Warning "Tentativa $attempt/$($RetryCount + 1) falhou. Repetindo em 2 segundos..."
            Start-Sleep -Seconds 2
            continue
        }

        throw "Falha ao consultar Dataserver RM. Url: $finalUrl. Detalhes: $($lastError.Exception.Message)"
    }
}
