import { describe, expect, it } from 'vitest'
import { runAutopilot } from './orchestrator.js'
import { getQwenSettings } from './qwenClient.js'

describe('runAutopilot', () => {
  it('returns deterministic demo evidence without a Qwen key', async () => {
    const run = await runAutopilot({
      scenarioId: 'java-ci-coverage-gate',
      useLiveQwen: false,
    })

    expect(run.provider).toBe('demo-fixture')
    expect(run.steps).toHaveLength(5)
    expect(run.model).toBeTruthy()
    expect(run.cloudEvidence.repoCodeFile).toContain('deploy/alibaba')
  })

  it('requires approval for production-sensitive signals', async () => {
    const run = await runAutopilot({
      scenarioId: 'production-alert',
      useLiveQwen: false,
    })

    expect(run.checkpoint.status).toBe('approval_required')
    expect(run.checkpoint.riskLevel).toBe('high')
  })

  it('falls back to default Qwen settings when env overrides are blank', () => {
    const previousBaseUrl = process.env.QWEN_BASE_URL
    const previousModel = process.env.QWEN_MODEL

    process.env.QWEN_BASE_URL = ''
    process.env.QWEN_MODEL = ''

    try {
      const settings = getQwenSettings()
      expect(settings.baseUrl).toBe('https://dashscope-intl.aliyuncs.com/compatible-mode/v1')
      expect(settings.model).toBe('qwen3.7-plus')
    } finally {
      if (previousBaseUrl === undefined) {
        delete process.env.QWEN_BASE_URL
      } else {
        process.env.QWEN_BASE_URL = previousBaseUrl
      }

      if (previousModel === undefined) {
        delete process.env.QWEN_MODEL
      } else {
        process.env.QWEN_MODEL = previousModel
      }
    }
  })
})
