# Claude Prompt Setup Guide
This documentation shows you how-to use the custom prompts from this catalog.

## Option 1: Create a Custom Claude Project (Recommended)
Use Claude Projects to create assistant that you can re-use and have all the context readily available:
1. Go to the [Projects page](https://claude.ai/projects)
2. Click on the `New project` button
3. Write a name for the project (e.g., "Prompt Generator")
4. On the right, below `Project Knowledge` click `Edit`
5. Copy the content of `prompts/prompt_generator/system.xml`
6. Paste into project instructions
7. Drag and drop the `prompts/prompt_generator/example.xml` file
8. See this [example](prompts/prompt_generator/examples.xml) for guidance on how to use the Prompt Generator.
9. Start a conversation on by writing your first prompt in the text box below `Prompt Generator`.


## Option 2: Use in Regular Conversations
Use this option for quick one-off tasks or if you don't have a Claude subscription.

For system prompts (without subscription):
1. Copy the contents of any `system.xml` file
2. Paste directly at the start of a Claude conversation
3. See this [example](prompts/prompt_generator/examples.xml) for guidance on how to use the Prompt Generator.

For user-facing prompts:
1. Copy the contents of any file in `user_facing_prompts/` folders
2. Paste directly into a Claude conversation
3. Replace placeholders like `[SPECIFIC_TASK]` with your details
