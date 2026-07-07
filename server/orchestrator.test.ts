import { describe, expect, it } from 'vitest'
import { runAutopilot } from './orchestrator.js'

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
})
