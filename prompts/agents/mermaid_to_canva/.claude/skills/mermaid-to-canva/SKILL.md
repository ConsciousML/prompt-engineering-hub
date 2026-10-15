---
name: mermaid-to-canva
description: Workflow to convert a Mermaid diagram into a Canva design built from the user's brand template, from asking for the diagram to handing it off. Use when asked to draw, convert, or redo a Mermaid diagram in Canva.
---

# Mermaid to Canva

Load the `canva-diagram` skill before your first Canva call: it holds the MCP recipes and limits.

## Division of Work

- You: the design, page size, layout, reusing and adding shapes, labels, arrows, logos.
- User: drawing the connectors (the MCP can't save lines attached to shapes), exporting.

## 1. Diagram

1. Ask the user for the Mermaid diagram.
2. List its nodes, subgraphs, edges, and edge labels.
3. Ask the user whether they want a specific aspect ratio. If not, pick the one that fits the layout.
4. Choose a page size in that ratio, large enough for every node and label. The image is usually shown at
   half size in docs, so plan node text at 28px or more and edge labels at 22px or more.

## 2. Setup

1. Ask the user for their brand template link or ID. The template must be fixed pages (a whiteboard is
   read-only through the MCP): page 1 holds the styled shapes to reuse, pages 2 and after hold the tool logos.
2. Create the design from the template.
3. If its size differs from your estimate, resize it to the exact size. Resizing makes a copy: work on the
   copy, and tell the user to delete the original, since the MCP can't delete designs.
4. Send the user the design link, and ask them to leave it alone while you edit it: a change in the UI makes
   your save fail.

## 3. Inventory

1. Read the design once: the shapes on page 1 and the logos on pages 2 and after.
2. Map each node type to a styled shape.
3. List the logos the diagram needs that are missing, upload them, and add them to the logos page.

## 4. Build

1. Compute every coordinate first: containers for subgraphs, rows following the flow, arrows that don't cross
   labels, labels beside their arrows.
2. Apply it in one batch, plus a second batch only for operations that need IDs the first one returned.
3. Check the preview thumbnail, fix what overlaps, then save.

## 5. Handoff

Tell the user what's left for them: the connectors to draw (list each edge as source, target, label), and the
export.
