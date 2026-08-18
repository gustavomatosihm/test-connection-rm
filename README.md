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
