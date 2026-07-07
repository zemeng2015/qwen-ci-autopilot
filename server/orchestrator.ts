import { inspectSignal, scoreRisk } from './localTools.js'
import { askQwenStage, getQwenSettings, type QwenStageResult } from './qwenClient.js'
import { getScenario } from './scenarios.js'

export interface RunAutopilotInput {
  scenarioId: string
  customInput?: string
  useLiveQwen?: boolean
}

export interface AgentStep {
  id: string
  title: string
  agent: string
  status: 'complete' | 'waiting' | 'blocked'
  confidence: number
  durationMs: number
  summary: string
  bullets: string[]
  toolCalls: string[]
  artifact: string
}

export interface AutopilotRun {
  id: string
  createdAt: string
  provider: 'demo-fixture' | 'qwen-live' | 'qwen-fallback'
  model: string
  baseUrl: string
  region: string
  scenarioId: string
  scenarioTitle: string
  summary: string
  steps: AgentStep[]
  checkpoint: {
    status: 'approval_required' | 'approved'
    riskLevel: 'low' | 'medium' | 'high'
    reason: string
    approvalQuestion: string
  }
  artifacts: Array<{
    name: string
    path: string
    kind: string
    status: 'ready' | 'draft' | 'blocked'
  }>
  commands: string[]
  metrics: Array<{ label: string; value: string }>
  architectureProof: Array<{ label: string; value: string }>
  cloudEvidence: {
    deploymentTarget: string
    healthEndpoint: string
    repoCodeFile: string
    qwenApiBase: string
  }
}

const stageDefs = [
  {
    id: 'triage',
    title: 'Triage',
    agent: 'Signal Triage Agent',
    instruction:
      'Classify the incident, isolate the smallest failing surface, and identify ambiguity that must be resolved before patching.',
  },
  {
    id: 'reproducer',
    title: 'Reproducer',
    agent: 'Reproducer Agent',
    instruction:
      'Choose the minimum commands and local checks needed to reproduce the failure and validate the suspected files.',
  },
  {
    id: 'patch',
    title: 'Patch Planner',
    agent: 'Patch Planner Agent',
    instruction:
      'Create a scoped patch plan. Prefer tests and guard clauses before broad production behavior changes.',
  },
  {
    id: 'risk',
    title: 'Risk Review',
    agent: 'Risk Review Agent',
    instruction:
      'Identify business, security, data, and production risks. Decide where human approval is required.',
  },
  {
    id: 'verification',
    title: 'Verification',
    agent: 'Verification Agent',
    instruction:
      'Build the evidence plan: exact commands, expected outputs, rollback notes, and repository artifacts to save.',
  },
]

