# Devpost Copy-Paste Template (Qwen Cloud Track 4)

Use this directly in the Devpost submission form, then replace all placeholders.

**Project Title**  
Qwen CI Autopilot

**Track**  
Track 4: Autopilot Agent

**One-paragraph Description**  
Qwen CI Autopilot is a production-minded agentic workflow that turns ambiguous engineering incidents into safe, staged remediation plans. It combines local signal analysis (files, stack traces, commands, risk signals) with Qwen Cloud reasoning (`qwen3.7-plus`) to run a five-stage loop: triage, reproduce, patch plan, risk review, and verification. High-risk cases require human approval before verification actions, and the app ships deployment and architecture proof required for competition judging.

**Technical Highlights**  
- Alibaba Cloud Function Compute custom container backend with explicit `/api/health` deployment proof.
- Deterministic fallback mode when Qwen Cloud is unavailable.
- Frontend dashboard with run history, risk checkpoints, and artifact generation.
- Evidence artifacts: patch intent, remediation plan, verification evidence, and deployment proof.

**Repository (public GitHub repo)**  
https://github.com/zemeng2015/qwen-ci-autopilot

**Demo video**  
`[ADD_PUBLIC_3MIN_OR_SHORTER_VIDEO_URL]`

**Public demo instructions**  
1. Open app URL.
2. Select a scenario and run the autopilot.
3. Show the five-stage evidence timeline and approval gate.
4. Open `/api/health` and confirm deployment fields.
5. Show `deploy/alibaba/serverless-devs.yaml`.

**Architecture / proof links**  
- Architecture diagram: `docs/architecture.svg`  
- Architecture doc: `docs/architecture.md`  
- Deployment proof file: `deploy/alibaba/serverless-devs.yaml`

**Judging test command (optional to paste in description)**  
```bash
npm run hackathon:audit
```

**Submission checklist before final click**  
- [x] Repo is public (GitHub) and contains LICENSE.  
- [ ] Video is public on YouTube / Vimeo / Youku and **< 3:00**.  
- [ ] Track set to `Track 4: Autopilot Agent`.  
- [ ] Health endpoint proof is working in deployed environment.  

**Video proof placeholder**  
`[ADD_PUBLIC_PROOF_CLIP_URL]`
