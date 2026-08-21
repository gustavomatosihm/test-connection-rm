[CmdletBinding()]
param(
    [string]$ReadConfigFile = "",
    [string]$CreateConfigFile = "",
    [string]$DeleteConfigFile = "",
    [string]$LogFile = "",
    [string]$ErrorLogFile = "",
    [int]$RetryCount = 2,
    [int]$RetryDelaySeconds = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = $PSScriptRoot

function Get-XmlDecodedContent {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $Content }
    return [System.Net.WebUtility]::HtmlDecode($Content)
}

function Extract-TagValue {
    param([string]$Content, [string]$TagName)
    $decoded = Get-XmlDecodedContent -Content $Content
    $match = [regex]::Match($decoded, "<$TagName>(.*?)</$TagName>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { throw "Não foi possível localizar <$TagName>." }
    return $match.Groups[1].Value.Trim()
}

function Extract-ReadField {
    param([string]$Content, [string]$TagName)
    $decoded = Get-XmlDecodedContent -Content $Content
    $match = [regex]::Match($decoded, "<$TagName>(.*?)</$TagName>", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { throw "Não foi possível localizar <$TagName>." }
    return $match.Groups[1].Value.Trim()
}

function Invoke-RmWebRequest {
    param(
        [string]$ConfigFile,
        [string]$OverrideSoapAction = "",
        [string]$OverrideBody = ""
    )

    $cfg = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json
    $url = $cfg.ApplicationServerUrl.TrimEnd('/') + '/' + $cfg.RelativePath.Trim('/')
    $headers = @{}
    foreach ($h in $cfg.Headers) {
        if ($h.Name) { $headers[$h.Name] = $h.Value }
    }
    if (-not $headers.ContainsKey('Accept')) { $headers['Accept'] = 'text/xml' }

    $soapAction = if ($OverrideSoapAction) { $OverrideSoapAction } else { $cfg.SoapAction }
    if ($soapAction) { $headers['SOAPAction'] = '"' + $soapAction + '"' }

    $credFile = $cfg.Authentication.CredentialFile
    if (-not [System.IO.Path]::IsPathRooted($credFile)) {
        $credFile = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $ConfigFile) $credFile))
    }
    $cred = Get-Content -Raw -Path $credFile | ConvertFrom-Json
    $pair = "$($cred.Username):$($cred.Password)"
    $headers['Authorization'] = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))

    $body = if ($OverrideBody) { $OverrideBody } else { $cfg.RequestBody }

    $maxAttempts = $RetryCount + 1
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -Body $body -ContentType $cfg.ContentType -TimeoutSec $cfg.TimeoutSeconds
            if ($attempt -gt 1) {
                $msg = "attempt=$attempt url=$url"
                Write-LogEntry -Path $ErrorLogFile -Title 'RETRY_RECOVERED' -Body $msg
            }
            return $response.Content
        } catch [System.Net.WebException] {
            $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            $errMsg = "HTTP_ERROR status=$statusCode url=$url msg=$($_.Exception.Message)"
        } catch {
            $errMsg = "CONNECTION_ERROR url=$url msg=$($_.Exception.Message)"
        }

        Write-LogEntry -Path $ErrorLogFile -Title "RETRY" -Body "attempt=$attempt/$maxAttempts $errMsg"

        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    throw [System.Exception]::new($errMsg)
}

function New-RuntimeConfig {
    param([string]$SourceFile, [string]$DestinationFile, [scriptblock]$Mutator)
    $cfg = Get-Content -Raw -Path $SourceFile | ConvertFrom-Json
    & $Mutator $cfg
    $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $DestinationFile -Encoding UTF8
}

function Build-UpdateBody {
    param([string]$ReadXml, [string]$NewDescription)
    $xml = Get-XmlDecodedContent -Content $ReadXml
    $xml = $xml -replace '<DESCISM>.*?</DESCISM>', "<DESCISM>$NewDescription</DESCISM>"
    return '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://www.totvs.com/"><soap:Body><tem:SaveRecord><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:XML><![CDATA[' + $xml + ']]></tem:XML><tem:Contexto></tem:Contexto></tem:SaveRecord></soap:Body></soap:Envelope>'
}

function Write-LogEntry {
    param(
        [string]$Path,
        [string]$Title,
        [string]$Body
    )

    $entry = "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffK')] ${Title}: $Body"
    Add-Content -Path $Path -Value $entry -Encoding UTF8
}

