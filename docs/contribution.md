# Contribution Guidelines
Please familiarize yourself with [Anthropic's Prompt Engineering Documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview) to ensure your prompts follow best practices.

## Submission Guidelines

1. Create a new folder under `prompts/` with a descriptive name (e.g., `data_analyzer`, `meeting_summarizer`)
2. Include a `system.xml` file with your system prompt
3. Add `user_facing_prompts/` folder if your prompt includes prompt templates.
4. Follow XML formatting as shown in existing prompts
5. Test your prompt thoroughly before submitting

## File Structure Requirements
```
prompts/your_prompt_name/
├── system.xml
└── user_facing_prompts/          # Optional: Conversational examples
├── examples/
|   └── example_1.xml
|   └── ...
```

## How to Submit
1. Fork this repository
2. Create a new branch for your prompt
3. Add your prompt following the guidelines above
4. Update this README's Prompt Catalog table
5. Submit a pull request with a clear description

Thank you for helping make AI assistants more useful for everyone!