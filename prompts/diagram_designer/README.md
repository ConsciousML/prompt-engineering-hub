# Diagram Designer

## Overview

The Diagram Designer is an AI assistant that creates clear, well-structured diagrams using Mermaid syntax.

With this assistant, you can describe what you want to visualize in plain language, and it will generate a Mermaid diagram that renders in Claude's interface.

## When to Use

Use the Diagram Designer when you want to:
- Visualize your ideas to spot patterns, gaps, and opportunities for improvement
- Add diagrams to documentation, presentations, or explanations to make it easier to understand.

## Features
- **Automatic diagram type selection**: Describe what you want to visualize, and the assistant will choose the most appropriate diagram type (flowchart, sequence diagram, mind map, etc.)
- **Natural language input**: No need to know Mermaid syntax. Just explain what you want in plain language
- **Best practices**: Generates clean, well-structured diagrams following Mermaid style conventions
- **Interactive refinement**: Easily iterate on your diagrams with follow-up requests
- **Ready-to-render output**: Creates Mermaid code that renders directly in Claude's interface

## How to Use

Follow our [setup guide](../../docs/setup-guide.md) to add the Diagram Designer to your Claude workspace.

Once set up, simply describe what you want to visualize.

Here's a [detailed example](examples/flowchart_custom_prompt.xml) on how to best use this assistant.

## Tips

- **Be specific about actors and relationships**: Mention all entities involved (users, systems, databases) to get more accurate diagrams
- **Iterate**: Start with a basic description, then ask for refinements like "add error handling paths" or "group related steps"
- **Request specific diagram types if needed**: While the assistant auto-selects diagram types, you can specify "as a sequence diagram" or "using swimlanes" for precise control