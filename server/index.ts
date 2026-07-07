import cors from 'cors'
import dotenv from 'dotenv'
import express from 'express'
import { existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { z } from 'zod'
import { runAutopilot } from './orchestrator.js'
import { getQwenSettings } from './qwenClient.js'
import { scenarios } from './scenarios.js'

dotenv.config()

const app = express()
const port = Number(process.env.PORT ?? 8787)
const runRequestSchema = z.object({
  scenarioId: z.string().min(1),
  customInput: z.string().max(25_000).optional(),
  useLiveQwen: z.boolean().optional(),
})

app.use(cors())
app.use(express.json({ limit: '1mb' }))

app.get('/api/health', (_request, response) => {
  const settings = getQwenSettings()

  response.json({
    ok: true,
    service: process.env.ALIBABA_CLOUD_SERVICE ?? 'qwen-ci-autopilot-api',
    deploymentTarget: 'Alibaba Cloud Function Compute custom container',
    region: process.env.ALIBABA_CLOUD_REGION ?? 'us-east-1',
    track: 'Track 4: Autopilot Agent',
    qwen: {
      model: settings.model,
      baseUrl: settings.baseUrl,
      liveReady: settings.liveReady,
    },
    proofFile: 'deploy/alibaba/serverless-devs.yaml',
    generatedAt: new Date().toISOString(),
  })
})

app.get('/api/scenarios', (_request, response) => {
  response.json({ scenarios })
})

app.post('/api/autopilot/run', async (request, response) => {
  const parsed = runRequestSchema.safeParse(request.body)
  if (!parsed.success) {
    response.status(400).json({
      error: 'Invalid run request',
      details: parsed.error.flatten(),
    })
    return
  }

  try {
    const run = await runAutopilot(parsed.data)
    response.json(run)
  } catch (error) {
    response.status(500).json({
      error: 'Autopilot run failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    })
  }
})

const __dirname = dirname(fileURLToPath(import.meta.url))
const staticDir = join(__dirname, '..', 'dist')

if (existsSync(staticDir)) {
  app.use(express.static(staticDir))
  app.get('*splat', (_request, response) => {
    response.sendFile(join(staticDir, 'index.html'))
  })
}

app.listen(port, () => {
  console.log(`Qwen CI Autopilot API listening on http://127.0.0.1:${port}`)
})
