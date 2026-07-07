param(
    [Parameter(Mandatory = $false)]
    [string]$RepoUrl = "",
    [Parameter(Mandatory = $false)]
    [string]$DemoVideoUrl = "",
    [Parameter(Mandatory = $false)]
    [string]$BackendUrl = "http://127.0.0.1:8787",
    [Parameter(Mandatory = $false)]
    [string]$Track = "Track 4: Autopilot Agent",
    [switch]$RequireRemoteVisibility
)

$ErrorActionPreference = "Stop"
$projectRoot = (Get-Location).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactDir = Join-Path $projectRoot "artifacts/qwencloud-proof"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$packetJson = Join-Path $artifactDir "submission-packet-$timestamp.json"
$packetMd = Join-Path $artifactDir "submission-packet-$timestamp.md"

$requiredPaths = @(
    "README.md",
    "LICENSE",
    "package.json",
    "server/index.ts",
    "server/orchestrator.ts",
    "server/qwenClient.ts",
    "server/localTools.ts",
    "server/scenarios.ts",
    "src/App.tsx",
    "docs/devpost-submission.md",
    "docs/devpost-copy-paste-template.md",
    "docs/architecture.md",
    "docs/architecture.svg",
    "docs/deployment/alibaba-cloud.md",
    "deploy/alibaba/serverless-devs.yaml",
    "scripts/qwencloud-deploy-preflight.ps1",
    "scripts/qwencloud-hackathon-audit.ps1",
    "scripts/qwencloud-hackathon-proof.ps1",
    "scripts/qwencloud-hackathon-verify.ps1",
    "scripts/qwencloud-hackathon-submit-gate.ps1",
    "scripts/qwencloud-hackathon-submission-packet.ps1",
    "artifacts/remediation-plan.md",
    "artifacts/patch-intent.diff",
    "artifacts/verification-evidence.json"
)

$checks = @()
$ready = $true
$notes = [System.Collections.Generic.List[string]]::new()

function Add-Check([string]$name, [bool]$ok, [string]$details) {
    $script:checks += [ordered]@{
        name = $name
        ok = $ok
        details = $details
    }
    if (-not $ok) {
        $script:ready = $false
    }
}

function IsPublicGitHubRepo([string]$url) {
    if ($url -notmatch "github\.com[:/][^/]+/[^/.]+(?:\.git)?$") {
        return $false
    }
    $clean = $url -replace "\.git$", ""
    if ($clean -match "github\.com[:/]([^/]+)/([^/]+)$") {
        $owner = $matches[1]
        $repo = $matches[2]
        try {
            $repoData = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo" -UserAgent "codex-hackathon-packet/1.0" -TimeoutSec 15
            return (-not [bool]$repoData.private)
        }
        catch {
            return $false
        }
    }
    return $false
}

function IsLikelyVideoUrl([string]$url) {
    return [bool]($url -match "https?://(www\.)?(youtube\.com|youtu\.be|vimeo\.com|youku\.com)")
}

$repoUsed = $RepoUrl
if ([string]::IsNullOrWhiteSpace($repoUsed) -and (Test-Path ".git")) {
    try {
        $origin = & git remote get-url origin 2>$null
        if ($origin) {
            $repoUsed = $origin
            $notes.Add("Repo URL was taken from local git origin.")
        }
    }
    catch {
        # no-op, keep fallback empty
    }
}

foreach ($path in $requiredPaths) {
    Add-Check -name "required_path.$path" -ok (Test-Path $path) -details $path
}

if (Test-Path "LICENSE") {
    $licenseText = Get-Content "LICENSE" -Raw
    Add-Check -name "license_detectable" -ok ($licenseText -match "MIT|Apache|BSD|GPL|MPL|ISC") -details "Detected open source license text."
}
else {
    Add-Check -name "license_detectable" -ok $false -details "LICENSE file missing"
}

if ([string]::IsNullOrWhiteSpace($repoUsed)) {
    Add-Check -name "repo_url_present" -ok $false -details "Provide -RepoUrl or configure git origin."
}
else {
    Add-Check -name "repo_url_present" -ok $true -details "repo=$repoUsed"
}

if ($repoUsed -and $repoUsed -like "*github.com*") {
    if ($RequireRemoteVisibility) {
        Add-Check -name "repo_url_visibility" -ok (IsPublicGitHubRepo $repoUsed) -details "GitHub API public check for $repoUsed"
    }
    else {
        Add-Check -name "repo_url_visibility" -ok $true -details "Skipped unless -RequireRemoteVisibility is set."
    }
}
elseif ($repoUsed) {
    Add-Check -name "repo_url_visibility" -ok $true -details "Non-GitHub repository URL; visibility auto-check skipped."
}

