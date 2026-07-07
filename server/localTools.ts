export interface LocalEvidence {
  files: string[]
  commands: string[]
  errors: string[]
  constraints: string[]
  riskSignals: string[]
  suggestedTools: string[]
}

const filePattern =
  /(?:[\w.-]+\/)*(?:src|server|app|payments-service|packages|test)[\w./-]+\.(?:ts|tsx|js|java|py|yml|yaml|json)/g
const commandPattern =
  /(?:mvn|npm|pnpm|yarn|pytest|gradle|go test|docker|kubectl|aws|aliyun)\s+[^\n\r]+/gi
const errorPattern =
  /(?:Error|Exception|Failure|HTTP\s\d{3}|CloudWatch alarm|Coverage gate|java\.lang\.[\w.]+)[^\n\r]*/gi

export function inspectSignal(input: string): LocalEvidence {
  const files = uniq(input.match(filePattern) ?? []).slice(0, 8)
  const commands = uniq(input.match(commandPattern) ?? []).slice(0, 6)
  const errors = uniq(input.match(errorPattern) ?? []).slice(0, 8)
  const constraints = input
    .split(/\r?\n/)
    .filter((line) => /constraint|do not|approval|robots\.txt|product-owner/i.test(line))
    .map((line) => line.trim())
    .filter(Boolean)
    .slice(0, 6)

  const lower = input.toLowerCase()
  const riskSignals = [
    lower.includes('production') || lower.includes('cloudwatch')
      ? 'production-impact'
      : undefined,
    lower.includes('pricing') || lower.includes('payment') ? 'financial-logic' : undefined,
    lower.includes('s3') || lower.includes('signed url') ? 'cloud-storage' : undefined,
    lower.includes('robots.txt') || lower.includes('authenticated')
      ? 'data-access-policy'
      : undefined,
    lower.includes('coverage') ? 'quality-gate' : undefined,
  ].filter((signal): signal is string => Boolean(signal))

  return {
    files,
    commands,
    errors,
    constraints,
    riskSignals,
    suggestedTools: buildToolPlan(input, riskSignals),
  }
}

export function scoreRisk(evidence: LocalEvidence): 'low' | 'medium' | 'high' {
  if (
    evidence.riskSignals.includes('production-impact') ||
    evidence.riskSignals.includes('financial-logic') ||
    evidence.riskSignals.includes('data-access-policy')
  ) {
    return 'high'
  }

  if (evidence.riskSignals.includes('cloud-storage') || evidence.errors.length > 2) {
    return 'medium'
  }

  return 'low'
}

function buildToolPlan(input: string, riskSignals: string[]): string[] {
  const tools = ['log-parser', 'repo-file-finder']

  if (/mvn|java|jacoco/i.test(input)) {
    tools.push('maven-test-runner', 'jacoco-reader')
  }

  if (/npm|typescript|angular|react/i.test(input)) {
    tools.push('typescript-test-runner')
  }

  if (riskSignals.includes('cloud-storage')) {
    tools.push('cloud-config-checker')
  }

  if (riskSignals.includes('data-access-policy')) {
    tools.push('policy-guardrail')
  }

  return uniq(tools)
}

function uniq(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean)))
}
