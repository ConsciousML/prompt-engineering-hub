---
name: canva-diagram
description: Canva MCP recipes and limits for drawing a diagram in a fixed-page design from styled template shapes. Load before any Canva MCP call that reads or edits a diagram design.
---

# Canva Diagram

## Creating

- `create-design-from-brand-template` with the template ID (the `brand-templates/<ID>` part of its link)
  makes a design at the template's size, with all its pages.
- `resize-design` with `type: custom` and the exact width and height makes a resized copy. Styled shapes keep
  their style and size, but Canva moves them, and text next to images can shift.

## Reading

- Cheap checks: `read-design` with `fields: ["design_content"]` and no transaction returns the text only.
  `fields: ["design_metadata"]` returns `updated_at`.
- Open an editing transaction with `open_transaction: true` and `fields: ["design_metadata"]`, not the full content.
- Read the full page only once, to get element IDs, paths, and styles. Filter with `element_ids` or
  `page_indices` after that.
- `page_metadata` omits a page added in an open transaction. Get its ID with `design_content` and
  `page_indices: [n]` plus the `transaction_id`.

## Editing

- Whiteboard pages return `isEditable: false`: only fixed pages can be edited.
- One `edit-design` call per batch, with every operation in it. Never print the operations before sending them.
- Save with `finalize: "commit"` right after checking the preview.
- A save that fails with a server error means one of:
  - The design changed in the UI since the transaction opened: `updated_at` is newer. Cancel, reopen, redo.
  - A line was attached to shapes with `update_line_properties`. Those saves always fail: never attach lines.

## Shapes

- There is no copy operation. Reuse the template's styled shapes in place: `position_element`,
  `resize_element`, `replace_text`. They keep the brand font.
- For extra nodes, `insert_shape` with the same path, fill, and stroke. Draw the path in pixels with the view
  box equal to the size. `replace_text` then `format_text` on the new shape puts text inside it, in Canva's
  default font.
- Shapes with a nine-slice may keep their height when resized: read the returned size before placing
  anything below them.

## Arrows

- `insert_shape` with `stroke_color`, `stroke_weight`, and no `color`, so it has no fill.
- Draw the whole arrow as one subpath through the head, for example a downward arrow:
  `M2 496 L12 512 L22 496 L12 512 L12 12`. A subpath that is one straight segment is not drawn.
- `replace_shape` only accepts closed paths: delete the arrow and insert a new one instead.

## Text

- `add_text` uses Canva's default 16px black. Style it with `format_text` in the second batch, since it needs
  the new element IDs.

## Logos

1. Find a public URL, and check it with `curl` first:
   - Simple Icons: `https://cdn.simpleicons.org/<slug>`, in brand color.
   - The project's own GitHub repo, through `raw.githubusercontent.com`.
   - AWS services: `awslabs/aws-icons-for-plantuml`, under `dist/<Category>/<Service>.png` (64px only).
2. Upload with `upload-asset-from-url`, named `<Tool> logo`. Prefer a colored logo: a white SVG on a
   transparent background is invisible on the page.
3. Place it on the logos page with `insert_fill` and the asset ID, keeping its aspect ratio, with its name as
   text below it, in a 6-column grid.