export async function runAutopilot(input: RunAutopilotInput): Promise<AutopilotRun> {
  const settings = getQwenSettings()
  const scenario = getScenario(input.scenarioId)
  const incidentText = input.customInput?.trim() || scenario.input
  const evidence = inspectSignal(incidentText)

  if (input.useLiveQwen && settings.liveReady) {
    try {
      const steps = await runLiveStages(incidentText, evidence)
      return buildRun({
        provider: 'qwen-live',
        scenarioId: scenario.id,
        scenarioTitle: scenario.title,
        steps,
        incidentText,
      })
    } catch (error) {
      const steps = buildDemoSteps(evidence)
      steps[0] = {
        ...steps[0],
        summary: `Live Qwen call fell back to deterministic demo: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      }

      return buildRun({
        provider: 'qwen-fallback',
        scenarioId: scenario.id,
        scenarioTitle: scenario.title,
        steps,
        incidentText,
      })
    }
  }

  return buildRun({
    provider: 'demo-fixture',
    scenarioId: scenario.id,
    scenarioTitle: scenario.title,
    steps: buildDemoSteps(evidence),
    incidentText,
  })
}

async function runLiveStages(
  incidentText: string,
  evidence: ReturnType<typeof inspectSignal>,
): Promise<AgentStep[]> {
  const settings = getQwenSettings()
  const started = Date.now()
  const steps: AgentStep[] = []

  for (const stage of stageDefs) {
    const stageStarted = Date.now()
    const result = await askQwenStage(
      settings,
      stage.title,
      stage.instruction,
      incidentText,
      {
        evidence,
        previousSteps: steps.map((step) => ({
          title: step.title,
          summary: step.summary,
          bullets: step.bullets,
        })),
      },
    )

    steps.push(stageToAgentStep(stage, result, Date.now() - stageStarted))
  }

  if (Date.now() - started < 900) {
    await new Promise((resolve) => setTimeout(resolve, 900))
  }

  return steps
}

function buildRun({
  provider,
  scenarioId,
  scenarioTitle,
  steps,
  incidentText,
}: {
  provider: AutopilotRun['provider']
  scenarioId: string
  scenarioTitle: string
  steps: AgentStep[]
  incidentText: string
}): AutopilotRun {
  const settings = getQwenSettings()
  const evidence = inspectSignal(incidentText)
  const riskLevel = scoreRisk(evidence)
  const approvalRequired = riskLevel === 'high'

  return {
    id: `run_${Date.now().toString(36)}`,
    createdAt: new Date().toISOString(),
    provider,
    model: settings.model,
    baseUrl: settings.baseUrl,
    region: process.env.ALIBABA_CLOUD_REGION ?? 'us-east-1',
    scenarioId,
    scenarioTitle,
    summary:
      riskLevel === 'high'
        ? 'Autopilot prepared a remediation plan and stopped before risky production-impacting changes.'
        : 'Autopilot prepared a scoped remediation plan with commands and review evidence.',
    steps,
    checkpoint: {
      status: approvalRequired ? 'approval_required' : 'approved',
      riskLevel,
      reason: approvalRequired
        ? 'The signal touches production, financial logic, data policy, or cloud signing behavior.'
        : 'The proposed changes stay inside test or low-risk validation surfaces.',
      approvalQuestion:
        'Approve the scoped patch plan and verification commands before applying repository changes?',
    },
    artifacts: [
      {
        name: 'Remediation plan',
        path: 'artifacts/remediation-plan.md',
        kind: 'markdown',
        status: 'ready',
      },
      {
        name: 'Patch intent',
        path: 'artifacts/patch-intent.diff',
        kind: 'diff',
        status: approvalRequired ? 'blocked' : 'draft',
      },
      {
        name: 'Verification evidence',
        path: 'artifacts/verification-evidence.json',
        kind: 'json',
        status: 'ready',
      },
    ],
    commands: buildCommands(evidence),
    metrics: [
      { label: 'External tools', value: String(evidence.suggestedTools.length) },
      { label: 'Risk signals', value: String(evidence.riskSignals.length) },
      { label: 'Human gates', value: approvalRequired ? '1' : '0' },
      { label: 'Model route', value: provider === 'qwen-live' ? 'live' : 'demo' },
    ],
    architectureProof: [
      { label: 'Frontend', value: 'React + Vite engineering dashboard' },
      { label: 'Backend', value: 'Express orchestrator with staged agent loop' },
      { label: 'Qwen Cloud', value: `${settings.model} via OpenAI-compatible API` },
      { label: 'Alibaba deploy', value: 'Function Compute custom container' },
    ],
    cloudEvidence: {
      deploymentTarget: 'Alibaba Cloud Function Compute custom container',
      healthEndpoint: '/api/health',
      repoCodeFile: 'deploy/alibaba/serverless-devs.yaml',
      qwenApiBase: settings.baseUrl,
    },
  }
}

function stageToAgentStep(
  stage: (typeof stageDefs)[number],
  result: QwenStageResult,
  durationMs: number,
): AgentStep {
  return {
    id: stage.id,
    title: stage.title,
    agent: stage.agent,
    status: 'complete',
    confidence: clamp(Number(result.confidence ?? 0.78)),
    durationMs,
    summary: result.headline ?? `${stage.agent} completed its analysis.`,
    bullets: ensureStringArray(result.bullets).slice(0, 5),
    toolCalls: ensureStringArray(result.toolCalls).slice(0, 5),
    artifact: result.artifact ?? '',
  }
}

function buildDemoSteps(evidence: ReturnType<typeof inspectSignal>): AgentStep[] {
  const primaryFile = evidence.files[0] ?? 'src/main/...'
  const primaryCommand = evidence.commands[0] ?? 'npm test'
  const highRisk = scoreRisk(evidence) === 'high'

  return [
    {
      id: 'triage',
      title: 'Triage',
      agent: 'Signal Triage Agent',
      status: 'complete',
      confidence: 0.86,
      durationMs: 420,
      summary: 'The failure is scoped to a small remediation surface with explicit review constraints.',
      bullets: [
        `${evidence.errors.length || 1} failure signals extracted from the incident text.`,
        `${evidence.files.length || 1} likely source or test files identified.`,
        highRisk
          ? 'Production or policy-sensitive language requires a human checkpoint.'
          : 'No production-impacting language was detected in the input.',
      ],
      toolCalls: ['log-parser', 'repo-file-finder'],
      artifact: `Primary file: ${primaryFile}`,
    },
    {
      id: 'reproducer',
      title: 'Reproducer',
      agent: 'Reproducer Agent',
      status: 'complete',
      confidence: 0.82,
      durationMs: 510,
      summary: 'The reproduction path uses the narrowest available command before broader regression checks.',
      bullets: [
        `Start with ${primaryCommand}.`,
        'Capture failing stack trace and coverage delta as immutable evidence.',
        'Run a targeted test before full pipeline verification.',
      ],
      toolCalls: evidence.suggestedTools.slice(0, 4),
      artifact: `Repro command: ${primaryCommand}`,
    },
    {
      id: 'patch',
      title: 'Patch Planner',
      agent: 'Patch Planner Agent',
      status: 'complete',
      confidence: 0.79,
      durationMs: 650,
      summary: 'Patch scope is constrained to guard behavior, test coverage, and observable failure evidence.',
      bullets: [
        'Add a regression test that reproduces the current failure first.',
        'Prefer a narrow null/edge guard or fallback path over broad algorithm changes.',
        'Save a patch-intent diff for reviewer inspection before writes are applied.',
      ],
      toolCalls: ['patch-intent-writer', 'coverage-gap-reader'],
      artifact: 'Patch intent waits for checkpoint when risk is high.',
    },
    {
      id: 'risk',
      title: 'Risk Review',
      agent: 'Risk Review Agent',
      status: 'complete',
      confidence: 0.9,
      durationMs: 390,
      summary: highRisk
        ? 'Risk review stops the autopilot before production-sensitive edits.'
        : 'Risk review allows the plan to proceed with standard reviewer evidence.',
      bullets: [
        ...evidence.riskSignals.map((signal) => `Risk signal: ${signal}.`),
        highRisk
          ? 'Human approval is mandatory before applying patch-intent.diff.'
          : 'Reviewer approval can happen after the patch is generated.',
      ].slice(0, 5),
      toolCalls: ['policy-guardrail', 'risk-classifier'],
      artifact: highRisk ? 'Checkpoint: approval_required' : 'Checkpoint: approved',
    },
    {
      id: 'verification',
      title: 'Verification',
      agent: 'Verification Agent',
      status: highRisk ? 'waiting' : 'complete',
      confidence: 0.84,
      durationMs: 470,
      summary: 'Verification package includes targeted tests, full build, and deployment health evidence.',
      bullets: [
        'Run targeted test command and full repository test command.',
        'Record before/after coverage and command output checksums.',
        'Confirm /api/health on Alibaba Cloud after deployment.',
      ],
      toolCalls: ['test-runner', 'evidence-recorder', 'deploy-health-check'],
      artifact: 'Verification evidence: artifacts/verification-evidence.json',
    },
  ]
}

function buildCommands(evidence: ReturnType<typeof inspectSignal>): string[] {
  const commands = evidence.commands.length > 0 ? evidence.commands : ['npm test']
  return [
    commands[0],
    'npm run test',
    'npm run build',
    'curl $ALIBABA_BACKEND_URL/api/health',
  ]
}

function ensureStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.map((item) => String(item)).filter(Boolean)
}

function clamp(value: number): number {
  if (Number.isNaN(value)) {
    return 0.75
  }

  return Math.max(0, Math.min(1, value))
}
