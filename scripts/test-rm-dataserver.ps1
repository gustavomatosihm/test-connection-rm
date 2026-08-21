[CmdletBinding()]
param(
    [string]$ConfigFile = "",
    [ValidateSet("ReadRecord","SaveRecord","DeleteRecord","DeleteRecordByKey")]
    [string]$Operation = "ReadRecord",
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

function Initialize-ProtectedDataSupport {
    try {
        [System.Security.Cryptography.ProtectedData] | Out-Null
        return $true
    }
    catch {
        try {
            Add-Type -AssemblyName System.Security
            [System.Security.Cryptography.ProtectedData] | Out-Null
            return $true
        }
        catch {
            return $false
        }
    }
}

$script:ProtectedDataSupported = Initialize-ProtectedDataSupport

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
    $plainPassword = $payload.Password
    if (-not $plainPassword -and $payload.PasswordProtected -and $script:ProtectedDataSupported) {
        $encryptedBytes = [Convert]::FromBase64String($payload.PasswordProtected)
        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        $plainPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
    if (-not $plainPassword) {
        throw 'Credencial inválida: senha ausente.'
    }

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

function Write-RmErrorLog {
    param(
        [string]$Operation,
        [string]$Url,
        [string]$Message,
        [string]$ResponseBody = '',
        [string]$StatusCode = ''
    )

    $logDir = Join-Path $PSScriptRoot '..\docs\logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logPath = Join-Path $logDir 'rm-errors.log'

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK'
    $entry = @(
        "[$timestamp]",
        "Operation: $Operation",
        "Url: $Url",
        "StatusCode: $StatusCode",
        "Message: $Message",
        "ResponseBody:"
    )

    if (-not [string]::IsNullOrWhiteSpace($ResponseBody)) {
        $entry += $ResponseBody
    }
    else {
        $entry += '(empty)'
    }

    $entryText = ($entry -join [Environment]::NewLine) + [Environment]::NewLine + ('-' * 80) + [Environment]::NewLine
    Add-Content -Path $logPath -Value $entryText -Encoding UTF8
}

function Escape-XmlValue {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function Convert-ReadRecordToSaveRecordBody {
    param([string]$XmlText)

    $escaped = Escape-XmlValue -Value $XmlText
    $inner = @"
<PrjIsm>
  <MIsm>
    <CODCOLIGADA>1</CODCOLIGADA>
    <IDPRJ>27056</IDPRJ>
    <IDISM>4875985</IDISM>
    <CODISM>015.0400.00001</CODISM>
    <DESCISM>SERVIÇOS PRESTADOS POR TERCEIROS</DESCISM>
    <CODUND>UN</CODUND>
    <GRUPODNER>C</GRUPODNER>
    <IDGIS>47161</IDGIS>
    <IDISMPRC>2358368</IDISMPRC>
    <VALOR>0.0000</VALOR>
    <VALORSEMLEIS>0.0000</VALORSEMLEIS>
    <VALORIMPRODUTIVO>0.0000</VALORIMPRODUTIVO>
    <CODAPLIC>M</CODAPLIC>
    <FATORK>1.0000</FATORK>
    <FLAGFRACIONARIO>0</FLAGFRACIONARIO>
    <JORNADA>0.00</JORNADA>
    <GRUPODNERGIS>C</GRUPODNERGIS>
    <PRAZORESSUP>0</PRAZORESSUP>
    <DESCRICAOCOMPLETA>SERVIÇOS PRESTADOS POR TERCEIROS</DESCRICAOCOMPLETA>
    <MINIMOHORAEXTRA>0.0000</MINIMOHORAEXTRA>
    <APLICFORMULA>M</APLICFORMULA>
    <TIPOISMDERIVADO>0</TIPOISMDERIVADO>
    <TIPO>0</TIPO>
    <PRIORIDADECALC>0</PRIORIDADECALC>
    <MAXIMOHORAEXTRA>0.0000</MAXIMOHORAEXTRA>
    <CUSTOUNITHORAEXTRA>0.0000</CUSTOUNITHORAEXTRA>
    <JORNADAPERIODO>0.00</JORNADAPERIODO>
    <ISMDETALHADO>0</ISMDETALHADO>
    <UTILIZADETISMCNT>0</UTILIZADETISMCNT>
    <CODCOLIGADA1>1</CODCOLIGADA1>
    <IDPRJ1>27056</IDPRJ1>
    <IDISM1>4875985</IDISM1>
    <Icone>7</Icone>
  </MIsm>
  <MISMCOMPL>
    <CODCOLIGADA>1</CODCOLIGADA>
    <IDPRJ>27056</IDPRJ>
    <IDISM>4875985</IDISM>
    <RECCREATEDBY>emanuelle.nunes</RECCREATEDBY>
    <RECCREATEDON>2013-08-29T08:46:51</RECCREATEDON>
    <RECMODIFIEDBY>mestre</RECMODIFIEDBY>
    <RECMODIFIEDON>2023-04-14T14:31:56</RECMODIFIEDON>
  </MISMCOMPL>
  <MISMPRD>
    <CODCOLIGADA>1</CODCOLIGADA>
    <IDPRJ>27056</IDPRJ>
    <IDISM>4875985</IDISM>
    <IDPRD>8210</IDPRD>
    <PRINCIPAL>1</PRINCIPAL>
    <CODIGOPRD>015.0400.00001</CODIGOPRD>
    <NOMEFANTASIA>NÃO UTILIZAR - SERVIÇOS PRESTADOS POR TERCEIROS</NOMEFANTASIA>
    <DESCRICAO>SERVIÇOS PRESTADOS POR TERCEIROS</DESCRICAO>
    <CODUNDCONTROLE>UN</CODUNDCONTROLE>
    <CODFAB>015.0400.00001</CODFAB>
    <INATIVO>0</INATIVO>
    <Icone>1</Icone>
  </MISMPRD>
  <MISMDESC>
    <CODCOLIGADA>1</CODCOLIGADA>
    <IDPRJ>27056</IDPRJ>
    <IDISM>4875985</IDISM>
    <DESCRICAOCOMPLETA>SERVIÇOS PRESTADOS POR TERCEIROS</DESCRICAOCOMPLETA>
  </MISMDESC>
</PrjIsm>
"@
    return '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://www.totvs.com/"><soapenv:Header/><soapenv:Body><tem:SaveRecord><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:XML>' + $escaped + '</tem:XML><tem:Contexto></tem:Contexto></tem:SaveRecord></soapenv:Body></soapenv:Envelope>'
}
function Get-DefaultSoapAction {
    param([string]$Op)
    switch ($Op) {
        'SaveRecord' { 'http://www.totvs.com/IwsDataServer/SaveRecord' }
        'DeleteRecord' { 'http://www.totvs.com/IwsDataServer/DeleteRecord' }
        'DeleteRecordByKey' { 'http://www.totvs.com/IwsDataServer/DeleteRecordByKey' }
        default { 'http://www.totvs.com/IwsDataServer/ReadRecord' }
    }
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
        throw 'Arquivo de configuração não encontrado. Crie rm.config.json ou rm.config.local.json.'
    }
}

if (-not (Test-Path $ConfigFile)) {
    throw "Arquivo de configuração não localizado: $ConfigFile"
}

$config = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
$serverUrl = if ($config.ApplicationServerUrl) { $config.ApplicationServerUrl } elseif ($config.ServerUrl) { $config.ServerUrl } else { throw 'Configuração sem ApplicationServerUrl/ServerUrl.' }
$dataServer = if ($config.DataServer) { $config.DataServer } elseif ($config.DataSource) { $config.DataSource } else { throw 'Configuração sem DataServer/DataSource.' }

if (-not $CredentialFile) {
    if ($config.Authentication -and $config.Authentication.CredentialFile) {
        $CredentialFile = Resolve-PathFromBase -Path $config.Authentication.CredentialFile -BasePath (Split-Path -Parent $ConfigFile)
    }
    elseif (Test-Path (Join-Path $PSScriptRoot 'rm.credentials.json')) {
        $CredentialFile = Join-Path $PSScriptRoot 'rm.credentials.json'
    }
}

if (-not $Method) {
    $Method = if ($config.HttpMethod) { $config.HttpMethod } elseif ($config.Method) { $config.Method } else { 'GET' }
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

$contentType = Get-PropertyValue -Object $config -Name 'ContentType' -Default 'text/xml; charset=utf-8'
$soapAction = Get-PropertyValue -Object $config -Name 'SoapAction'
if (-not $soapAction -and $Method -ne 'GET') {
    $soapAction = Get-DefaultSoapAction -Op $Operation
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
if (-not $headers.ContainsKey('Content-Type') -and -not $headers.ContainsKey('content-type')) {
    $headers['Content-Type'] = $contentType
}
if ($soapAction) {
    $headers['SOAPAction'] = '"' + $soapAction + '"'
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
    Operation = $Operation
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
            $response = Invoke-WebRequest -Uri $finalUrl -Method $Method -Headers $headers -Body $Body -ContentType $contentType -TimeoutSec $TimeoutSeconds
        }

        $stopwatch.Stop()
        $content = $response.Content

        $samplesDir = Join-Path $PSScriptRoot '..\samples'
        New-Item -ItemType Directory -Path $samplesDir -Force | Out-Null
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $responseFile = Join-Path $samplesDir ("rm-response-$Operation-$timestamp.txt")
        $content | Set-Content -Path $responseFile -Encoding UTF8

        [pscustomobject]@{
            Operation = $Operation
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
        $responseBody = ''
        $statusCode = ''

        if ($lastError.Exception -and $lastError.Exception.Response) {
            try {
                $stream = $lastError.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseBody = $reader.ReadToEnd()
                    $reader.Dispose()
                }
                $statusCode = [string]$lastError.Exception.Response.StatusCode
            }
            catch {}
        }

        Write-RmErrorLog -Operation $Operation -Url $finalUrl -Message $lastError.Exception.Message -ResponseBody $responseBody -StatusCode $statusCode

        if ($attempt -le $RetryCount) {
            Write-Warning "Tentativa $attempt/$($RetryCount + 1) falhou. Repetindo em 2 segundos..."
            Start-Sleep -Seconds 2
            continue
        }

        throw "Falha ao consultar Dataserver RM. Url: $finalUrl. Detalhes: $($lastError.Exception.Message)"
    }
}
