param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter(Mandatory = $false)]
    [string]$LocalImageTag = "qwen-ci-autopilot:local",
    [Parameter(Mandatory = $false)]
    [string]$AcrImage = $env:ACR_IMAGE,
    [switch]$SkipBuild,
    [switch]$SkipSmoke,
    [switch]$SkipPush,
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactDir = Join-Path $ProjectRoot "artifacts/qwencloud-proof"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$outJson = Join-Path $artifactDir "alibaba-release-$timestamp.json"
$outMd = Join-Path $artifactDir "alibaba-release-$timestamp.md"
$checks = @()
$steps = @()
$releaseOk = $true

function Add-Check([string]$name, [bool]$ok, [string]$details) {
    $script:checks += [ordered]@{
        name = $name
        ok = $ok
        details = $details
    }
    if (-not $ok) {
        $script:releaseOk = $false
    }
}

function Add-Step([string]$name, [bool]$ok, [string]$details) {
    $script:steps += [ordered]@{
        name = $name
        ok = $ok
        details = $details
    }
    if (-not $ok) {
        $script:releaseOk = $false
    }
}

function Has-Command([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Require-Env([string]$name, [string]$value, [string]$details) {
    Add-Check -name "env.$name" -ok (-not [string]::IsNullOrWhiteSpace($value)) -details $details
}

$existing = Get-Location
Set-Location $ProjectRoot

try {
    Add-Check -name "tool.docker" -ok (Has-Command "docker") -details "Docker CLI"
    Add-Check -name "tool.serverless_devs_s" -ok (Has-Command "s") -details "Serverless Devs CLI"
    Require-Env -name "DASHSCOPE_API_KEY" -value $env:DASHSCOPE_API_KEY -details "Qwen Cloud API key for live deployed backend."
    Require-Env -name "ALIBABA_CLOUD_REGION" -value $env:ALIBABA_CLOUD_REGION -details "Alibaba Cloud region."
    Require-Env -name "ALIBABA_CLOUD_SERVICE" -value $env:ALIBABA_CLOUD_SERVICE -details "Function Compute service/function name."
    Require-Env -name "ACR_IMAGE" -value $AcrImage -details "Alibaba Cloud Container Registry target image."

    if (-not $releaseOk) {
        throw "Release prerequisites are missing."
    }

    if (-not $env:QWEN_BASE_URL) {
        $env:QWEN_BASE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    }
    if (-not $env:QWEN_MODEL) {
        $env:QWEN_MODEL = "qwen3.7-plus"
    }

    if (-not $SkipBuild) {
        $preflightArgs = @(
            "-ProjectRoot", $ProjectRoot,
            "-ImageTag", $LocalImageTag,
            "-BuildImage"
        )
        if (-not $SkipSmoke) {
            $preflightArgs += "-SmokeContainer"
        }

        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "qwencloud-deploy-preflight.ps1") @preflightArgs
        $preflightOk = $LASTEXITCODE -eq 0
        Add-Step -name "preflight.build_and_smoke" -ok $preflightOk -details "Local image=$LocalImageTag"
        if (-not $preflightOk) {
            throw "Deploy preflight failed."
        }
    }
    else {
        Add-Step -name "preflight.build_and_smoke" -ok $true -details "Skipped by -SkipBuild"
    }

    & docker tag $LocalImageTag $AcrImage
    $tagOk = $LASTEXITCODE -eq 0
    Add-Step -name "docker.tag" -ok $tagOk -details "$LocalImageTag -> $AcrImage"
    if (-not $tagOk) {
        throw "Docker tag failed."
    }

    if (-not $SkipPush) {
        & docker push $AcrImage
        $pushOk = $LASTEXITCODE -eq 0
        Add-Step -name "docker.push" -ok $pushOk -details $AcrImage
        if (-not $pushOk) {
            throw "Docker push failed."
        }
    }
    else {
        Add-Step -name "docker.push" -ok $true -details "Skipped by -SkipPush"
    }

    if (-not $SkipDeploy) {
        Push-Location (Join-Path $ProjectRoot "deploy/alibaba")
        try {
            & s deploy
            $deployOk = $LASTEXITCODE -eq 0
            Add-Step -name "serverless_devs.deploy" -ok $deployOk -details "deploy/alibaba/serverless-devs.yaml"
            if (-not $deployOk) {
                throw "Serverless Devs deploy failed."
            }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Add-Step -name "serverless_devs.deploy" -ok $true -details "Skipped by -SkipDeploy"
    }
}
catch {
    Add-Step -name "release.error" -ok $false -details $_.Exception.Message
}
finally {
    Set-Location $existing
}

$result = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    projectRoot = $ProjectRoot
    releaseOk = $releaseOk
    localImageTag = $LocalImageTag
    acrImage = $AcrImage
    skipBuild = [bool]$SkipBuild
    skipSmoke = [bool]$SkipSmoke
    skipPush = [bool]$SkipPush
    skipDeploy = [bool]$SkipDeploy
    checks = $checks
    steps = $steps
}

Set-Content -Path $outJson -Value ($result | ConvertTo-Json -Depth 10) -Encoding UTF8

$mdLines = @(
    "# Alibaba Release ($timestamp)",
    "",
    "- Result: $releaseOk",
    "- Local image: $LocalImageTag",
    "- ACR image: $AcrImage",
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $status = if ($check.ok) { "PASS" } else { "FAIL" }
    $mdLines += "- $status $($check.name): $($check.details)"
}

$mdLines += @("", "## Steps", "")
foreach ($step in $steps) {
    $status = if ($step.ok) { "PASS" } else { "FAIL" }
    $mdLines += "- $status $($step.name): $($step.details)"
}

Set-Content -Path $outMd -Value ($mdLines -join "`r`n") -Encoding UTF8

if ($releaseOk) {
    Write-Host "Alibaba release completed: $outJson"
}
else {
    Write-Host "Alibaba release did not complete: $outJson" -ForegroundColor Yellow
    exit 1
}
