![Status](https://img.shields.io/badge/status-experimental-red)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/prompt-engineering-hub.svg?style=flat)]()
# How to Convert a Mermaid Diagram to Canva

This guide shows you how to turn a Mermaid diagram into a Canva design built from your own brand template, with the Mermaid to Canva agent.

The agent lays out the whole diagram with your styled shapes, labels, arrows, and tool logos. You finish it in Canva: you draw the connectors, then export it.

## Connect the Canva MCP

Add the Canva MCP server to Claude Code:
```bash
claude mcp add --transport http canva https://mcp.canva.com/mcp
```

Then, in Claude Code, run `/mcp`, select `canva`, and log in to Canva in your browser. The agent can now read and edit your designs.

## Prepare Your Brand Template

The agent builds every diagram from one brand template, so your diagrams share the same style. Create it once in Canva:

1. Create a design with fixed pages, at any size. Avoid a whiteboard: the agent can't edit one.
2. On page 1, add one shape for each style you want in your diagrams, like a node, a container for a group of nodes, and a highlighted node. Style each one as you want it to appear: fill, border, font, text color.
3. On page 2, add the tool logos you use often, each with its name below it. The agent adds the logos it can't find, so you can start with an empty page.
4. Publish the design as a brand template, and copy its link.

## Run the Agent

From the agent's folder, start Claude Code:
```bash
cd prompts/agents/mermaid_to_canva
claude
```

Then ask it to convert your diagram. It guides you through the conversion:

1. It asks for your Mermaid diagram. Paste it.
2. It asks whether you want a specific aspect ratio, like 4:3 or 16:9. If you don't, it picks the one that fits the diagram.
3. It asks for your brand template. Paste its link.
4. It creates the design at the right size, and sends you its link. Leave the design alone in Canva until it's done: a change made in Canva while the agent edits makes its save fail.
5. It builds the diagram, and lists the connectors left for you to draw.

If the agent resized the design, it tells you to delete the original, at your template's size. The agent can't delete designs.

## Finish the Diagram

1. Open the design in Canva.
2. The agent's arrows show where each connector goes, but they don't follow the shapes. For each connector in its list, drag a line from the source shape onto the target shape, so it follows them when you move them, then delete the agent's arrow.
3. Adjust anything else you want, then export the page as PNG or SVG.
