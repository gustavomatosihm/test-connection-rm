[CmdletBinding()]
param(
    [int]$Cycles = 5
)

$scriptDir = $PSScriptRoot
$logFile = Join-Path $scriptDir 'rm-crud-validation.log'
$errorLogFile = Join-Path $scriptDir 'rm-crud-errors.log'

# Atualizar configs operacionais a partir de rm.config.json
& (Join-Path $scriptDir 'sync-rm-configs.ps1')

# Garante UTF-8 no console do processo atual e nos processos filhos
if ([Console]::OutputEncoding.CodePage -ne 65001) {
    & cmd /c chcp 65001 | Out-Null
}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = "1"

$results = @()

for ($i = 1; $i -le $Cycles; $i++) {
    Write-Host "=== Ciclo $i/$Cycles ==="
    try {
        & (Join-Path $scriptDir 'test-rm-crud.ps1') -LogFile $logFile -ErrorLogFile $errorLogFile
        $results += [PSCustomObject]@{ Ciclo = $i; Status = "OK"; Erro = "" }
    } catch {
        $results += [PSCustomObject]@{ Ciclo = $i; Status = "ERRO"; Erro = $_.Exception.Message }
        Write-Host "ERRO capturado no ciclo $i, continuando..."
    }
}

Write-Host ""
Write-Host "=== RESUMO ==="
$results | Format-Table -AutoSize
Write-Host "Total: $Cycles | Sucesso: $(($results | Where-Object { $_.Status -eq 'OK' }).Count) | Erros: $(($results | Where-Object { $_.Status -eq 'ERRO' }).Count)"

Write-Host ""
Write-Host "=== rm-crud-validation.log (ultimas $($Cycles * 6) linhas) ==="
if (Test-Path $logFile) { Get-Content $logFile | Select-Object -Last ($Cycles * 6) } else { Write-Host "(vazio)" }

Write-Host ""
Write-Host "=== rm-crud-errors.log ==="
if (Test-Path $errorLogFile) { Get-Content $errorLogFile } else { Write-Host "(vazio)" }
