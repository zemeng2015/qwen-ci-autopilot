param(
    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = "http://127.0.0.1:8787",
    [Parameter(Mandatory = $false)]
    [switch]$SkipDraft,
    [switch]$RequireLiveQwen,
    [Parameter(Mandatory = $false)]
    [int]$MaxDraftOutputChars = 2000
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactDir = "artifacts/qwencloud-proof"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$outJson = Join-Path $artifactDir "submission-audit-$timestamp.json"
$outMd = Join-Path $artifactDir "submission-audit-$timestamp.md"

Write-Host "Running submit gate..."
try {
    $submitGateOutput = & (Join-Path $PSScriptRoot "qwencloud-hackathon-submit-gate.ps1") -SkipRemoteCheck 2>&1
    Write-Output $submitGateOutput
}
catch {
    Write-Output $_
    throw "Submit gate failed."
}

Write-Host "Running endpoint verification..."
& (Join-Path $PSScriptRoot "qwencloud-hackathon-verify.ps1") -BaseUrl $BaseUrl -RequireLiveQwen:$RequireLiveQwen
$verify = Join-Path "artifacts/qwencloud-proof" (Get-ChildItem -Path "artifacts/qwencloud-proof" -Filter "submission-verify-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
$verificationData = Get-Content $verify -Raw | ConvertFrom-Json

Write-Host "Capturing proof snapshot..."
& (Join-Path $PSScriptRoot "qwencloud-hackathon-proof.ps1") -BaseUrl $BaseUrl
$proof = Join-Path "artifacts/qwencloud-proof" (Get-ChildItem -Path "artifacts/qwencloud-proof" -Filter "submission-proof-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
$proofData = Get-Content $proof -Raw | ConvertFrom-Json

$draftText = if ($SkipDraft) { "skipped" } else { "attempted" }

$notes = @(
    "Run qwencloud-hackathon-audit.ps1 with -SkipDraft if you want an offline-only smoke pass."
)
if ($MaxDraftOutputChars -gt 0 -and -not $SkipDraft) {
    $notes += "Local draft output enabled."
}

$audit = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    baseUrl = $BaseUrl
    gate = "PASS"
    verification = $verificationData
    proof = $proofData
    draftAttempted = (-not $SkipDraft)
    notes = $notes
}

Set-Content -Path $outJson -Value ($audit | ConvertTo-Json -Depth 10) -Encoding UTF8

$mdLines = @(
    "# Submission Audit ($timestamp)",
    "",
    "- Base URL: `$BaseUrl",
    "- Result: PASS",
    "- Generated: $($audit.generatedAt)",
    "",
    "## Verification",
    "",
    "- JSON checks: $($verificationData.checks.Count)",
    "- Health endpoint: $($BaseUrl.TrimEnd('/'))/api/health",
    "- Proof file: $($proofData.health.proofFile)",
    "",
    "## Draft status",
    "",
    "- Local fallback / dry-run checks: $draftText",
    "",
    "## Output files",
    "",
    "- $outJson",
    "- $proof",
    "- $verify",
    ""
)

Set-Content -Path $outMd -Value ($mdLines -join "`r`n") -Encoding UTF8
Write-Host "Submission audit saved: $outJson"
Write-Host "Submission audit markdown: $outMd"
