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

### Mode 1: Create MVP (Minimum Viable Prompt)
Start from scratch to create a new prompt. Here's an example:
### Mode 1: Create MVP (Minimum Viable Prompt)
Start from scratch to create a new prompt. Here's an example conversation:

> **You**: I would like to create a README assistant prompt.
> I want to use an iterative approach.
> 1. the user provides information about the repo and its content.
> 2. the assistant asks any missing information if needed.
> 3. the user answers
> 4. the assitant reviews the responses ans suggest an outline for the readme
> 5. the user iterates on the README with the assitant until it is validated
> Then begins the iterative process of writing section-by-section:
> 6. Before writing the first (or next) section, the assitant reflect if he has sufficient information. If so he writes, if not he asks.
> 7. The user reviews and asks modification until validated
> 8. Do this until the README is done

> **Prompt Generator**: I'll help you create a README assistant prompt with that iterative approach. Let me ask a few clarifying questions:
> 
> 1. **[System Prompt](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/system-prompts) or user-facing prompt?**
>    - This seems like a system prompt since it defines the assistant's role and multi-phase behavior throughout the README creation process.
> 
> 2. **[Chain of thought](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought)** (CoT):
>    - CoT would be valuable here, especially for the reflection steps where the assistant evaluates if they have sufficient information before writing each section. Should I include CoT?
> 
> 3. **[Prompt Chaining](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-prompts) or [High-Level Instructions](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/extended-thinking-tips#use-general-instructions-first%2C-then-troubleshoot-with-more-step-by-step-instructions)?**
>    - Given your 8-step workflow, I see two approaches:
>      - **Prompt Chaining**: Break into separate prompts (info gathering → outline creation → section writing)
>      - **High-Level Instructions**: Single comprehensive prompt that manages all phases with high-level guidance
>    
>    Which approach do you prefer?
> 
> 4. **Do we need examples for the prompt?**
>    - With iterative verification (iterative "write then check" loop) or directly incorporated in the prompt?
>    - How many examples? Only positive or also negative examples? With or without &lt;thinking&gt; tags? (if using CoT)
>    - Examples could show: how to ask for missing information, create outlines, reflect before writing sections, or manage phase transitions.
> 
> Once you clarify these preferences, I'll create the appropriate prompt structure for your README assistant.