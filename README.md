# Investigação de Connection Reset e Instabilidades - Totvs RM

Este repositório foi criado para centralizar a investigação de problemas de **connection reset** e demais instabilidades nos webservices/API do Totvs RM.

## Objetivo

Mapear, reproduzir, analisar e documentar falhas de conectividade e comportamento intermitente, criando uma base técnica para diagnóstico e mitigação.

## Contexto

Problemas de comunicação com serviços do Totvs RM podem se manifestar como quedas de conexão, timeouts e respostas inconsistentes. A proposta deste projeto é organizar evidências técnicas (logs, amostras e análises) e apoiar a construção de hipóteses e testes de validação.

## Estrutura proposta

- `docs/`: documentação de ocorrências, logs coletados, hipóteses e análises.
- `scripts/`: scripts de diagnóstico e testes de conectividade.
- `samples/`: exemplos de requisições e respostas problemáticas para referência e reprodução.

## Fluxo sugerido de investigação

1. Registrar a ocorrência no template de investigação (`docs/investigation.md`).
2. Coletar evidências (logs, payloads, horário, endpoint e contexto).
3. Executar scripts de teste para tentativa de reprodução.
4. Consolidar achados, hipóteses e próximos passos em `docs/`.

## Diagnóstico rápido do Dataserver RM

Para testar conectividade em diferentes ambientes sem alterar o código, use o script de diagnóstico em `scripts/test-rm-dataserver.ps1` combinado com um arquivo de configuração local.

### Observação importante sobre o endpoint

Os DataServers RM normalmente não são consumidos como `GET` direto em `http://servidor:8054/PrjIsmData`. A arquitetura documentada pela TOTVS expõe o WebService do RM por meio do Host, geralmente na porta HTTP do Host (ex.: `8051`) e via SOAP/XML com autenticação Basic. O endpoint do servidor de aplicação (`8054`) pode ser um serviço diferente e não o WS do DataServer em si.

### 1) Configuração

Ajuste `scripts/rm.config.json` ou crie `scripts/rm.config.local.json` com a URL do Host e o payload SOAP de teste:

```json
{
  "ApplicationServerUrl": "http://srvbhz16:8051",
  "DataServer": "PrjIsmData",
  "HttpMethod": "POST",
  "RelativePath": "wsDataServer",
  "TimeoutSeconds": 30,
  "RetryCount": 2,
  "SoapAction": "",
  "ContentType": "text/xml; charset=utf-8",
  "Authentication": {
    "Type": "Basic",
    "Username": "CHANGE_ME",
    "CredentialFile": ".\\rm.credentials.json"
  },
  "RequestBody": "<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:tem=\"http://www.totvs.com/\"><soap:Body><tem:ReadRecord><tem:DataServerName>PrjIsmData</tem:DataServerName><tem:PrimaryKey>CHAVE_DO_REGISTRO</tem:PrimaryKey><tem:Contexto></tem:Contexto></tem:ReadRecord></soap:Body></soap:Envelope>"
}
```

### Validação no navegador

Antes de chamar o serviço pelo script, teste no navegador estas URLs do Host:

- `http://srvbhz16:8051/wsPageIndex`
- `http://srvbhz16:8051/wsDataServer`
- `http://srvbhz16:8051/wsDataServer/MEX?wsdl`

Se a URL `wsDataServer`/`MEX?wsdl` responder corretamente, significa que o Host está publicando o WebService do RM na porta `8051` e o script deve ser executado no endpoint SOAP exposto no WSDL, não em `http://srvbhz16:8054/PrjIsmData`.

O WSDL publicado pelo Host aponta para o endereço SOAP real:

- `http://srvbhz16.ihm.local:8051/wsDataServer/IwsDataServer`

Ou seja, o `RelativePath` correto para a chamada SOAP do Dataserver é:

- `wsDataServer/IwsDataServer`

> Em ambientes reais, o valor exato do `RelativePath` e do `SoapAction` depende do WSDL publicado pelo Host. O ajuste pode ser necessário para a rota exata do serviço exposto (por exemplo, `wsPageIndex`, `wsDataServer`, `wsDataServer/IwsDataServer` ou `wsReport`).

### 2) Guardar credencial criptografada

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\set-rm-credential.ps1
```

Isso salva a senha em `scripts/rm.credentials.json` criptografada para o usuário atual do Windows, sem expor a senha em variáveis de ambiente.

### 3) Testar conexão

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-rm-dataserver.ps1 -ConfigFile .\scripts\rm.config.local.json
```

Se quiser apenas validar a montagem da URL e a configuração antes de chamar o serviço:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-rm-dataserver.ps1 -ShowConfigOnly
```

O script grava a resposta em `samples/` para comparar falhas entre ambientes.
