[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/claude-prompt-catalog.svg?style=flat)]()
[![XML Validation](https://github.com/ConsciousML/claude-prompt-catalog/actions/workflows/ci.yaml/badge.svg)](https://github.com/ConsciousML/claude-prompt-catalog/actions/workflows/ci.yaml)
[![PR's Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat)](http://makeapullrequest.com) 
# Claude Prompt Catalog

A curated collection of prompts for [Claude](https://claude.ai/), designed to help users get the most out of their favorite AI assistant.

## Purpose
This catalog serves as both a resource and learning hub, providing working examples of [Anthropic's prompt engineering documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview) in action.

Use these prompts:
- Right off the bat if they fit some of your needs.
- To learn from their structure
- To get inspiration to craft your own prompts
- To contribute back to help the community!

## Requirements
- [**Claude.ai account**](https://claude.ai/): free account works for user-facing prompts.
- [**Claude subscription**](https://claude.ai/settings/billing?action=subscribe): required for Custom Projects (system prompts).

**Note**: the prompts of this catalog has been designed specifically for Claude. But feel free to test them with other LLMs.

## Quick Start
See our [Setup Guide](docs/setup-guide.md) for detailed instructions on using these prompts.

## Prompt Catalog
Here's a table with available prompts:
| Assistant | Description |
|--------|-------------|
| **Prompt Generator** | A comprehensive system for creating effective Claude prompts using advanced techniques like chain-of-thought, prompt chaining, and XML formatting. Follows Anthropic's best practices. |
| **Insight Extractor** | Extracts key findings from articles, research papers, forums, and other content sources. Includes source referencing with text fragment linking for verification. |
| **README Writer** | A structured, iterative approach to creating comprehensive project documentation. Guides you through information gathering, outline creation, and section-by-section writing. |
| **Community Insight Analyst** | Extracts actionable insights from community feedback reports, organizing findings into wants, frustrations, objections, and misunderstandings. Every insight is backed by direct quotes. |
| [**Mermaid Diagram Designer**](prompts/diagram_designer/README.md) | Creates clear, well-structured diagrams using Mermaid syntax. It automatically selects the most appropriate diagram type for your needs and follows best practices for visual clarity. |

For guidance on how to use an assitant, click on the respective link under the `Assistant` tab.

## Repository Structure
```
claude-prompt-catalog/
├── prompts/
│   ├── prompt_generator/
│   │   ├── system.xml
│   │   ├── examples.xml
│   │   └── user_facing_prompts/
│   │       └── evaluate_insights.xml     # User-facing prompt for conversations
│   ├── community_insight/
│   │   └── ...                    # Same as previous folder
│   ├── insight_extractor/
│   │   └── ...
│   └── readme-writer/
│       ├── ...
```

Here's a brief description of each file type:
- `system.xml`: system prompts for Custom Claude Projects. Copy these into Project Instructions.
- `user_facing_prompts/`: ready-to-use prompts for direct conversation. Copy and paste into Claude chats.
- `examples.xml`: example files to upload to Custom Projects alongside system prompts.

## Contributing
We welcome contributions from the community! Help us grow this collection by sharing your prompts.

See the [contributing documentation](docs/contribution.md) for detailed guidelines.

Thank you for helping make Claude more useful for everyone!

## License
This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

Feel free to use, modify, and distribute these prompts in your own projects!