if ([string]::IsNullOrWhiteSpace($DemoVideoUrl)) {
    Add-Check -name "video_url_present" -ok $false -details "Provide -DemoVideoUrl (YouTube/Vimeo/Youku, <=3:00) for submission."
}
else {
    $videoLooksGood = IsLikelyVideoUrl $DemoVideoUrl
    Add-Check -name "video_url_present" -ok $videoLooksGood -details $DemoVideoUrl
}

try {
    & (Join-Path $PSScriptRoot "qwencloud-hackathon-submit-gate.ps1") | Out-Null

    $latestGatePath = Get-ChildItem -Path $artifactDir -Filter "submission-gate-*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $latestGateFile = $latestGatePath.FullName
    if ($latestGatePath -and (Test-Path $latestGateFile)) {
        Add-Check -name "local_submit_gate" -ok $true -details "Generated: $latestGateFile"
    }
    else {
        Add-Check -name "local_submit_gate" -ok $false -details "Submit gate output file not found."
    }
}
catch {
    Add-Check -name "local_submit_gate" -ok $false -details $_.Exception.Message
}

try {
    $health = Invoke-RestMethod -Method Get -Uri "$($BackendUrl.TrimEnd('/'))/api/health" -TimeoutSec 20
    Add-Check -name "backend_health" -ok $true -details "GET $($BackendUrl.TrimEnd('/'))/api/health"
    Add-Check -name "backend_track" -ok (
        $null -ne $health.track -and $health.track -like "*Autopilot*"
    ) -details "track=$($health.track)"
    Add-Check -name "backend_prooffile" -ok (
        $health.proofFile -eq "deploy/alibaba/serverless-devs.yaml"
    ) -details "proofFile=$($health.proofFile)"
}
catch {
    Add-Check -name "backend_health" -ok $false -details $_.Exception.Message
    Add-Check -name "backend_track" -ok $false -details "health check failed"
    Add-Check -name "backend_prooffile" -ok $false -details "health check failed"
}

try {
    $scenarioResponse = Invoke-RestMethod -Method Get -Uri "$($BackendUrl.TrimEnd('/'))/api/scenarios" -TimeoutSec 20
    Add-Check -name "backend_scenarios" -ok (
        $null -ne $scenarioResponse.scenarios -and $scenarioResponse.scenarios.Count -ge 1
    ) -details "scenarios=$($scenarioResponse.scenarios.Count)"
}
catch {
    Add-Check -name "backend_scenarios" -ok $false -details $_.Exception.Message
}

$packet = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    projectRoot = $projectRoot
    track = $Track
    ready = $ready
    readyForSubmission = $ready
    input = [ordered]@{
        repoUrl = $repoUsed
        demoVideoUrl = $DemoVideoUrl
        backendUrl = $BackendUrl
    }
    checks = $checks
}

Set-Content -Path $packetJson -Value ($packet | ConvertTo-Json -Depth 10) -Encoding UTF8

$copyLines = @(
    "# Devpost Submission Packet ($timestamp)",
    "",
    "Generated: $($packet.generatedAt)",
    "",
    "## Project fields",
    "",
    "- Project title: Qwen CI Autopilot",
    "- Track: $Track",
    "- Repo URL: $repoUsed",
    "- Demo video URL: $DemoVideoUrl",
    "",
    "## Required check results",
    ""
)

foreach ($check in $checks) {
    $status = if ($check.ok) { "PASS" } else { "FAIL" }
    $copyLines += "- $status $($check.name): $($check.details)"
}

$copyLines += @(
    "",
    "## Quick copy to Devpost text fields",
    "",
    "Qwen CI Autopilot",
    "",
    "Track: $Track",
    "",
    "A staged-engineering CI and cloud-alert autopilot that turns ambiguous production incidents into a human-gated, evidence-backed remediation plan. It runs local triage, reproduction, patch planning, risk review, and verification loops, then emits structured artifacts and deployment proof.",
    "",
    "Repository: $repoUsed",
    "",
    "Demo video: $DemoVideoUrl",
    "",
    "Architecture: docs/architecture.svg",
    "Deployment proof file: deploy/alibaba/serverless-devs.yaml",
    "",
    "Run command for judges:",
    "npm run hackathon:audit",
    "",
    "## Next step",
    "- Open the Devpost entry form and paste the text above.",
    "- Upload/attach public demo video links above (<= 3:00).",
    "- Set submission status to final and save.",
    "",
    "## Notes",
    ""
)
if ($notes.Count -gt 0) {
    $copyLines += $notes
}

Set-Content -Path $packetMd -Value ($copyLines -join "`r`n") -Encoding UTF8

if ($ready) {
    Write-Host "Submission packet READY: $packetJson"
    Write-Host "Submission packet markdown: $packetMd"
}
else {
    Write-Host "Submission packet has missing requirements: $packetJson" -ForegroundColor Yellow
    Write-Host "Submission packet markdown: $packetMd"
    exit 1
}
