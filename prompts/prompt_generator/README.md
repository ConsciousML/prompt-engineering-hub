# Prompt Generator
The Prompt Generator is the core assistant in this catalog. It was used to creates all other assistants.

The Prompt Generator was designed to guide you through the process of creating optimized prompts for your workflow.

## Why Use the Prompt Generator?

The Prompt Generator knows the best practices from Anthropic's prompt engineering documentation. It creates prompts like an expert prompt engineer.

Key benefits:
- Get professional-quality prompts without being an expert
- Save time - no need to learn complex prompting techniques
- Create prompts that get better results from Claude

## Prerequisites

To get the most out of the Prompt Generator, we recommend reading [Anthropic's prompt engineering documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview).

This will help you understand the techniques the Prompt Generator uses and have better conversations with it.

However, if you're eager to start, you can use the Prompt Generator right away. It will guide you through the process and explain concepts as needed.

## Prompt Techniques
The Prompt Generator uses proven techniques to create effective prompts:
- **System Prompts**: Creates role-based prompts that define Claude's expertise and context, greatly improving performance for specialized tasks
- **Chain-of-Thought (CoT)**: Adds thinking space for Claude to break down problems step-by-step, leading to more accurate outputs
- **Prompt Chaining**: Breaks complex tasks into smaller, manageable subtasks that build on each other
- **XML Formatting**: Structures prompts with clear sections and tags for better organization and Claude comprehension
- **Minimum Viable Prompt (MVP)**: Starts with essential elements only, avoiding unnecessary complexity

These techniques work together to create prompts that are both powerful and efficient.

## Getting Started

First, follow our [setup guide](../../docs/setup-guide.md) to add the Prompt Generator to your Claude workspace.

The Prompt Generator operates in three modes. Here's how to use each one:

### Mode 1: Create Minimum Viable Prompt (MVP)
Start from scratch to create a new prompt:
1. Write all the details about the prompt you want to create.
2. The assistant will ask clarification questions.
3. Answer the questions.
4. The assistant will generate an MVP (a first version of your prompt).
5. Ask for refinements until your validate the MVP.

Here's an [example conversation](example_readme_writer.xml) illustrating how to generate an MVP.