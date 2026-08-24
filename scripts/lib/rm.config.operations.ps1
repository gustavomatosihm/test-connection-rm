# Operações CRUD - Bodies SOAP template (sem servidor hardcoded)
# Importar com: . .\rm.config.operations.ps1

$OPERATIONS = @{
    CREATE = @{
        SoapAction = 'http://www.totvs.com/IwsDataServer/SaveRecord'
        Body = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://www.totvs.com/"><soap:Body><tem:SaveRecord><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:XML><![CDATA[<PrjIsm><MIsm><CODCOLIGADA>1</CODCOLIGADA><IDPRJ>27056</IDPRJ><IDISM>-1</IDISM><CODISM>TESTE-20260821-180641</CODISM><DESCISM>NOVO REGISTRO TESTE</DESCISM><CODUND>UN</CODUND><GRUPODNER>C</GRUPODNER><IDGIS>47161</IDGIS></MIsm></PrjIsm>]]></tem:XML><tem:Contexto></tem:Contexto></tem:SaveRecord></soap:Body></soap:Envelope>'
    }
    READ = @{
        SoapAction = 'http://www.totvs.com/IwsDataServer/ReadRecord'
        Body = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://www.totvs.com/"><soap:Body><tem:ReadRecord><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:PrimaryKey>1;27056;4875985</tem:PrimaryKey><tem:Contexto></tem:Contexto></tem:ReadRecord></soap:Body></soap:Envelope>'
    }
    DELETE = @{
        SoapAction = 'http://www.totvs.com/IwsDataServer/DeleteRecordByKey'
        Body = '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:tem="http://www.totvs.com/"><soap:Body><tem:DeleteRecordByKey><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:PrimaryKey>1;27056;6744059</tem:PrimaryKey><tem:Contexto></tem:Contexto></tem:DeleteRecordByKey></soap:Body></soap:Envelope>'
    }
}

function Build-OperationConfig {
    param(
        [string]$OperationType,
        [hashtable]$BaseConfig
    )
    
    if (-not $OPERATIONS[$OperationType]) {
        throw "Operação desconhecida: $OperationType"
    }
    
    $op = $OPERATIONS[$OperationType]
    
    return @{
        ApplicationServerUrl = $BaseConfig.Connection.Url
        DataServer = $BaseConfig.DataServer
        HttpMethod = 'POST'
        RelativePath = $BaseConfig.RelativePath
        TimeoutSeconds = $BaseConfig.TimeoutSeconds
        RetryCount = $BaseConfig.RetryCount
        SoapAction = $op.SoapAction
        ContentType = $BaseConfig.ContentType
        Headers = $BaseConfig.Headers
        Authentication = $BaseConfig.Authentication
        RequestBody = $op.Body
    }
}
