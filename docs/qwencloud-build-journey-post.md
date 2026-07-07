# Qwen Cloud Build Journey Post Draft

Optional public post for the Qwen Cloud hackathon blog/social bonus category.

## Suggested title

Building Qwen CI Autopilot: A Human-Gated Agent for Production Engineering

## Draft post

For the Qwen Cloud Hackathon, I built Qwen CI Autopilot: a Track 4 Autopilot
Agent that helps engineering teams turn ambiguous CI failures and production
alerts into safe remediation workflows.

The core idea is simple: production automation should not blindly patch systems.
It should first gather evidence, explain the smallest failing surface, produce a
reproducible verification plan, and stop for human approval when the change
touches production, financial logic, data policy, cloud signing, or other
sensitive paths.

The workflow has five stages:

1. Signal Triage Agent
2. Reproducer Agent
3. Patch Planner Agent
4. Risk Review Agent
5. Verification Agent

The backend extracts local evidence first, including stack traces, commands,
candidate files, constraints, and risk signals. When a Qwen Cloud API key is
configured, each stage can call `qwen3.7-plus` through the OpenAI-compatible API
and return structured JSON. If the key or quota is unavailable, the app uses a
deterministic fallback so judges can still test the full workflow.

For deployment readiness, the project includes a Docker build, a local container
smoke check, Alibaba Cloud Function Compute configuration, a `/api/health`
deployment proof endpoint, architecture docs, and GitHub Actions CI.

Project:
https://github.com/zemeng2015/qwen-ci-autopilot

What I learned: the strongest agent demos are not just about model output. The
real value comes from the boundaries around the model: local evidence, structured
contracts, reproducible commands, risk-aware checkpoints, and clear deployment
proof.

## Suggested hashtags

#QwenCloud #AlibabaCloud #Hackathon #AIAgents #DeveloperTools #CICD
