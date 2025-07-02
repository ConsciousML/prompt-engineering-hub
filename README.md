[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
# Claude Prompt Catalog

A curated collection of prompts for [Claude](https://claude.ai/), designed to help users get the most out of their favorite AI assistant.

## Purpose
This catalog serves as both a resource and learning hub, providing working examples of [Anthropic's prompt engineering documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview) in action.

Use these prompts:
- right off the bat if they fit some of your needs.
- to learn from their structure
- to get inspiration to craft your own prompts
- to contribute back to help the community!

## Requirements
- [**Claude.ai account**](https://claude.ai/): free account works for user-facing prompts.
- [**Claude subscription**](https://claude.ai/settings/billing?action=subscribe): required for Custom Projects (system prompts).

**Note**: the prompts of this catalog has been designed specifically for Claude. But feel free to test them with other LLMs.

## Quick Start

### Option 1: Create a Custom Claude Project (Recommended)

For specialized workflows, create a dedicated Claude assistant using the Prompt Generator as an example:

1. Go to the [Projects page](https://claude.ai/projects)
2. Click on the `New project` button
3. Write a name for the project (e.g., "Prompt Generator")
4. On the right, below `Project Knowledge` click `Edit`
5. Copy the content of `prompts/prompt_generator/system.xml`
6. Paste into project instructions
7. Drag and drop the `prompts/prompt_generator/example.xml` file
8. See this [example](prompts/prompt_generator/examples.xml) for guidance on how to use the Prompt Generator.
9. Start a conversation on by writing your first prompt in the text box below `Prompt Generator`.


### Option 2: Use in Regular Conversations

Use this option for quick one-off tasks or if you don't have a Claude subscription.

For system prompts (without subscription):
1. Copy the contents of any `system.xml` file
2. Paste directly at the start of a Claude conversation
3. See this [example](prompts/prompt_generator/examples.xml) for guidance on how to use the Prompt Generator.

For user-facing prompts:
1. Copy the contents of any file in `user_facing_prompts/` folders
2. Paste directly into a Claude conversation
3. Replace placeholders like `[SPECIFIC_TASK]` with your details


## Prompt Catalog
Here's a table with available prompts:
| Prompt | Description |
|--------|-------------|
| **Prompt Generator** | A comprehensive system for creating effective Claude prompts using advanced techniques like chain-of-thought, prompt chaining, and XML formatting. Follows Anthropic's best practices. |
| **Insight Extractor** | Extracts key findings from articles, research papers, forums, and other content sources. Includes source referencing with text fragment linking for verification. |
| **README Writer** | A structured, iterative approach to creating comprehensive project documentation. Guides you through information gathering, outline creation, and section-by-section writing. |
| **Community Insight Analyst** | Extracts actionable insights from community feedback reports, organizing findings into wants, frustrations, objections, and misunderstandings. Every insight is backed by direct quotes. |

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