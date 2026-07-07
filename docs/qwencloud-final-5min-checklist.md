# Qwen Cloud Submission Final 5-Minute Checklist

Run this in the last 5 minutes before submission.

1. Confirm codebase requirements in Devpost form:
   - Public repository URL: `https://github.com/zemeng2015/qwen-ci-autopilot`
   - CI proof URL: `https://github.com/zemeng2015/qwen-ci-autopilot/actions/workflows/ci.yml`
   - Project description
   - Track = `Track 4: Autopilot Agent`
   - Text explanation of workflow and impact
2. Confirm all required links are present:
   - GitHub repository (public)
   - `deploy/alibaba/serverless-devs.yaml` (deployment proof link)
   - `docs/architecture.svg` and `docs/architecture.md` (architecture diagram)
   - demo video URL (YouTube/Vimeo/Youku, <=3:00)
   - demo upload notes: `docs/demo-video-upload-packet.md`
   - optional blog/social draft: `docs/qwencloud-build-journey-post.md`
3. Confirm local/run-time proof:
   - `/api/health` works on backend URL
   - proof response includes:
     - `service`
     - `deploymentTarget`
     - `region`
     - `qwen.model`
     - `proofFile`
   - Alibaba release helper ran successfully if using this repo flow:
     ```powershell
     npm run deploy:alibaba
     ```
4. Execute audit command and attach outputs:
   ```powershell
   npm run hackathon:audit
   ```
5. Render or verify the final Devpost video:
   ```powershell
   npm run demo:render
   ```
   Confirm `artifacts/demo/qwen-ci-autopilot-devpost-final.mp4` is under 3
   minutes before upload.
6. Execute container smoke if Docker is running:
   ```powershell
   npm run deploy:preflight -- -BuildImage -SmokeContainer -ImageTag qwen-ci-autopilot:local
   ```
7. Generate submission packet with your real links:
   ```powershell
   npm run hackathon:submission-packet -- -RepoUrl "https://github.com/zemeng2015/qwen-ci-autopilot" -DemoVideoUrl "https://www.youtube.com/..."
   ```
8. Open packet output and copy ready-to-paste Devpost fields to the form.
9. Re-check Devpost required fields and submit.
