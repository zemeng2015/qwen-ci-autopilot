# Devpost Submission Draft

## Project Title

Qwen CI Autopilot

## Suggested Qwen Cloud Track

- Track 4: Autopilot Agent

## Tagline

An engineering autopilot that turns CI failures and production alerts into a
safe remediation plan with Qwen Cloud reasoning, local tool evidence, and a
human approval gate before risky changes.

## Description

Qwen CI Autopilot helps engineering teams handle ambiguous build failures,
coverage drops, and cloud alerts. A developer pastes a CI signal or selects a
sample scenario. The backend extracts deterministic evidence such as changed
files, commands, stack traces, constraints, and risk signals. It then runs a
five-stage agent workflow: Triage, Reproducer, Patch Planner, Risk Review, and
Verification.

When a Qwen Cloud key is configured, each stage calls `qwen3.7-plus` through the
OpenAI-compatible Qwen Cloud API and asks for structured JSON. If a key or quota
is unavailable, the same response contract falls back to deterministic demo
fixtures so judges can still exercise the workflow. High-risk incidents, such
as production alerts or financial logic, stop at a human checkpoint before the
agent applies or verifies a patch.

## Built With

- Qwen Cloud `qwen3.7-plus`
- Alibaba Cloud Function Compute
- React
- Vite
- TypeScript
- Express
- OpenAI-compatible SDK
- Vitest
- Docker

## Key Features

- Multi-stage Autopilot Agent for real engineering workflows
- Structured Qwen Cloud calls with deterministic fallback
- Local evidence extraction before model reasoning
- Human-in-the-loop checkpoint for production-sensitive changes
- Verification command package and deployment health proof
- Alibaba Cloud Function Compute deployment config

## Demo Video Script

Target length: under 3 minutes.

1. Show the dashboard and explain the problem: CI failures are ambiguous and
   risky to automate blindly.
2. Select `Spring Boot CI coverage gate` and run in demo mode.
3. Show the five agent stages and generated evidence.
4. Select a high-risk production scenario and run again.
5. Show the human approval checkpoint blocking verification.
6. Approve the plan and show verification unlock.
7. Show `/api/health` and the Alibaba Cloud proof file.
8. Close with why this is production-ready: scoped tools, Qwen reasoning,
   fallback mode, and explicit risk gates.

## Demo/Video Metadata

- Video URL (YouTube/Vimeo/Youku): `https://...`
- Video length target: `<= 3:00`
- Demonstration device: Desktop browser
- Script language: English

## Alibaba Cloud Proof Link

Use this repository file as the proof link:

`deploy/alibaba/serverless-devs.yaml`

## Architecture Diagram Link

Use:

`docs/architecture.svg`

## Public Video Proof

- Short proof clip URL (separate from main demo, if available): `https://...`

## Repository Checklist

- [x] Source code
- [x] Open source license
- [x] Qwen Cloud integration
- [x] Alibaba Cloud deployment proof file
- [x] Architecture diagram
- [x] Local setup instructions
- [x] Tests and build scripts
- [ ] Public demo video URL
- [x] Public GitHub repository URL
- [ ] Separate Alibaba Cloud proof recording URL
- [ ] Finalized testing instructions

## Public Repository

https://github.com/zemeng2015/qwen-ci-autopilot

## Reproducible CI Proof

https://github.com/zemeng2015/qwen-ci-autopilot/actions/workflows/ci.yml

## Ready-to-run one-liner

Before final submit, generate everything you need to paste into Devpost:

```powershell
npm run hackathon:submission-packet -- `
  -RepoUrl "https://github.com/<you>/<repo>" `
  -DemoVideoUrl "https://www.youtube.com/..."
```
