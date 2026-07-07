import {
  Activity,
  AlertTriangle,
  Braces,
  CheckCircle2,
  ChevronRight,
  CirclePause,
  Cloud,
  FileText,
  GitBranch,
  Loader2,
  Play,
  Radio,
  ServerCog,
  ShieldCheck,
  Terminal,
  Workflow,
} from 'lucide-react'
import { useEffect, useMemo, useState, type CSSProperties, type ReactNode } from 'react'
import './App.css'

interface Scenario {
  id: string
  title: string
  owner: string
  signal: string
  risk: 'low' | 'medium' | 'high'
  description: string
  input: string
}

interface HealthResponse {
  ok: boolean
  service: string
  deploymentTarget: string
  region: string
  track: string
  proofFile: string
  qwen: {
    model: string
    baseUrl: string
    liveReady: boolean
  }
}

interface AgentStep {
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

interface AutopilotRun {
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

function App() {
  const [health, setHealth] = useState<HealthResponse | null>(null)
  const [scenarios, setScenarios] = useState<Scenario[]>([])
  const [selectedScenarioId, setSelectedScenarioId] = useState('java-ci-coverage-gate')
  const [customInput, setCustomInput] = useState('')
  const [useLiveQwen, setUseLiveQwen] = useState(false)
  const [run, setRun] = useState<AutopilotRun | null>(null)
  const [approved, setApproved] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    Promise.all([
      fetch('/api/health').then((response) => response.json()),
      fetch('/api/scenarios').then((response) => response.json()),
    ])
      .then(([healthData, scenarioData]) => {
        if (cancelled) {
          return
        }

        setHealth(healthData)
        setScenarios(scenarioData.scenarios ?? [])
        setUseLiveQwen(Boolean(healthData.qwen?.liveReady))
      })
      .catch((fetchError: unknown) => {
        if (!cancelled) {
          setError(fetchError instanceof Error ? fetchError.message : 'API is not reachable')
        }
      })

    return () => {
      cancelled = true
    }
  }, [])

  const selectedScenario = useMemo(
    () => scenarios.find((scenario) => scenario.id === selectedScenarioId) ?? scenarios[0],
    [scenarios, selectedScenarioId],
  )

  const visibleInput = customInput || selectedScenario?.input || ''
  const progress = run ? (approved || run.checkpoint.status === 'approved' ? 100 : 82) : 0
  const providerLabel =
    run?.provider === 'qwen-live'
      ? 'Live Qwen Cloud'
      : run?.provider === 'qwen-fallback'
        ? 'Qwen fallback'
        : 'Demo fallback'

