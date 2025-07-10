# Prompt Setup Guide
This documentation shows you how-to use the custom prompts from this catalog.

## Option 1: Create a Custom Project (Recommended)
Use the Projects feature to create assistants that you can re-use and have all the context readily available.

Here's how to proceed depending on which LLM chat interface you use.

### Claude Projects
1. Go to the [Projects page](https://claude.ai/projects)
2. Click on the `New project` button
3. Write a name for the project (e.g., "Prompt Generator")
4. On the right, below `Project Knowledge` click `Edit`
5. Copy the content of `prompt_generator/system.xml`
6. Paste into project instructions
7. Drag and drop all the files in the `prompt_generator/examples/` folder
8. See this [example](../prompt_generator/examples/readme_writer.xml) for guidance on how to use the Prompt Generator.
9. Start a conversation by writing your first prompt in the text box below `Prompt Generator`.

### ChatGPT Projects
1. Click on `New Project` in the left tab.
2. Write a name for the project (e.g., "Prompt Generator").
3. Click the `Create project` button.
4. Click the `Add files` button.
5. Drag and drop the following files in the Web UI:
- `prompt_generator/system.xml`.
- All the files in the `prompt_generator/examples/` folder.
6. See this [example](../prompt_generator/examples/readme_writer.xml) for guidance on how to use the Prompt Generator.
7. Start a conversation by writing your first prompt in the text box below `Prompt Generator`.

### Gemini Gem
1. Go to the [New Gem page](https://gemini.google.com/gems/create).
2. Write a name for the project (e.g., "Prompt Generator").
3. Copy the content of `prompt_generator/system.xml` under `Instructions`.
4. Drag and drop all the files in the `prompt_generator/examples/` folder under `Knowledge`.
5. Click `Save`.
6. See this [example](../prompt_generator/examples/readme_writer.xml) for guidance on how to use the Prompt Generator.
7. Start a conversation.

## Option 2: Use in Regular Conversations
Use this option for quick one-off tasks or if you don't have a subscription.

For system prompts (without subscription):
1. Copy the contents of any the `prompt_generator/system.xml` file
2. Paste directly at the start of a Claude conversation
3. See this [example](../prompt_generator/examples/readme_writer.xml) for guidance on how to use the Prompt Generator.

For user-facing prompts:
1. Copy the contents of any file in `user_facing_prompts/` folders
2. Paste directly into a Claude conversation
3. Replace placeholders like `[SPECIFIC_TASK]` with your details
