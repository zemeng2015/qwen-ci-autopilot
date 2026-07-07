param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipRemoteCheck,
    [switch]$RequireRemote
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactDir = Join-Path $ProjectRoot "artifacts/qwencloud-proof"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$outFile = Join-Path $artifactDir "submission-gate-$timestamp.json"
$outMarkdown = Join-Path $artifactDir "submission-gate-$timestamp.md"

$requiredPaths = @(
    "README.md",
    "LICENSE",
    "package.json",
    "server/index.ts",
    "server/orchestrator.ts",
    "docs/devpost-submission.md",
    "docs/architecture.md",
    "docs/architecture.svg",
    "docs/deployment/alibaba-cloud.md",
    "deploy/alibaba/serverless-devs.yaml",
    "scripts/qwencloud-alibaba-release.ps1",
    "scripts/qwencloud-deploy-preflight.ps1",
    "scripts/qwencloud-hackathon-audit.ps1",
    "scripts/qwencloud-hackathon-proof.ps1",
    "scripts/qwencloud-hackathon-verify.ps1",
    "scripts/qwencloud-hackathon-submit-gate.ps1",
    "artifacts/remediation-plan.md",
    "artifacts/patch-intent.diff",
    "artifacts/verification-evidence.json"
)

$checks = @()
$allPass = $true
$repoInfo = [ordered]@{
    url = $null
    visible = $null
    note = ""
}

function Add-Check([string]$name, [bool]$ok, [string]$details) {
    $script:checks += [ordered]@{
        name = $name
        ok = $ok
        details = $details
    }

    if (-not $ok) {
        $script:allPass = $false
    }
}

$existing = Get-Location
Set-Location $ProjectRoot

foreach ($path in $requiredPaths) {
    $target = Resolve-Path -Path $path -ErrorAction SilentlyContinue
    Add-Check -name "required_path.$path" -ok ($null -ne $target) -details $path
}

if (Test-Path "artifacts/qwencloud-proof") {
    Add-Check -name "proof_dir_writable" -ok $true -details "artifacts/qwencloud-proof exists"
} else {
    Add-Check -name "proof_dir_writable" -ok $false -details "artifacts/qwencloud-proof missing"
}

if (Test-Path ".git") {
    Add-Check -name "git_repo" -ok $true -details "git metadata exists"
} else {
    Add-Check -name "git_repo" -ok $false -details "no .git metadata"
}

if (Test-Path "LICENSE") {
    $license = Get-Content "LICENSE" -Raw
    Add-Check -name "license_detectable" -ok ($license -match "MIT" -or $license -match "Apache|BSD|GPL|MPL|ISC|Creative") -details "License file text detected"
} else {
    Add-Check -name "license_detectable" -ok $false -details "License missing"
}

if (-not $SkipRemoteCheck -and (Test-Path ".git")) {
    try {
        $origin = (& git remote get-url origin) 2>$null
        if (-not [string]::IsNullOrWhiteSpace($origin)) {
            Add-Check -name "git_remote_origin" -ok $true -details $origin
            $repoInfo.url = $origin

            if ($origin -match "github.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$") {
                $api = "https://api.github.com/repos/$($matches.owner)/$($matches.repo)"
                try {
                    $repoData = Invoke-RestMethod -Uri $api -UserAgent "codex-hackathon-audit/1.0" -TimeoutSec 12
                    Add-Check -name "remote_repo_accessible" -ok $true -details "repo=$($repoData.full_name)"
                    $repoInfo.visible = -not $repoData.private
                }
                catch {
                    Add-Check -name "remote_repo_accessible" -ok (-not $RequireRemote) -details $_.Exception.Message
                }
            } else {
                Add-Check -name "remote_host_supported" -ok $RequireRemote -details "only GitHub visibility check is automatic"
            }
        } else {
            Add-Check -name "git_remote_origin" -ok (-not $RequireRemote) -details "origin is empty"
        }
    }
    catch {
        Add-Check -name "git_remote_origin" -ok (-not $RequireRemote) -details $_.Exception.Message
    }
}

$summary = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    projectRoot = $ProjectRoot
    pass = $allPass
    checks = $checks
    repo = $repoInfo
}

Set-Content -Path $outFile -Value ($summary | ConvertTo-Json -Depth 8) -Encoding UTF8

$markdown = @"
# Qwen Hackathon Submission Gate ($timestamp)

## JSON

- Output: $outFile
- Result: $($allPass)
- GitHub remote: $($repoInfo.url)
- Remote public: $($repoInfo.visible)

## Checks

"@
foreach ($check in $checks) {
    $status = if ($check.ok) { "PASS" } else { "FAIL" }
    $markdown += "- $status $($check.name): $($check.details)`n"
}

Set-Content -Path $outMarkdown -Value $markdown -Encoding UTF8

Set-Location $existing
if ($allPass) {
    Write-Host "Submission gate passed: $outFile"
} else {
    Write-Host "Submission gate found issues: $outFile" -ForegroundColor Red
    exit 1
}