  async function handleRun() {
    setLoading(true)
    setError(null)
    setApproved(false)

    try {
      const response = await fetch('/api/autopilot/run', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          scenarioId: selectedScenarioId,
          customInput,
          useLiveQwen,
        }),
      })

      if (!response.ok) {
        throw new Error(`Run failed with ${response.status}`)
      }

      setRun((await response.json()) as AutopilotRun)
    } catch (runError) {
      setError(runError instanceof Error ? runError.message : 'Autopilot run failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Primary">
        <div className="brand">
          <div className="brand-mark">
            <Braces size={19} aria-hidden="true" />
          </div>
          <div>
            <strong>Qwen CI</strong>
            <span>Autopilot</span>
          </div>
        </div>

        <nav className="nav-list">
          <a className="nav-item active" href="#incidents">
            <Activity size={17} aria-hidden="true" />
            Incidents
          </a>
          <a className="nav-item" href="#runs">
            <Workflow size={17} aria-hidden="true" />
            Runs
          </a>
          <a className="nav-item" href="#evidence">
            <FileText size={17} aria-hidden="true" />
            Evidence
          </a>
        </nav>

        <div className="sidebar-status">
          <span className="status-dot" />
          <span>{health?.region ?? 'local'} backend</span>
        </div>
      </aside>

      <main className="workspace">
        <header className="topbar">
          <div>
            <h1>Qwen CI Autopilot</h1>
            <p>Production remediation agent for CI failures, coverage gates, and cloud alerts.</p>
          </div>

          <div className="topbar-actions">
            <StatusPill icon={<Radio size={14} />} tone={health?.qwen.liveReady ? 'good' : 'muted'}>
              {health?.qwen.model ?? 'qwen3.7-plus'}
            </StatusPill>
            <StatusPill icon={<Cloud size={14} />} tone="info">
              Alibaba Cloud
            </StatusPill>
            <button className="primary-button" type="button" onClick={handleRun} disabled={loading}>
              {loading ? <Loader2 className="spin" size={16} /> : <Play size={16} />}
              Run Autopilot
            </button>
          </div>
        </header>

        {error && (
          <div className="error-strip" role="alert">
            <AlertTriangle size={16} aria-hidden="true" />
            {error}
          </div>
        )}

        <section className="board">
          <section className="panel input-panel" id="incidents">
            <PanelHeader
              icon={<GitBranch size={18} />}
              title="Workflow input"
              meta={selectedScenario?.owner ?? 'Loading'}
            />

            <label className="field-label" htmlFor="scenario">
              Scenario
            </label>
            <select
              id="scenario"
              value={selectedScenarioId}
              onChange={(event) => {
                setSelectedScenarioId(event.target.value)
                setCustomInput('')
              }}
            >
              {scenarios.map((scenario) => (
                <option key={scenario.id} value={scenario.id}>
                  {scenario.title}
                </option>
              ))}
            </select>

            {selectedScenario && (
              <div className="scenario-summary">
                <div>
                  <span className={`risk-text ${selectedScenario.risk}`}>{selectedScenario.risk}</span>
                  <strong>{selectedScenario.signal}</strong>
                </div>
                <p>{selectedScenario.description}</p>
              </div>
            )}

            <label className="field-label" htmlFor="input">
              CI signal
            </label>
            <textarea
              id="input"
              value={visibleInput}
              onChange={(event) => setCustomInput(event.target.value)}
              spellCheck={false}
            />

            <div className="switch-row">
              <label className="switch">
                <input
                  type="checkbox"
                  checked={useLiveQwen}
                  disabled={!health?.qwen.liveReady}
                  onChange={(event) => setUseLiveQwen(event.target.checked)}
                />
                <span />
                Live Qwen Cloud
              </label>
              <span>{health?.qwen.liveReady ? 'key ready' : 'demo fallback'}</span>
            </div>

            <div className="signal-grid">
              <MetricTile label="Mode" value={useLiveQwen ? 'live' : 'demo'} />
              <MetricTile label="Track" value={health?.track ?? 'Track 4: Autopilot Agent'} />
              <MetricTile label="Gate" value="human" />
            </div>
          </section>

          <section className="panel timeline-panel" id="runs">
            <PanelHeader
              icon={<Workflow size={18} />}
              title="Agent run"
              meta={run ? providerLabel : 'ready'}
            />

            <div className="run-summary">
              <div>
                <span className="run-id">{run?.id ?? 'run_pending'}</span>
                <h2>{run?.scenarioTitle ?? 'Run a scenario to generate remediation evidence'}</h2>
                <p>{run?.summary ?? 'Five staged agents will triage, reproduce, plan, review risk, and verify.'}</p>
              </div>
              <div
                className="progress-ring"
                style={
                  {
                    background: `conic-gradient(#0b8c80 ${progress * 3.6}deg, #e7edf0 0deg)`,
                  } as CSSProperties
                }
              >
                <span>{progress}%</span>
              </div>
            </div>

            <div className="progress-strip" aria-hidden="true">
              <span style={{ width: `${Math.max(progress, loading ? 28 : 0)}%` }} />
            </div>

            <div className="timeline">
              {(run?.steps ?? seedSteps).map((step) => {
                const locked =
                  step.id === 'verification' &&
                  run?.checkpoint.status === 'approval_required' &&
                  !approved

                return (
                  <article className={`step-row ${locked ? 'locked' : ''}`} key={step.id}>
                    <div className="step-status">
                      {locked ? (
                        <CirclePause size={17} aria-hidden="true" />
                      ) : (
                        <CheckCircle2 size={17} aria-hidden="true" />
                      )}
                    </div>
                    <div className="step-content">
                      <div className="step-heading">
                        <div>
                          <strong>{step.title}</strong>
                          <span>{step.agent}</span>
                        </div>
                        <code>{Math.round(step.confidence * 100)}%</code>
                      </div>
                      <p>{locked ? 'Waiting for human approval before verification executes.' : step.summary}</p>
                      <ul>
                        {step.bullets.slice(0, 3).map((bullet) => (
                          <li key={bullet}>{bullet}</li>
                        ))}
                      </ul>
                      <div className="tool-row">
                        {step.toolCalls.slice(0, 3).map((tool) => (
                          <span key={tool}>
                            <Terminal size={12} aria-hidden="true" />
                            {tool}
                          </span>
                        ))}
                      </div>
                    </div>
                  </article>
                )
              })}
            </div>
          </section>

          <aside className="panel evidence-panel" id="evidence">
            <PanelHeader icon={<ShieldCheck size={18} />} title="Evidence report" meta="judging proof" />

            <div className={`checkpoint ${run?.checkpoint.riskLevel ?? 'medium'}`}>
              <div className="checkpoint-title">
                <AlertTriangle size={17} aria-hidden="true" />
                <strong>{run?.checkpoint.status === 'approval_required' && !approved ? 'Approval required' : 'Approved path'}</strong>
              </div>
              <p>{run?.checkpoint.reason ?? 'Human checkpoint appears when the run touches production or policy-sensitive paths.'}</p>
              <button
                className="secondary-button"
                type="button"
                disabled={!run || run.checkpoint.status !== 'approval_required' || approved}
                onClick={() => setApproved(true)}
              >
                {approved ? <CheckCircle2 size={15} /> : <ShieldCheck size={15} />}
                {approved ? 'Checkpoint approved' : 'Approve plan'}
              </button>
            </div>

            <EvidenceSection title="Generated files" icon={<FileText size={16} />}>
              {(run?.artifacts ?? seedArtifacts).map((artifact) => (
                <div className="evidence-row" key={artifact.path}>
                  <div>
                    <strong>{artifact.name}</strong>
                    <code>{artifact.path}</code>
                  </div>
                  <span className={`artifact-status ${artifact.status}`}>{artifact.status}</span>
                </div>
              ))}
            </EvidenceSection>

            <EvidenceSection title="Commands" icon={<Terminal size={16} />}>
              {(run?.commands ?? seedCommands).map((command) => (
                <code className="command-line" key={command}>
                  {command}
                </code>
              ))}
            </EvidenceSection>

            <EvidenceSection title="Architecture proof" icon={<ServerCog size={16} />}>
              {(run?.architectureProof ?? seedArchitecture).map((item) => (
                <div className="proof-row" key={item.label}>
                  <span>{item.label}</span>
                  <strong>{item.value}</strong>
                </div>
              ))}
            </EvidenceSection>

            <div className="deploy-health">
              <Cloud size={17} aria-hidden="true" />
              <div>
                <strong>{health?.deploymentTarget ?? 'Alibaba Cloud Function Compute'}</strong>
                <span>{health?.proofFile ?? 'deploy/alibaba/serverless-devs.yaml'}</span>
              </div>
              <ChevronRight size={16} aria-hidden="true" />
            </div>
          </aside>
        </section>
      </main>
    </div>
  )
}

