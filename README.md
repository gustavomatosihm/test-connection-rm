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

### 1) Configuração

Ajuste `scripts/rm.config.json` ou crie `scripts/rm.config.local.json` com o endereço do servidor de aplicação e o Dataserver de teste:

```json
{
  "ApplicationServerUrl": "http://srvbhz16:8054",
  "DataServer": "PrjIsmData",
  "HttpMethod": "GET",
  "RelativePath": "",
  "TimeoutSeconds": 30,
  "RetryCount": 2,
  "Authentication": {
    "Type": "Basic",
    "Username": "CHANGE_ME",
    "CredentialFile": ".\\rm.credentials.json"
  }
}
```

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
