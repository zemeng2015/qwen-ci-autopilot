import OpenAI from 'openai'

export interface QwenSettings {
  apiKey?: string
  baseUrl: string
  model: string
  liveReady: boolean
}

export interface QwenStageResult {
  headline?: string
  bullets?: string[]
  decisions?: string[]
  toolCalls?: string[]
  confidence?: number
  artifact?: string
}

export function getQwenSettings(): QwenSettings {
  const apiKey = firstNonBlank(process.env.DASHSCOPE_API_KEY, process.env.QWEN_API_KEY)
  const baseUrl =
    firstNonBlank(process.env.QWEN_BASE_URL, process.env.DASHSCOPE_BASE_URL) ??
    'https://dashscope-intl.aliyuncs.com/compatible-mode/v1'
  const model = firstNonBlank(process.env.QWEN_MODEL) ?? 'qwen3.7-plus'

  return {
    apiKey,
    baseUrl,
    model,
    liveReady: Boolean(apiKey),
  }
}

function firstNonBlank(...values: Array<string | undefined>): string | undefined {
  return values.find((value) => value && value.trim().length > 0)
}

export async function askQwenStage(
  settings: QwenSettings,
  stageName: string,
  stageInstruction: string,
  incidentText: string,
  localEvidence: unknown,
): Promise<QwenStageResult> {
  if (!settings.apiKey) {
    throw new Error('DASHSCOPE_API_KEY is not configured')
  }

  const client = new OpenAI({
    apiKey: settings.apiKey,
    baseURL: settings.baseUrl,
  })

  const completion = await client.chat.completions.create({
    model: settings.model,
    temperature: 0.2,
    response_format: { type: 'json_object' },
    messages: [
      {
        role: 'system',
        content:
          'You are one stage inside a production CI remediation autopilot. Respond with strict JSON only. The JSON keys must be headline, bullets, decisions, toolCalls, confidence, artifact.',
      },
      {
        role: 'user',
        content: JSON.stringify(
          {
            stageName,
            stageInstruction,
            requiredJsonShape: {
              headline: 'one sentence',
              bullets: ['3 to 5 concise findings'],
              decisions: ['1 to 3 concrete decisions'],
              toolCalls: ['tool names or commands you would invoke'],
              confidence: 'number from 0 to 1',
              artifact: 'short markdown artifact for this stage',
            },
            localEvidence,
            incidentText,
          },
          null,
          2,
        ),
      },
    ],
  } as never)

  const content = completion.choices[0]?.message?.content ?? '{}'
  return parseJsonObject(content)
}

function parseJsonObject(content: string): QwenStageResult {
  try {
    return JSON.parse(content) as QwenStageResult
  } catch {
    const match = content.match(/\{[\s\S]*\}/)
    if (!match) {
      throw new Error('Qwen response did not contain JSON')
    }

    return JSON.parse(match[0]) as QwenStageResult
  }
}
