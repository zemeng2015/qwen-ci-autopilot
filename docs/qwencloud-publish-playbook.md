# Qwen Cloud Submission Playbook

## 1) Before coding

- Keep one GitHub repo clean and public.
- Keep branch history focused and easy to review.
- Ensure license file exists and repository description includes project intent.

## 2) Build and verify locally

```powershell
npm install
npm run test
npm run build
npm run deploy:preflight
npm run deploy:preflight -- -BuildImage -SmokeContainer -ImageTag qwen-ci-autopilot:local
npm run deploy:alibaba
npm run hackathon:verify
```

## 3) Run audit gate

```powershell
npm run hackathon:audit
```

Expected outputs in `artifacts/qwencloud-proof/`:

- `submission-audit-*.json`
- `submission-gate-*.json` and `.md`
- `submission-verify-*.json`
- `submission-proof-*.json` and `.md`

Generate the final Devpost packet after the public repo and video URLs exist:

```powershell
npm run hackathon:submission-packet -- `
  -RepoUrl "https://github.com/zemeng2015/qwen-ci-autopilot" `
  -DemoVideoUrl "https://www.youtube.com/..." `
  -BackendUrl "https://<your-alibaba-backend>"
```

## 4) Demo prep

- Record a <3 minute demo on the target device (desktop/browser).
- Show:
  - scenario run
  - staged evidence
- Show high-risk checkpoint workflow
- Show `/api/health` and deployment proof link

## 5) Devpost form fields (final)

- Title: `Qwen CI Autopilot`
- Track: `Track 4: Autopilot Agent`
- Repository URL: public GitHub repo
- Description: 6-10 lines with use case + architecture + verification approach
- Demo video: public link
- Category-specific proof links: architecture + deployment file + health proof URL if useful
- Optional: separate deployment proof clip and blog/social post link

## 6) Post submit

- Keep repository public and accessible through judging period.
- Do not add new runtime secrets to public repo.
- Keep Docker and deploy docs aligned with actual service name and region.
