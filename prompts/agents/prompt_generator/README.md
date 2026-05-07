![Status](https://img.shields.io/badge/status-experimental-red)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/prompt-engineering-hub.svg?style=flat)]()
# Prompt Generator Agent
The Prompt Generator Agent is the autonomous counterpart of the [Prompt Generator assistant](../../assistants/prompt_generator/README.md).

It generates, reviews, and improves prompts in a single pass — no clarifying questions, no back-and-forth.

## Why Use the Prompt Generator Agent?

Use it when you want to generate prompts programmatically or as part of an automated workflow in Claude Code.

It applies the same prompt engineering best practices as the assistant version, drawn from the documentation of [Anthropic](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview), [OpenAI](https://platform.openai.com/docs/guides/) and [Google's Gemini](https://ai.google.dev/gemini-api/docs/prompting-strategies).

## How It Works
The agent detects the task from the inputs provided and operates in one of three modes:

1. **Create MVP**: Prompt description provided, no existing prompt → generates a Minimum Viable Prompt.
2. **Review**: Existing prompt provided, no outputs or issues → reviews adherence to best practices, redundancy, and usefulness.
3. **Improve**: Existing prompt + observed outputs or issues provided → suggests minimal fixes for the identified problems.

## Required Inputs
All inputs must be provided upfront. The agent will not ask clarifying questions.

For **Create MVP**, you must include alongside the task description:
- **Prompt type**: system prompt or user-facing prompt
- **Chain of thought (CoT)**: yes or no
- **Instruction style**: high-level, step-by-step, or prompt-chaining

For **Review** and **Improve**, provide the existing prompt and, if applicable, the observed outputs or issues.

## Quick Start
Follow our [agent setup guide](../../../docs/agent-setup-guide.md) to register this agent in Claude Code.

Once set up, invoke it with all required inputs in a single message:
```
Use the prompt-generator agent to create a system prompt for a customer support assistant.
Prompt type: system prompt. CoT: yes. Instruction style: step-by-step.
```