function PanelHeader({
  icon,
  title,
  meta,
}: {
  icon: ReactNode
  title: string
  meta: string
}) {
  return (
    <div className="panel-header">
      <div>
        {icon}
        <h2>{title}</h2>
      </div>
      <span>{meta}</span>
    </div>
  )
}

function StatusPill({
  icon,
  tone,
  children,
}: {
  icon: ReactNode
  tone: 'good' | 'info' | 'muted'
  children: ReactNode
}) {
  return (
    <span className={`status-pill ${tone}`}>
      {icon}
      {children}
    </span>
  )
}

function MetricTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric-tile">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function EvidenceSection({
  title,
  icon,
  children,
}: {
  title: string
  icon: ReactNode
  children: ReactNode
}) {
  return (
    <section className="evidence-section">
      <div className="evidence-heading">
        {icon}
        <h3>{title}</h3>
      </div>
      {children}
    </section>
  )
}

const seedSteps: AgentStep[] = [
  {
    id: 'triage',
    title: 'Triage',
    agent: 'Signal Triage Agent',
    status: 'waiting',
    confidence: 0.8,
    durationMs: 0,
    summary: 'Waiting for CI signal.',
    bullets: ['Extract stack traces.', 'Find changed files.', 'Mark ambiguity.'],
    toolCalls: ['log-parser'],
    artifact: '',
  },
  {
    id: 'reproducer',
    title: 'Reproducer',
    agent: 'Reproducer Agent',
    status: 'waiting',
    confidence: 0.78,
    durationMs: 0,
    summary: 'Minimum repro command will appear here.',
    bullets: ['Targeted command.', 'Evidence capture.', 'Baseline test.'],
    toolCalls: ['test-runner'],
    artifact: '',
  },
  {
    id: 'patch',
    title: 'Patch Planner',
    agent: 'Patch Planner Agent',
    status: 'waiting',
    confidence: 0.76,
    durationMs: 0,
    summary: 'Scoped patch plan waits for agent run.',
    bullets: ['Regression test first.', 'Small patch scope.', 'Diff intent.'],
    toolCalls: ['patch-intent'],
    artifact: '',
  },
  {
    id: 'risk',
    title: 'Risk Review',
    agent: 'Risk Review Agent',
    status: 'waiting',
    confidence: 0.74,
    durationMs: 0,
    summary: 'Risk guardrail will decide whether a human gate is needed.',
    bullets: ['Production impact.', 'Policy flags.', 'Approval reason.'],
    toolCalls: ['risk-classifier'],
    artifact: '',
  },
  {
    id: 'verification',
    title: 'Verification',
    agent: 'Verification Agent',
    status: 'waiting',
    confidence: 0.72,
    durationMs: 0,
    summary: 'Verification evidence waits for approval.',
    bullets: ['Tests.', 'Build.', 'Cloud health.'],
    toolCalls: ['evidence-recorder'],
    artifact: '',
  },
]

const seedArtifacts = [
  { name: 'Remediation plan', path: 'artifacts/remediation-plan.md', kind: 'markdown', status: 'draft' },
  { name: 'Patch intent', path: 'artifacts/patch-intent.diff', kind: 'diff', status: 'blocked' },
  { name: 'Verification evidence', path: 'artifacts/verification-evidence.json', kind: 'json', status: 'draft' },
] as AutopilotRun['artifacts']

const seedCommands = ['mvn -q test', 'npm run test', 'npm run build', 'curl $ALIBABA_BACKEND_URL/api/health']

const seedArchitecture = [
  { label: 'Frontend', value: 'React + Vite dashboard' },
  { label: 'Backend', value: 'Express agent orchestrator' },
  { label: 'Qwen Cloud', value: 'OpenAI-compatible chat API' },
  { label: 'Alibaba deploy', value: 'Function Compute container' },
]

export default App
