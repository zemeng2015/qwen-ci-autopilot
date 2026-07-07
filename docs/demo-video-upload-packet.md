# Demo Video Upload Packet

Use this for the public YouTube, Vimeo, or Youku upload required by Devpost.

## Local video file

`artifacts/demo/qwen-ci-autopilot-devpost-final.mp4`

Generated local proof:

- Length: about 41 seconds
- Format: MP4 / H.264
- Rendered with title card, captions, proof outro, dashboard flow, demo
  autopilot run, production-risk approval gate, checkpoint approval, and
  `/api/health` deployment metadata

Render command:

```powershell
npm run demo:render
```

## Suggested title

Qwen CI Autopilot - Qwen Cloud Track 4 Autopilot Agent

## Suggested description

Qwen CI Autopilot is a Track 4 Autopilot Agent for the Qwen Cloud Hackathon. It
turns ambiguous CI failures and production alerts into a staged remediation
workflow with local evidence extraction, Qwen Cloud reasoning, deterministic
fallback, and human approval gates before risky actions.

In this demo:

1. The dashboard loads a realistic engineering incident.
2. The autopilot runs triage, reproduction, patch planning, risk review, and
   verification stages.
3. A production-sensitive workflow alert triggers an approval gate.
4. The reviewer approves the plan.
5. The health endpoint shows Alibaba Cloud deployment metadata and the repo
   proof file path.

Repository:
https://github.com/zemeng2015/qwen-ci-autopilot

Track:
Track 4: Autopilot Agent

Architecture:
https://github.com/zemeng2015/qwen-ci-autopilot/blob/main/docs/architecture.svg

Alibaba Cloud deployment proof file:
https://github.com/zemeng2015/qwen-ci-autopilot/blob/main/deploy/alibaba/serverless-devs.yaml

## Suggested tags

`qwencloud`, `hackathon`, `autopilot-agent`, `alibaba-cloud`, `typescript`,
`react`, `developer-tools`, `ci-cd`

## Short narration script

This is Qwen CI Autopilot, a Track 4 Autopilot Agent for production engineering
workflows. A developer can paste a CI failure or production alert. The backend
extracts local signals, then runs staged agents for triage, reproduction, patch
planning, risk review, and verification. When the signal touches production or
policy-sensitive behavior, the agent stops at a human approval checkpoint before
continuing. The project includes Qwen Cloud integration, deterministic fallback,
Docker deployment, Alibaba Cloud Function Compute proof, CI verification, and
architecture documentation for judges.

## Upload checklist

- [ ] Run `npm run demo:render`.
- [ ] Upload `artifacts/demo/qwen-ci-autopilot-devpost-final.mp4`.
- [ ] Set visibility to public or unlisted-but-accessible if the platform allows
  Devpost judging access. Public is safest.
- [ ] Confirm duration is under 3 minutes.
- [ ] Paste the video URL into `docs/devpost-copy-paste-template.md`.
- [ ] Re-run:
  ```powershell
  npm run hackathon:submission-packet -- -RepoUrl "https://github.com/zemeng2015/qwen-ci-autopilot" -DemoVideoUrl "<public video URL>"
  ```
