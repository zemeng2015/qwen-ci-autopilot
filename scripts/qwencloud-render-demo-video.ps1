param(
    [Parameter(Mandatory = $false)]
    [string]$InputVideo = "artifacts/demo/qwen-ci-autopilot-demo-local-paced.mp4",
    [Parameter(Mandatory = $false)]
    [string]$OutputVideo = "artifacts/demo/qwen-ci-autopilot-devpost-final.mp4",
    [Parameter(Mandatory = $false)]
    [string]$WorkDir = "artifacts/demo/render"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg is required to render the final demo video."
}

if (-not (Test-Path $InputVideo)) {
    throw "Input video was not found: $InputVideo"
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$intro = Join-Path $WorkDir "intro.mp4"
$main = Join-Path $WorkDir "main-captioned.mp4"
$outro = Join-Path $WorkDir "outro.mp4"
$concatFile = Join-Path $WorkDir "concat.txt"
$introAss = Join-Path $WorkDir "intro.ass"
$mainAss = Join-Path $WorkDir "main.ass"
$outroAss = Join-Path $WorkDir "outro.ass"

function Write-AssFile([string]$Path, [string[]]$Dialogues) {
    $header = @(
        "[Script Info]",
        "ScriptType: v4.00+",
        "PlayResX: 1440",
        "PlayResY: 1000",
        "",
        "[V4+ Styles]",
        "Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding",
        "Style: Title,Arial,58,&H002B2F0B,&H000000FF,&H00FFFFFF,&H00000000,-1,0,0,0,100,100,0,0,1,1,1,5,40,40,40,1",
        "Style: Subtitle,Arial,30,&H00FFFFFF,&H000000FF,&H000B2F2B,&HCC0B2F2B,0,0,0,0,100,100,0,0,3,2,0,2,80,80,70,1",
        "Style: Body,Arial,30,&H002B2F0B,&H000000FF,&H00FFFFFF,&H00000000,0,0,0,0,100,100,0,0,1,1,1,5,40,40,40,1",
        "",
        "[Events]",
        "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text"
    )
    Set-Content -Path $Path -Value (($header + $Dialogues) -join "`r`n") -Encoding UTF8
}

Write-AssFile -Path $introAss -Dialogues @(
    "Dialogue: 0,0:00:00.00,0:00:05.00,Title,,0,0,0,,{\pos(720,335)}Qwen CI Autopilot",
    "Dialogue: 0,0:00:00.00,0:00:05.00,Body,,0,0,0,,{\pos(720,415)}Track 4 Autopilot Agent for production engineering workflows",
    "Dialogue: 0,0:00:00.00,0:00:05.00,Body,,0,0,0,,{\pos(720,470)}Qwen Cloud reasoning plus local evidence plus human approval gates"
)

Write-AssFile -Path $mainAss -Dialogues @(
    "Dialogue: 0,0:00:00.00,0:00:06.00,Subtitle,,0,0,0,,Realistic incident input becomes a staged agent run",
    "Dialogue: 0,0:00:06.00,0:00:13.00,Subtitle,,0,0,0,,Triage reproduce patch plan risk review and verification",
    "Dialogue: 0,0:00:13.00,0:00:21.00,Subtitle,,0,0,0,,Production sensitive alerts stop at a human approval gate",
    "Dialogue: 0,0:00:21.00,0:00:25.00,Subtitle,,0,0,0,,Reviewer approval unlocks the verification path",
    "Dialogue: 0,0:00:25.00,0:00:30.00,Subtitle,,0,0,0,,Health endpoint exposes Alibaba deployment proof metadata"
)

Write-AssFile -Path $outroAss -Dialogues @(
    "Dialogue: 0,0:00:00.00,0:00:07.00,Title,,0,0,0,,{\pos(720,285)}Submission proof",
    "Dialogue: 0,0:00:00.00,0:00:07.00,Body,,0,0,0,,{\pos(720,375)}Public repo  github.com/zemeng2015/qwen-ci-autopilot",
    "Dialogue: 0,0:00:00.00,0:00:07.00,Body,,0,0,0,,{\pos(720,425)}Architecture  docs/architecture.svg",
    "Dialogue: 0,0:00:00.00,0:00:07.00,Body,,0,0,0,,{\pos(720,475)}Alibaba proof  deploy/alibaba/serverless-devs.yaml",
    "Dialogue: 0,0:00:00.00,0:00:07.00,Body,,0,0,0,,{\pos(720,525)}CI proof  GitHub Actions ci workflow"
)

$introAssPath = $introAss.Replace("\", "/")
$mainAssPath = $mainAss.Replace("\", "/")
$outroAssPath = $outroAss.Replace("\", "/")

& ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0xf7faf9:s=1440x1000:d=5:r=25" -vf "subtitles='$introAssPath'" -c:v libx264 -pix_fmt yuv420p -an $intro
if ($LASTEXITCODE -ne 0) { throw "Failed to render intro segment." }

& ffmpeg -hide_banner -loglevel error -y -i $InputVideo -vf "subtitles='$mainAssPath'" -r 25 -c:v libx264 -pix_fmt yuv420p -an $main
if ($LASTEXITCODE -ne 0) { throw "Failed to render captioned main segment." }

& ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=0xf7faf9:s=1440x1000:d=7:r=25" -vf "subtitles='$outroAssPath'" -c:v libx264 -pix_fmt yuv420p -an $outro
if ($LASTEXITCODE -ne 0) { throw "Failed to render outro segment." }

$concatLines = @(
    "file 'intro.mp4'",
    "file 'main-captioned.mp4'",
    "file 'outro.mp4'"
)
Set-Content -Path $concatFile -Value ($concatLines -join "`n") -Encoding ASCII

& ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $concatFile -c copy -movflags +faststart $OutputVideo
if ($LASTEXITCODE -ne 0) { throw "Failed to concatenate final video." }

$probeJson = & ffprobe -v error -show_entries format=duration,size -of json $OutputVideo
Write-Host "Final demo video rendered: $OutputVideo"
Write-Host $probeJson
