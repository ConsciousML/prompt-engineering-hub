![Status](https://img.shields.io/badge/status-stable-green)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/prompt-engineering-hub.svg?style=flat)]()
# Example Generator
The Example Generator creates XML examples that demonstrate how your assistants should behave.

## Purpose
Examples (few-short) are one of the most powerful tools for improving the performance of LLMs.

Unfortunately, it can be long and tedious to create them. The Example Generator helps you facilitate this process.

Here's in which context the assistant can be used:
1. Notice an undesired behavior of an assistant.
2. Use the Example Generator to create an example that illustrates the desired behavior.
3. Feed the generated example to the initial assistant and test it again.

This iterative process is part of the broader prompt improvement workflow described in [Prompt Generator step 6](../../prompt_generator/README.md#step-6-generate-examples).

**Pro tip**: The most effective examples come from reformatting real conversations where your assistant performed exactly as intended.

## Quick Start
Follow our [setup guide](../../docs/setup-guide.md) to get started with the Example Generator.

## How To Use
### Mode 1: Create Examples from Scratch
1. Start a conversation by:
- Giving the system prompt of the assistant you want to create examples for
- Rename the main `<system>` tag to `<system_[NAME_OF_YOUR_ASSISTANT]>` to avoid confusion
- Ask: "Let's create an example for the [NAME_OF_YOUR_ASSISTANT]"
2. The Examples Generator asks what aspect of the system prompt you want to demonstrate
3. Specify the behavior or workflow you want to show
4. The assistant generates one user/assistant interaction
5. Review and validate the example
6. Continue with until the complete conversation

### Mode 2: Improve Existing Examples
1. Start a new conversation and provide:
- The system prompt of the assistant you want to create examples for
- Rename the main `<system>` tag to `<system_[NAME_OF_YOUR_ASSISTANT]>` to avoid confusion
- The existing example
2. Explain what improvements you need (clarity, better demonstration of features, fixing inconsistencies, etc.)
3. The assistant generates an improved version
4. Review and validate the improvements

### Mode 3: Refactor Existing Conversation
1. Start a conversation by providing:
   - The system prompt of the assistant
   - A real conversation where your assistant performed well
2. Ask: "Refactor this conversation into an example"
3. The Examples Generator will:
   - Clean up the conversation flow
   - Add proper XML formatting
   - Include `<thinking>` tags if applicable
   - Remove any unnecessary parts
4. Review the reformatted example
5. Request adjustments if needed

## Tips on Examples

- **Demonstrate complete workflows**: Show the entire process from user request to final output
- **Use realistic scenarios**: Base examples on actual use cases rather than generated from scratch
- **Include thinking tags**: If your assistant uses Chain of Thought (CoT), always include `<thinking>` tags in examples
- **Show edge cases**: Create examples for tricky situations or common user mistakes
- **Be consistent**: Ensure examples don't contradict any instructions in the system prompt
- **Keep it focused**: Each example should demonstrate one clear aspect of the assistant's behavior