if (-not $ReadConfigFile) { $ReadConfigFile = Join-Path $scriptDir 'rm.config.read.json' }
if (-not $CreateConfigFile) { $CreateConfigFile = Join-Path $scriptDir 'rm.config.create.json' }
if (-not $DeleteConfigFile) { $DeleteConfigFile = Join-Path $scriptDir 'rm.config.delete.json' }
if (-not $LogFile) { $LogFile = Join-Path $scriptDir 'rm-crud-validation.log' }
if (-not $ErrorLogFile) { $ErrorLogFile = Join-Path $scriptDir 'rm-crud-errors.log' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$tempCreate = Join-Path $scriptDir 'rm.config.create.runtime.json'
$tempReadCreate = Join-Path $scriptDir 'rm.config.read-create.runtime.json'
$tempReadUpdate = Join-Path $scriptDir 'rm.config.read-update.runtime.json'
$tempDelete = Join-Path $scriptDir 'rm.config.delete.runtime.json'

try {
    New-RuntimeConfig -SourceFile $CreateConfigFile -DestinationFile $tempCreate -Mutator {
        param($cfg)
        $cfg.RequestBody = $cfg.RequestBody -replace 'TESTE-\d{8}-\d{6}', "TESTE-$stamp"
    }
    $createContent = Invoke-RmWebRequest -ConfigFile $tempCreate
    $createKey = Extract-TagValue -Content $createContent -TagName 'SaveRecordResult'
    Write-LogEntry -Path $LogFile -Title 'CREATE' -Body $createKey

    New-RuntimeConfig -SourceFile $ReadConfigFile -DestinationFile $tempReadCreate -Mutator {
        param($cfg)
        $cfg.RequestBody = $cfg.RequestBody -replace '1;27056;4875985', $createKey
    }
    $verifyCreateContent = Invoke-RmWebRequest -ConfigFile $tempReadCreate
    Write-LogEntry -Path $LogFile -Title 'READ AFTER CREATE' -Body ("IDISM=" + (Extract-ReadField -Content $verifyCreateContent -TagName 'IDISM'))
    if ((Extract-ReadField -Content $verifyCreateContent -TagName 'IDISM') -ne ($createKey.Split(';')[-1])) {
        throw 'A validação do novo registro falhou.'
    }

    $updateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $previousDescription = Extract-ReadField -Content $verifyCreateContent -TagName 'DESCISM'
    $updateDescription = "UPDATE-TESTE-$updateStamp"
    $updateBody = Build-UpdateBody -ReadXml $verifyCreateContent -NewDescription $updateDescription
    $updateContent = Invoke-RmWebRequest -ConfigFile $ReadConfigFile -OverrideSoapAction 'http://www.totvs.com/IwsDataServer/SaveRecord' -OverrideBody $updateBody
    Write-LogEntry -Path $LogFile -Title 'UPDATE' -Body ("FROM=" + $previousDescription + " TO=" + $updateDescription)
    if ($updateContent -notlike "*$createKey*") {
        throw "A atualização retornou chave diferente. Esperado: $createKey. Obtido: $updateContent"
    }

    New-RuntimeConfig -SourceFile $ReadConfigFile -DestinationFile $tempReadUpdate -Mutator {
        param($cfg)
        $cfg.RequestBody = $cfg.RequestBody -replace '1;27056;4875985', $createKey
    }
    $verifyUpdateContent = Invoke-RmWebRequest -ConfigFile $tempReadUpdate
    Write-LogEntry -Path $LogFile -Title 'READ AFTER UPDATE' -Body ("DESCISM=" + (Extract-ReadField -Content $verifyUpdateContent -TagName 'DESCISM'))
    if ((Extract-ReadField -Content $verifyUpdateContent -TagName 'DESCISM') -notlike "*$updateDescription*") {
        throw 'A validação da atualização falhou.'
    }

    New-RuntimeConfig -SourceFile $DeleteConfigFile -DestinationFile $tempDelete -Mutator {
        param($cfg)
        $cfg.RequestBody = $cfg.RequestBody -replace '1;27056;6744059', $createKey
    }
    $deleteContent = Invoke-RmWebRequest -ConfigFile $tempDelete
    Write-LogEntry -Path $LogFile -Title 'DELETE' -Body $createKey

    $verifyDeleteContent = Invoke-RmWebRequest -ConfigFile $tempReadUpdate
    Write-LogEntry -Path $LogFile -Title 'READ AFTER DELETE' -Body ("FOUND=" + ((Get-XmlDecodedContent -Content $verifyDeleteContent) -like "*$createKey*"))
    if ((Get-XmlDecodedContent -Content $verifyDeleteContent) -like "*$createKey*") {
        throw 'A validação da exclusão falhou.'
    }

    [Console]::WriteLine('CRUD executado com sucesso (validado por ReadRecord).')
} catch {
    Write-LogEntry -Path $ErrorLogFile -Title 'CYCLE_ERROR' -Body $_.Exception.Message
        [Console]::WriteLine("ERRO no ciclo: $($_.Exception.Message)")
    throw
} finally {
    Remove-Item -Path $tempCreate, $tempReadCreate, $tempReadUpdate, $tempDelete -Force -ErrorAction SilentlyContinue
}
