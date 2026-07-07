# Qwen Cloud Submission Final 5-Minute Checklist

Run this in the last 5 minutes before submission.

1. Confirm codebase requirements in Devpost form:
   - Public repository URL
   - Project description
   - Track = `Track 4: Autopilot Agent`
   - Text explanation of workflow and impact
2. Confirm all required links are present:
   - GitHub repository (public)
   - `deploy/alibaba/serverless-devs.yaml` (deployment proof link)
   - `docs/architecture.svg` and `docs/architecture.md` (architecture diagram)
   - demo video URL (YouTube/Vimeo/Youku, <=3:00)
3. Confirm local/run-time proof:
   - `/api/health` works on backend URL
   - proof response includes:
     - `service`
     - `deploymentTarget`
     - `region`
     - `qwen.model`
     - `proofFile`
4. Execute audit command and attach outputs:
   ```powershell
   npm run hackathon:audit
   ```
5. Generate submission packet with your real links:
   ```powershell
   npm run hackathon:submission-packet -- -RepoUrl "https://github.com/<you>/<repo>" -DemoVideoUrl "https://www.youtube.com/..."
   ```
6. Open packet output and copy ready-to-paste Devpost fields to the form.
7. Re-check Devpost required fields and submit.
