# Registro de Ocorrências - Investigation Log

Use este template para registrar cada ocorrência investigada.

## Data/Hora
- Data:
- Hora:
- Fuso horário:

## Endpoint afetado
- Serviço/API:
- URL/rota:
- Método HTTP:

## Tipo de erro
- Sintoma (ex.: connection reset, timeout, resposta inválida):
- Código/stack (se aplicável):

## Passos para reproduzir
1.
2.
3.

## Logs relevantes
- Origem do log (aplicação, gateway, servidor, cliente):
- Trechos principais:

```text
[cole aqui os trechos relevantes]
```

## Evidências adicionais
- Payload de requisição (se aplicável):
- Payload de resposta (se aplicável):
- Janela de ocorrência:

## Hipóteses iniciais
- 

## Ações executadas
- 

## Resultado parcial
- 

## Próximos passos
- 

---

# Ocorrência #1: Validação CRUD Completa - PrjIsmData

## Data/Hora
- Data: 2026-08-21
- Hora: 14:51-14:52 (BRT)
- Fuso horário: America/Sao_Paulo (BRT -03:00)

## Endpoint afetado
- Serviço/API: TOTVS RM DataServer WebService
- URL/rota: http://srvbhz16:8051/wsDataServer/IwsDataServer
- Método HTTP: POST (SOAP 1.1)
- DataServer: PrjIsmData

## Tipo de erro
- Sintoma: Nenhum - validação bem-sucedida de todas operações CRUD
- Status: ✅ Funcionando normalmente

## Passos para reproduzir
1. Executar operação READ em registro existente (1;27056;4875985)
2. Executar operação UPDATE alterando DESCISM com timestamp
3. Executar operação CREATE com IDISM=-1 (auto-geração de chave)
4. Executar operação DELETE na chave recém-criada

## Logs relevantes
- Origem do log: Scripts PowerShell + RM DataServer
- Arquivo: docs/logs/rm-errors.log (sem erros registrados nesta execução)

## Evidências adicionais

### 1. READ Operation
- Chave testada: `1;27056;4875985`
- Status HTTP: **200 OK**
- Resposta: XML estruturado com dados do registro
- Exemplo de dados retornados:
  ```xml
  <PrjIsm>
    <MIsm>
      <CODCOLIGADA>1</CODCOLIGADA>
      <IDPRJ>27056</IDPRJ>
      <IDISM>4875985</IDISM>
      <CODISM>015.0400.00001</CODISM>
      <DESCISM>ATUALIZADO-20260821-145117</DESCISM>
      <CODUND>UN</CODUND>
      <GRUPODNER>C</GRUPODNER>
      <IDGIS>47161</IDGIS>
    </MIsm>
  </PrjIsm>
  ```

### 2. UPDATE Operation
- Chave testada: `1;27056;4875985` (IDISM existente)
- Campo alterado: DESCISM → "ATUALIZADO-20260821-145117"
- Status HTTP: **200 OK**
- Resposta (SaveRecordResult): `1;27056;4875985` (confirmação da chave atualizada)

### 3. CREATE Operation
- Chave entrada: IDISM = `-1` (novo registro)
- CODISM: `TESTE-20260821-145130`
- DESCISM: `NOVO REGISTRO TESTE`
- Status HTTP: **200 OK**
- Resposta (SaveRecordResult): **`1;27056;6743971`** (chave auto-gerada pelo servidor)
- Campos obrigatórios preenchidos: CODCOLIGADA, IDPRJ, CODISM, DESCISM, CODUND, GRUPODNER, IDGIS

### 4. DELETE Operation
- Chave testada: `1;27056;6743971` (chave recém-criada)
- Status HTTP: **200 OK**
- Resposta (DeleteRecordByKeyResult): "Exclusão de registro(s) realizado com sucesso"

## Hipóteses iniciais
- ✅ CRUD funciona corretamente via SOAP
- ✅ Autenticação Basic Auth está operacional
- ✅ Geração automática de chaves (IDISM) pelo servidor funciona
- ⚠️ Connection Reset observado anteriormente pode ser intermitente ou relacionado a timeouts longos

## Ações executadas
1. Executado ReadRecord para validar recuperação de dados existentes
2. Executado SaveRecord em modo UPDATE (IDISM existente) com alteração em DESCISM
3. Executado SaveRecord em modo CREATE (IDISM=-1) para gerar novo registro
4. Executado DeleteRecordByKey para remover registro de teste
5. Todas operações com timestamp para rastreabilidade de alterações

## Resultado parcial
- ✅ READ: Funcional - retorna XML estruturado
- ✅ UPDATE: Funcional - altera registro existente
- ✅ CREATE: Funcional - gera novo registro com chave automática
- ✅ DELETE: Funcional - exclui registros com sucesso
- **Status geral: CRUD 100% operacional**

## Próximos passos
- [ ] Validar mudanças no banco de dados (confrontar valores de DESCISM e chave de CREATE)
- [ ] Investigar padrão de connection reset (intermitência, timing, causas)
- [ ] Implementar retry logic automático em script de produção
- [ ] Analisar logs do servidor RM para possíveis gargalos ou timeouts
- [ ] Documentar melhorias na tratativa de exceções SOAP
