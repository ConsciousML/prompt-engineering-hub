# Agent Setup Guide
This guide shows you how to set up and use agents from this catalog in Claude Code.

## Option 1: Claude Code Sub-Agent (Recommended)
Register the agent as a sub-agent so Claude Code can discover and invoke it autonomously.

1. Open Claude Code and run `/agents`.
2. Switch to the **Library** tab and select **Create new agent**.
3. Choose **Project** to scope the agent to the current project, or **Personal** to make it available in all your projects.
4. Fill in the name and description, then paste the content of the agent's `system.xml` as the system prompt.
5. Select the tools the agent can use.
6. Select the model, pick a color, and save.

The agent is available immediately.

**Tip**: Write a precise description. Claude Code uses it to decide when to invoke the agent.

## Option 2: Anthropic API
Use this option to invoke agents programmatically outside Claude Code.

1. Copy the content of the agent's `system.xml` file.
2. Pass it as the `system` parameter in your API call.
3. Provide all required inputs in the `user` message — agents require all inputs upfront and will not ask clarifying questions.

See the [Anthropic API documentation](https://docs.anthropic.com/en/api/getting-started) for details on how to structure your request.

## Further Reading
For a full overview of Claude Code sub-agents, see the [official sub-agents documentation](https://code.claude.com/docs/en/sub-agents).
