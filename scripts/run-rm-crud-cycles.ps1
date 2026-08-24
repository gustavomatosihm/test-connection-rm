[CmdletBinding()]
param(
    [int]$Cycles = 5,
    [int]$Parallel = 1
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

if ($Parallel -le 1) {
    # Execucao sequencial (comportamento original)
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
} else {
    # Execucao paralela com Start-Job
    Write-Host "Iniciando $Cycles ciclos em paralelo ($Parallel simultaneos)..."
    $jobs = @()

    for ($i = 1; $i -le $Cycles; $i++) {
        $jobLogFile    = Join-Path $scriptDir "rm-crud-validation-job-$i.log"
        $jobErrorFile  = Join-Path $scriptDir "rm-crud-errors-job-$i.log"
        $cycleNum      = $i
        $testScript    = Join-Path $scriptDir 'test-rm-crud.ps1'

        $job = Start-Job -ScriptBlock {
            param($script, $log, $errLog, $cycle)
            try {
                & $script -LogFile $log -ErrorLogFile $errLog
                [PSCustomObject]@{ Ciclo = $cycle; Status = "OK"; Erro = "" }
            } catch {
                [PSCustomObject]@{ Ciclo = $cycle; Status = "ERRO"; Erro = $_.Exception.Message }
            }
        } -ArgumentList $testScript, $jobLogFile, $jobErrorFile, $cycleNum

        $jobs += [PSCustomObject]@{ Job = $job; Ciclo = $i; LogFile = $jobLogFile; ErrorFile = $jobErrorFile }
        Write-Host "  Job iniciado: Ciclo $i (JobId=$($job.Id))"

        # Aguardar se atingiu o limite de paralelos
        while (($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $Parallel) {
            Start-Sleep -Milliseconds 500
        }
    }

    Write-Host "Aguardando todos os jobs finalizarem..."
    $jobs | ForEach-Object { Wait-Job -Job $_.Job | Out-Null }

    # Coletar resultados e consolidar logs
    foreach ($entry in $jobs | Sort-Object { $_.Ciclo }) {
        $result = Receive-Job -Job $entry.Job
        Remove-Job -Job $entry.Job

        if ($result) {
            $results += [PSCustomObject]@{ Ciclo = $result.Ciclo; Status = $result.Status; Erro = $result.Erro }
        }

        # Consolidar logs temporarios nos arquivos principais
        if (Test-Path $entry.LogFile) {
            Get-Content $entry.LogFile | Add-Content -Path $logFile -Encoding UTF8
            Remove-Item $entry.LogFile -Force
        }
        if (Test-Path $entry.ErrorFile) {
            Get-Content $entry.ErrorFile | Add-Content -Path $errorLogFile -Encoding UTF8
            Remove-Item $entry.ErrorFile -Force
        }
    }
}

Write-Host ""
Write-Host "=== RESUMO ==="
if ($Parallel -gt 1) { Write-Host "Modo: $Parallel ciclos simultaneos" }
$results | Sort-Object Ciclo | Format-Table -AutoSize
Write-Host "Total: $Cycles | Sucesso: $(($results | Where-Object { $_.Status -eq 'OK' }).Count) | Erros: $(($results | Where-Object { $_.Status -eq 'ERRO' }).Count)"

Write-Host ""
Write-Host "=== rm-crud-validation.log (ultimas $($Cycles * 6) linhas) ==="
if (Test-Path $logFile) { Get-Content $logFile | Select-Object -Last ($Cycles * 6) } else { Write-Host "(vazio)" }

Write-Host ""
Write-Host "=== rm-crud-errors.log ==="
if (Test-Path $errorLogFile) { Get-Content $errorLogFile } else { Write-Host "(vazio)" }
