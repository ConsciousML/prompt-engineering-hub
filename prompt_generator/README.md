![Status](https://img.shields.io/badge/status-stable-green)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/claude-prompt-catalog.svg?style=flat)]()
# Prompt Generator
The Prompt Generator is the core assistant in this catalog. It was used to creates all other assistants.

The Prompt Generator was designed to guide you through the process of creating optimized prompts for your workflow.

## Why Use the Prompt Generator?

The Prompt Generator knows the best practices from Anthropic's prompt engineering documentation. It creates prompts like an expert prompt engineer.

Key benefits:
- Get professional quality prompts without being an expert
- Save time, no need to learn complex prompting techniques
- Create prompts that get better results from Claude

## When to Use the Prompt Generator?

The Prompt Generator is most valuable in these situations:

- **For tasks you do regularly with LLMs**: Create a specialized assistant once, then reuse it instead of explaining the task every time
- **When Claude's default responses aren't good enough**: The Prompt Generator adds techniques that improve Claude's performance on difficult tasks
- **When you need specific behavior from Claude**: Control the reasoning process, output format, or step-by-step approach Claude should follow
- **When your task requires lots of context or specifications**: Instead of providing lengthy instructions each time, create an assistant that remembers all requirements

## Prerequisites

To get the most out of the Prompt Generator, we recommend reading [Anthropic's prompt engineering documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview).

This will help you understand the techniques the Prompt Generator uses and have better conversations with it.

However, if you're eager to start, you can use the Prompt Generator right away. It will guide you through the process and explain concepts as needed.

## Key Features
### Assistant Capabilities
The Prompt Generator supports three modes:
1. **Create from scratch**: Guides you through creating a new prompt with targeted questions about your needs
2. **Review existing prompts**: Analyzes your prompts to:
- Follow best practices
- Avoid redundancies
- Ensure every instruction is useful
3. **Improve based on results**: Refines prompts based on real-world outputs and/or user feedback

### Prompt Techniques
The Prompt Generator uses proven techniques to create effective prompts:
- **System Prompts**: Creates role-based prompts that define Claude's expertise and context, greatly improving performance for specialized tasks
- **Chain-of-Thought (CoT)**: Adds thinking space for Claude to break down problems step-by-step, leading to more accurate outputs
- **Prompt Chaining**: Breaks complex tasks into smaller, manageable subtasks that build on each other
- **XML Formatting**: Structures prompts with clear sections and tags for better organization and Claude comprehension
- **Minimum Viable Prompt (MVP)**: Starts with essential elements only, avoiding unnecessary complexity

## Quick Start
Follow our [setup guide](../../docs/setup-guide.md) to get started with the Prompt Generator.

## Advanced Prompt Generation Guide
This section will explain how to get the most of the Prompt Generator.

Prompt engineering is an iterative process. Here's an overview of the proposed workflow:
1. [Create an MVP](#step-1-create-minimum-viable-prompt-mvp): Start with the essential elements.
2. [Review for issues](#step-2-review-the-prompt): Check adherence to best practices.
3. [Refine the prompt](#step-3-improve-the-prompt): Address identified issues.
4. [Test in real scenarios](#step-4-test-the-prompt): Use your assistant on actual tasks.
5. [Improve based on results](#step-5-improve-the-prompt-based-on-outputs): Fix any performance gaps.
6. [Add examples](#step-6-generate-examples): Boost performance with few-shot learning.

### Configuration Recommendation
Generating optimal prompts is a complex task.
To get the most out of this assistant, we recommend using:
- Claude Opus 4
- With [extended thinking](https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking).

Here's a screenshot illustrating how to enable extended thinking:
![](../../data/extended_thinking.png)

### Step 1: Create Minimum Viable Prompt (MVP)
Start from scratch to create a new prompt:
1. Write all the details about the prompt you want to create.
2. The assistant will ask clarification questions.
3. Answer the questions.
4. The assistant will generate an MVP (a first version of your prompt).
5. Review the MVP carefully. Remove any unnecessary instructions.

By this stage, you should end up with a relatively simple prompt.

Here's an [example conversation](examples/readme_writer.xml) illustrating how to generate an MVP.

### Step 2: Review the Prompt
The MVP is rarely perfect out of the box.

Luckily, this assistant comes with a functionality that allows you to spot the issues of the initial prompt:
1. Ask the assistant to review the prompt. Use a simple phrase like: "Review the MVP."
2. The assistant will check that:
- It follows all the guidance and constraints of the Anthropic's documentation.
- It is free of redundancy.
- Every instruction is useful for the engoal.
3. The assistant will expose the issues of the MVP.

### Step 3: Improve the Prompt
1. Approve, decline or change suggestions from the previous step.
2. Feed the revised suggestions to the assistant and ask to improve the prompt.
3. Repeat [step 2](#step-2-review-the-prompt) and [step 3](#step-3-improve-the-prompt) until you are satisfied with your MVP.

**Caution**: By the end of this step. You should end up with a relatively simple prompt. If the prompt is too verbose, there's a high change that it will perform poorly.

### Step 4: Test the Prompt
1. Perform the [setup guide](../../docs/setup-guide.md) again with your newly created prompt to add the generated assistant to your workspace.
2. Start a conversation and perform a real-world task with the assistant.
3. Note any lack of performance or undesired behavior.

### Step 5: Improve the Prompt Based on Outputs
1. Start a conversation with the Prompt Generator again.
2. Feed him:
- The system prompt of your generated assistant.
- The query (user prompt) that illustrates the issues noticed in [step 4](#step-4-test-the-prompt).
- Explain the issue and ask the Prompt Generator to suggest improvements.
4. The Prompt Generator will suggest improvements.
5. Accept, decline or change any suggested improvements.
6. Ask the Prompt Generator to improve the prompt based on the revised suggestions.

If you want to maximize the performance of your assistant, repeat this step each time you notice a major issue.

### Step 6: Generate Examples
LLMs perform significantly better with examples (few-shot).

If you successfully performed a task (you achieved the desired outcome) with your generated assistant, you can use your queries (user prompts) and the assistant's responses to create an example.

When creating/generating examples, make sure that:
- The example illustrates how the assistant should function.
- Use XML formatting with `<user>` and `<assistant>` tags. See this [example](examples/readme_writer.xml).
- If your assistant uses Chain of Thought (CoT), make sure to incorporate `<thinking>` tags in your example.
- The example does not contradict any instruction from its system prompt.

**Note**: If the assistant functions step-by-step, do not feed the final desired outcome. For example, if you create an assistant to write READMEs section by section, emulate this in the example.

To make this process easier, you can use the [Example Generator](../example_generator/README.md).