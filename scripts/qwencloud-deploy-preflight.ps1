param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location).Path,
    [Parameter(Mandatory = $false)]
    [string]$ImageTag = "qwen-ci-autopilot:local",
    [switch]$BuildImage,
    [switch]$SmokeContainer,
    [Parameter(Mandatory = $false)]
    [int]$SmokePort = 8788
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$artifactDir = Join-Path $ProjectRoot "artifacts/qwencloud-proof"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$outJson = Join-Path $artifactDir "deploy-preflight-$timestamp.json"
$outMd = Join-Path $artifactDir "deploy-preflight-$timestamp.md"
$checks = @()
$ready = $true

function Add-Check([string]$name, [bool]$ok, [string]$details, [bool]$required = $true) {
    $script:checks += [ordered]@{
        name = $name
        ok = $ok
        required = $required
        details = $details
    }

    if ($required -and -not $ok) {
        $script:ready = $false
    }
}

function Has-Command([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

$existing = Get-Location
Set-Location $ProjectRoot

try {
    Add-Check -name "file.Dockerfile" -ok (Test-Path "Dockerfile") -details "Dockerfile"
    Add-Check -name "file.serverless_devs" -ok (Test-Path "deploy/alibaba/serverless-devs.yaml") -details "deploy/alibaba/serverless-devs.yaml"

    $hasDocker = Has-Command "docker"
    Add-Check -name "tool.docker" -ok $hasDocker -details "docker CLI"
    $dockerDaemonOk = $false
    if ($hasDocker) {
        try {
            $dockerStdout = Join-Path $artifactDir "docker-info-$timestamp.out"
            $dockerStderr = Join-Path $artifactDir "docker-info-$timestamp.err"
            $dockerInfo = Start-Process -FilePath "docker" -ArgumentList "info" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $dockerStdout -RedirectStandardError $dockerStderr
            $dockerDaemonOk = $dockerInfo.ExitCode -eq 0
        }
        catch {
            $dockerDaemonOk = $false
        }
        Add-Check -name "tool.docker_daemon" -ok $dockerDaemonOk -details "Docker daemon must be running for image build/push."
    }
    else {
        Add-Check -name "tool.docker_daemon" -ok $false -details "Docker CLI is unavailable."
    }

    $hasServerlessDevs = Has-Command "s"
    Add-Check -name "tool.serverless_devs_s" -ok $hasServerlessDevs -details "Install with: npm install -g @serverless-devs/s"
    if ($hasServerlessDevs) {
        try {
            $sConfig = (& s config get -a default 2>&1) -join "`n"
            $hasDefaultAccess = $sConfig -notmatch "not yet|not found|not.*configured"
            Add-Check -name "tool.serverless_devs_default_access" -ok $hasDefaultAccess -details "Required because deploy/alibaba/serverless-devs.yaml uses access: default."
        }
        catch {
            Add-Check -name "tool.serverless_devs_default_access" -ok $false -details "Run: s config add"
        }
    }
    else {
        Add-Check -name "tool.serverless_devs_default_access" -ok $false -details "Install Serverless Devs, then run: s config add"
    }

    Add-Check -name "tool.aliyun_cli" -ok (Has-Command "aliyun") -details "Optional helper CLI; Serverless Devs can deploy without this." -required $false
    Add-Check -name "env.DASHSCOPE_API_KEY" -ok ([bool]$env:DASHSCOPE_API_KEY) -details "Required for live Qwen Cloud calls on deployed backend."
    Add-Check -name "env.ALIBABA_CLOUD_REGION" -ok ([bool]$env:ALIBABA_CLOUD_REGION) -details "Example: us-east-1"
    Add-Check -name "env.ALIBABA_CLOUD_SERVICE" -ok ([bool]$env:ALIBABA_CLOUD_SERVICE) -details "Example: qwen-ci-autopilot-api"
    Add-Check -name "env.ACR_IMAGE" -ok ([bool]$env:ACR_IMAGE) -details "Alibaba Cloud Container Registry image URI."

    if ($BuildImage) {
        if ($hasDocker -and $dockerDaemonOk) {
            Write-Host "Building Docker image: $ImageTag"
            try {
                & docker build -t $ImageTag .
                $dockerBuildOk = $LASTEXITCODE -eq 0
            }
            catch {
                $dockerBuildOk = $false
            }
            Add-Check -name "docker.build" -ok $dockerBuildOk -details "docker build -t $ImageTag ."
        }
        else {
            Add-Check -name "docker.build" -ok $false -details "Docker CLI or daemon is unavailable."
        }
    }
    else {
        Add-Check -name "docker.build" -ok $true -details "Skipped. Re-run with -BuildImage to test container build." -required $false
    }

    if ($SmokeContainer) {
        $containerName = "qwen-ci-autopilot-smoke"
        $smokeOk = $false
        if ($hasDocker -and $dockerDaemonOk) {
            try {
                try {
                    & docker rm -f $containerName 2>$null | Out-Null
                }
                catch {
                    # Ignore missing previous smoke container.
                }
                & docker run --rm -d -p "$($SmokePort):8787" --name $containerName $ImageTag | Out-Null
                $deadline = (Get-Date).AddSeconds(45)
                do {
                    try {
                        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$SmokePort/api/health" -TimeoutSec 5
                        if ($health.ok -and $health.proofFile -eq "deploy/alibaba/serverless-devs.yaml") {
                            $smokeOk = $true
                            break
                        }
                    }
                    catch {
                        Start-Sleep -Seconds 2
                    }
                } while ((Get-Date) -lt $deadline)
            }
            finally {
                try {
                    & docker stop $containerName 2>$null | Out-Null
                }
                catch {
                    # Ignore containers that exited before cleanup.
                }
            }
        }
        Add-Check -name "docker.smoke_container" -ok $smokeOk -details "GET http://127.0.0.1:$SmokePort/api/health from $ImageTag"
    }
    else {
        Add-Check -name "docker.smoke_container" -ok $true -details "Skipped. Re-run with -SmokeContainer to test runtime health." -required $false
    }
}
finally {
    Set-Location $existing
}

$result = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    projectRoot = $ProjectRoot
    readyForDeploy = $ready
    buildImage = [bool]$BuildImage
    smokeContainer = [bool]$SmokeContainer
    imageTag = $ImageTag
    checks = $checks
}

Set-Content -Path $outJson -Value ($result | ConvertTo-Json -Depth 8) -Encoding UTF8

$mdLines = @(
    "# Alibaba Deploy Preflight ($timestamp)",
    "",
    "- Ready for deploy: $ready",
    "- Docker build requested: $([bool]$BuildImage)",
    "- Container smoke requested: $([bool]$SmokeContainer)",
    "- Image tag: $ImageTag",
    "",
    "## Checks",
    ""
)

foreach ($check in $checks) {
    $status = if ($check.ok) { "PASS" } else { "FAIL" }
    $kind = if ($check.required) { "required" } else { "optional" }
    $mdLines += "- $status [$kind] $($check.name): $($check.details)"
}

$mdLines += @(
    "",
    "## Next deploy commands",
    "",
    '```powershell',
    'npm install -g @serverless-devs/s',
    's config add',
    '$env:DASHSCOPE_API_KEY="sk-..."',
    '$env:ALIBABA_CLOUD_REGION="us-east-1"',
    '$env:ALIBABA_CLOUD_SERVICE="qwen-ci-autopilot-api"',
    '$env:ACR_IMAGE="registry-intl.us-east-1.aliyuncs.com/<namespace>/qwen-ci-autopilot:latest"',
    "npm run deploy:preflight -- -BuildImage -SmokeContainer -ImageTag qwen-ci-autopilot:local",
    "docker build -t qwen-ci-autopilot:latest .",
    '# docker tag/push to $env:ACR_IMAGE after logging into Alibaba Cloud Container Registry',
    "cd deploy/alibaba",
    "s deploy",
    '```'
)

Set-Content -Path $outMd -Value ($mdLines -join "`r`n") -Encoding UTF8

if ($ready) {
    Write-Host "Deploy preflight passed: $outJson"
}
else {
    Write-Host "Deploy preflight found missing required inputs: $outJson" -ForegroundColor Yellow
    exit 1
}
