![Prompt Engineering Hub](data/prompt-engineering-hub-logo.png)

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/prompt-engineering-hub.svg?style=flat)]()
[![XML Validation](https://github.com/ConsciousML/prompt-engineering-hub/actions/workflows/ci.yaml/badge.svg)](https://github.com/ConsciousML/prompt-engineering-hub/actions/workflows/ci.yaml)
[![PR's Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com) 
# Prompt Engineering Hub

A prompt hub to help you get the most out of your favorite LLM by generating (or using ready-made) optimized prompts!

## What's Inside

### The Prompt Generator
An assistant that helps you create optimized prompts for any task, following the prompt engineering best practices of [Anthropic](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview), [OpenAI](https://platform.openai.com/docs/guides/) and [Google's Gemini](https://ai.google.dev/gemini-api/docs/prompting-strategies).

### Ready-Made Assistants
A [collection of prompts](#prompt-catalog) for a variety of tasks. All created using our Prompt Generator

## When to Use
Use this repository whether you want to:
- Create your own custom AI assistants (or user prompts)
- Use our pre-built assistants
- Learn from prompt engineering examples
- Contribute your own prompts to help the community!

## Requirements
Any LLM chat interface (Claude, ChatGPT, Gemini, etc.) or APIs

**Note**: While these prompts work across different LLMs, they were optimized using Claude and may need minor adjustments for other platforms.

## Quick Start
See our [setup guide](docs/setup-guide.md) for detailed instructions on using these prompts.

## Advanced Prompt Generation Guide
**Create your own assistants** using our [advanced prompt generation documentation](prompt_generator/README.md#advanced-prompt-generation-guide).

This guide walks you through an iterative workflow to create optimized prompts for your specific tasks.

## Prompt Catalog
Here's a table with available prompts:
| Assistant | Usage | Description | Status |
|--------|-------|-------------|--------|
| [**Prompt Generator**](prompt_generator/README.md) | Prompt Engineering | Generates optimized prompts using advanced techniques like chain-of-thought, prompt chaining, and XML formatting. Follows Anthropic's best practices. | ![Stable](https://img.shields.io/badge/status-stable-green) |
| [**Example Generator**](prompts/example_generator/README.md) | Prompt Engineering | Creates XML examples that demonstrate assistant behavior to improve performance. | ![Stable](https://img.shields.io/badge/status-stable-green) |
| [**README Writer**](prompts/readme_writer/README.md) | Documentation | Assists you section by section to write README.md files. Guides you through information gathering, outline creation, and section-by-section writing. | ![Beta](https://img.shields.io/badge/status-beta-yellow) |
| [**Mermaid Diagram Designer**](prompts/diagram_designer/README.md) | Diagrams | Builds clear, well-structured diagrams using Mermaid syntax. It automatically selects the most appropriate diagram type for your needs and follows best practices for visual clarity. | ![Beta](https://img.shields.io/badge/status-beta-yellow) |
| **Insight Extractor** | Research | Extracts key findings from articles, research papers, forums, and other content sources. Includes source referencing with text fragment linking for verification. | ![Experimental](https://img.shields.io/badge/status-experimental-red) |
| **Community Insight Analyst** | Research | Extracts insights from community feedback reports, organizing findings into wants, frustrations, objections, and misunderstandings. Every insight is backed by direct quotes. | ![Experimental](https://img.shields.io/badge/status-experimental-red) |

For guidance on how to use an assistant, click on the respective link under the `Assistant` tab.

## Repository Structure
```bash
prompt-generator-hub/
├── prompt_generator/                     # The main prompt generation tool
│   ├── system.xml
│   ├── examples/
│   │   └── example_1.xml
│   │   └── ...
│   └── user_facing_prompts/
│       └── evaluate_insights.xml
├── prompts/                              # Ready-made assistants created with our generator
│   ├── example_generator/
│   │   ├── system.xml
│   │   ├── examples/
│   │   └── user_facing_prompts/
│   ├── readme_writer/
│   │   └── ...
│   ├── diagram_designer/
│   │   └── ...
│   └── insight_extractor/
│       └── ...
└── docs/
    ├── setup-guide.md
    └── contribution.md
```

Here's a brief description of each file type:
- `system.xml`: system prompts for Custom Projects or API. Copy these into Project Instructions or use with your LLM's system prompt feature.
- `user_facing_prompts/`: ready-to-use prompts for direct conversation. Copy and paste into any LLM chat.
- `example_*.xml`: example files demonstrating the assistant's behavior.

Should I continue with the Contributing section?

## Contributing
We welcome contributions from the community! Help us grow this collection by sharing your prompts.

See the [contributing documentation](docs/contribution.md) for detailed guidelines.

Thank you for helping make AI assistants more useful for everyone!

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

Feel free to use, modify, and distribute these prompts in your own projects!
