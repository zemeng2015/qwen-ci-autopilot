# Qwen CI Autopilot

Qwen CI Autopilot is a production-minded Track 4: Autopilot Agent project for the
Qwen Cloud hackathon. It turns ambiguous CI failures, coverage gates, and
production alerts into a staged remediation workflow with local evidence, optional
Qwen Cloud reasoning, and human-in-the-loop checkpoints before risky actions.

The app is built to match Devpost requirements:

- Qwen Cloud integration (`qwen3.7-plus`).
- Public, open-source repository baseline.
- Alibaba Cloud deployment proof.
- Architecture diagram.
- <=3 minute demonstration-ready behavior.

## Hackathon Fit (Qwen Cloud)

- Track: Track 4: Autopilot Agent.
- Use case: automated engineering workflow agent for ambiguous incidents.
- Core integration: `qwen3.7-plus` via OpenAI-compatible Qwen Cloud API.
- Safety model: local evidence parser + deterministic fallback when no key is
  available.

## Submission-ready features

- Uses local tools first (signal parsing, command/file extraction, risk signals).
- Calls Qwen Cloud when `DASHSCOPE_API_KEY` is configured.
- Includes a dedicated verification + human checkpoint stage.
- Uses Alibaba Cloud Function Compute as backend target.
- Provides submission artifacts for Devpost:
  - `deploy/alibaba/serverless-devs.yaml`
  - `docs/architecture.svg`
  - `docs/architecture.md`

## What It Does

1. Accepts a CI failure, coverage gate, crawler incident, or production alert.
2. Extracts local evidence such as commands, files, stack traces, constraints, and
   risk signals.
3. Runs five staged agents:
   - Signal Triage Agent
   - Reproducer Agent
   - Patch Planner Agent
   - Risk Review Agent
   - Verification Agent
4. Calls Qwen Cloud when configured, otherwise uses deterministic demo flow.
5. Produces review artifacts, command evidence, architecture proof, and deployment
   health metadata.

## Local Setup

```powershell
npm install
Copy-Item .env.example .env
```

Set your Qwen Cloud key:

```powershell
$env:DASHSCOPE_API_KEY="sk-your-qwen-cloud-key"
```

Run full stack:

```powershell
npm run dev
```

Open frontend at the Vite URL (usually `http://127.0.0.1:5173`) and API at
`http://127.0.0.1:8787`.

## Verification and Submission Readiness

### Local checks

```powershell
npm run test
npm run build
```

Useful API checks:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/api/health
Invoke-RestMethod http://127.0.0.1:8787/api/scenarios
```

### Full pre-submit gate

```powershell
npm run hackathon:audit
```

Optional:

```powershell
npm run hackathon:verify
npm run hackathon:proof
npm run hackathon:submit-gate
npm run hackathon:submission-packet -- -RepoUrl "https://github.com/<you>/<repo>" -DemoVideoUrl "https://www.youtube.com/watch?v=..."
```

## Qwen Cloud Configuration

- `DASHSCOPE_API_KEY` (required for live Qwen calls)
- `QWEN_BASE_URL` default: `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
- `QWEN_MODEL` default: `qwen3.7-plus`
- `ALIBABA_CLOUD_REGION` default: `us-east-1`

Optional override:

```powershell
$env:QWEN_MODEL="qwen3.7-max"
$env:QWEN_BASE_URL="https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
```

## Deployment

Target deployment: Alibaba Cloud Function Compute custom container.

Required files:

- [`Dockerfile`](Dockerfile)
- [`deploy/alibaba/serverless-devs.yaml`](deploy/alibaba/serverless-devs.yaml)
- [`docs/deployment/alibaba-cloud.md`](docs/deployment/alibaba-cloud.md)

After deployment, record a short proof clip that shows:

1. The Alibaba Cloud Function Compute service.
2. The deployed endpoint URL.
3. `GET /api/health` returning service, region, Qwen model, and proof file.

### Submission artifacts

Look in `artifacts/qwencloud-proof/` for:

- `submission-audit-*.json` (final status report)
- `submission-proof-*.json` / `.md` (deployment proof snapshot)
- `submission-gate-*.json` / `.md` (file + repo checks)

## References

- Qwen Cloud hackathon: https://qwencloud-hackathon.devpost.com/
- Qwen Cloud first API call: https://docs.qwencloud.com/developer-guides/getting-started/first-api-call
- Qwen Cloud model overview: https://docs.qwencloud.com/developer-guides/getting-started/introduction
- Alibaba Cloud OpenAI-compatible API docs: https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope

## License

MIT. See [`LICENSE`](LICENSE).
