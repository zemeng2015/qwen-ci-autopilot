param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://127.0.0.1:8787",
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "artifacts/qwencloud-proof",
    [switch]$RawOnly
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$proofFile = Join-Path $OutputDir "submission-proof-$timestamp.json"
$readmeFile = Join-Path $OutputDir "submission-proof-$timestamp.md"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

try {
    $health = Invoke-RestMethod -Method Get -Uri "$($BaseUrl.TrimEnd('/'))/api/health" -TimeoutSec 20
}
catch {
    throw "Unable to fetch health endpoint: $($_.Exception.Message)"
}

$evidence = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    baseUrl = $BaseUrl
    proofType = "qwencloud-hackathon-alibaba-health-proof"
    health = $health
    requiredFields = @{
        proofFile = $true
        deploymentTarget = $true
        region = $true
        qwenModel = $true
        qwenLiveReady = $true
    }
}

Set-Content -Path $proofFile -Value ($evidence | ConvertTo-Json -Depth 12) -Encoding UTF8

if (-not $RawOnly) {
    $mdLines = @(
        "# Deployment Proof Snapshot ($timestamp)",
        "",
        "**Base URL:** $BaseUrl",
        "**Generated:** $($evidence.generatedAt)",
        "",
        "## Health response check",
        "",
        "```json",
        ($health | ConvertTo-Json -Depth 8),
        "```",
        "",
        "## Deployment metadata",
        "",
        "- Service: $($health.service)",
        "- Deployment target: $($health.deploymentTarget)",
        "- Region: $($health.region)",
        "- Qwen model: $($health.qwen.model)",
        "- Qwen base URL: $($health.qwen.baseUrl)",
        "- Live ready: $($health.qwen.liveReady)",
        "- Proof file in repo: $($health.proofFile)",
        "",
        "## Repo proof file link",
        "",
        "$($health.proofFile)",
        "",
        "## Testing endpoint",
        "",
        "- Health endpoint: $($BaseUrl.TrimEnd('/'))/api/health",
        "- Scenarios endpoint: $($BaseUrl.TrimEnd('/'))/api/scenarios"
    )
    Set-Content -Path $readmeFile -Value ($mdLines -join "`r`n") -Encoding UTF8
}

Write-Host "Deployment proof written: $proofFile"
if (-not $RawOnly) {
    Write-Host "Deployment proof markdown written: $readmeFile"
}
