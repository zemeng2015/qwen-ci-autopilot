param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://127.0.0.1:8787",
    [Parameter(Mandatory = $false)]
    [string]$ProofFile = "deploy/alibaba/serverless-devs.yaml",
    [Parameter(Mandatory = $false)]
    [string]$Track = "Track 4: Autopilot Agent",
    [switch]$RequireLiveQwen
)

$ErrorActionPreference = "Stop"
$results = New-Object System.Collections.Generic.List[object]
$checks = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    baseUrl = $BaseUrl
    pass = $true
    checks = @()
}

function Add-Check {
    param([string]$name, [bool]$ok, [string]$details)
    $entry = [ordered]@{
        name = $name
        ok = $ok
        details = $details
    }
    $checks.checks += $entry
    if (-not $ok) {
        $checks.pass = $false
    }
}

try {
    $healthUrl = "$($BaseUrl.TrimEnd('/'))/api/health"
    $health = Invoke-RestMethod -Method Get -Uri $healthUrl -TimeoutSec 15
    Add-Check -name "health_endpoint_reachable" -ok $true -details "GET $healthUrl"
}
catch {
    Add-Check -name "health_endpoint_reachable" -ok $false -details $_.Exception.Message
    $checks | ConvertTo-Json -Depth 6 | Set-Content "artifacts/qwencloud-proof/submission-verify-$(Get-Date -Format yyyyMMdd-HHmmss).json"
    throw "Health endpoint check failed: $($_.Exception.Message)"
}

$trackExpected = $Track
Add-Check -name "track_declared" -ok (
    $null -ne $health.track -and $health.track -like "*Autopilot*"
) -details "track=$($health.track)"
Add-Check -name "proof_file_present" -ok (
    $health.proofFile -eq $ProofFile
) -details "proofFile=$($health.proofFile)"
Add-Check -name "qwen_model_present" -ok (
    [bool]$health.qwen.model
) -details "model=$($health.qwen.model)"
Add-Check -name "qwen_baseurl_present" -ok (
    [bool]$health.qwen.baseUrl
) -details "qwen.baseUrl=$($health.qwen.baseUrl)"

if ($RequireLiveQwen) {
    Add-Check -name "qwen_live_ready" -ok (
        [bool]$health.qwen.liveReady
    ) -details "qwen.liveReady=$($health.qwen.liveReady)"
}

try {
    $scenarioUrl = "$($BaseUrl.TrimEnd('/'))/api/scenarios"
    $scenarioResponse = Invoke-RestMethod -Method Get -Uri $scenarioUrl -TimeoutSec 15
    Add-Check -name "scenarios_endpoint" -ok (
        $null -ne $scenarioResponse.scenarios -and $scenarioResponse.scenarios.Count -ge 1
    ) -details "scenarios=$($scenarioResponse.scenarios.Count)"
}
catch {
    Add-Check -name "scenarios_endpoint" -ok $false -details $_.Exception.Message
}

New-Item -ItemType Directory -Path "artifacts/qwencloud-proof" -Force | Out-Null
$outFile = "artifacts/qwencloud-proof/submission-verify-$(Get-Date -Format yyyyMMdd-HHmmss).json"
$outFileObj = [ordered]@{
    generatedAt = $checks.generatedAt
    baseUrl = $checks.baseUrl
    pass = $checks.pass
    checks = $checks.checks
} | ConvertTo-Json -Depth 8
Set-Content -Path $outFile -Value $outFileObj -Encoding UTF8

$failed = $checks.checks | Where-Object { -not $_.ok }
if ($checks.pass) {
    Write-Host "Health and endpoint checks passed." -ForegroundColor Green
    Write-Host "Result: $outFile"
}
else {
    Write-Host "Submission verification has failed checks." -ForegroundColor Red
    Write-Host "Failed checks:"
    foreach ($item in $failed) {
        Write-Host " - $($item.name): $($item.details)" -ForegroundColor Red
    }
    Write-Host "Result: $outFile"
    exit 1
}
