# Live Deployment Checklist (Judging-Ready)

Use this before uploading final demo links.

1. Backend live endpoint
   - Run `npm run deploy:preflight` before deploying.
   - Open backend URL from Alibaba Cloud Function Compute.
   - Confirm `GET /api/health` returns HTTP 200 and JSON body.
2. Health checks to verify
   - `ok` is true
   - `service` matches your function service name
   - `deploymentTarget` contains Function Compute
   - `region` is your configured region
   - `proofFile` points to `deploy/alibaba/serverless-devs.yaml`
   - `qwen.baseUrl` and `qwen.model` are set
3. Scenario checks
   - `GET /api/scenarios` returns scenario array (>=1).
4. Capture deployment proof proof-file in terminal/video:
   ```powershell
   Invoke-RestMethod http://<your-deployed-backend>/api/health
   ```
5. In the same run, execute:
   ```powershell
   npm run hackathon:verify
   npm run hackathon:proof
   ```
6. Save artifacts in `artifacts/qwencloud-proof/` and include paths in final notes.
