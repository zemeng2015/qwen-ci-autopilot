# Alibaba Cloud Deployment Proof

Devpost requires proof that the backend runs on Alibaba Cloud. This project is
prepared for Alibaba Cloud Function Compute using a custom container.

## Required Files

- `Dockerfile`
- `deploy/alibaba/serverless-devs.yaml`
- `.env.example`

## Build Container

Run the deploy preflight first:

```powershell
npm run deploy:preflight
```

To also verify the local Docker image build path:

```powershell
npm run deploy:preflight -- -BuildImage -SmokeContainer -ImageTag qwen-ci-autopilot:local
```

```powershell
docker build -t qwen-ci-autopilot:latest .
```

Push the image to Alibaba Cloud Container Registry, then export the image URL:

```powershell
$env:ACR_IMAGE="registry-intl.us-east-1.aliyuncs.com/<namespace>/qwen-ci-autopilot:latest"
```

## Deploy With Serverless Devs

Install and configure Serverless Devs with an Alibaba Cloud access profile:

```powershell
npm install -g @serverless-devs/s
s config add
```

Then deploy:

```powershell
cd deploy/alibaba
s deploy
```

Required environment variables:

```powershell
$env:DASHSCOPE_API_KEY="sk-your-qwen-cloud-key"
$env:ALIBABA_CLOUD_REGION="us-east-1"
$env:ALIBABA_CLOUD_SERVICE="qwen-ci-autopilot-api"
```

## Proof Recording Checklist

Record a short clip separate from the main demo:

1. Show the Function Compute service in Alibaba Cloud.
2. Show the deployed endpoint URL.
3. Call `GET /api/health`.
4. Show JSON containing:
   - `deploymentTarget`
   - `region`
   - `qwen.model`
   - `proofFile`
5. Briefly show this repository file:
   `deploy/alibaba/serverless-devs.yaml`.

## Expected Health Response

```json
{
  "ok": true,
  "service": "qwen-ci-autopilot-api",
  "deploymentTarget": "Alibaba Cloud Function Compute custom container",
  "region": "us-east-1",
  "qwen": {
    "model": "qwen3.7-plus",
    "baseUrl": "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    "liveReady": true
  },
  "proofFile": "deploy/alibaba/serverless-devs.yaml"
}
```
