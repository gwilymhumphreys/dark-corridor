# Tooltips

The combat item tooltip (gen 3, built). Hover a board item → a **cluster** appears
beside it; hover a keyword **chip** inside it → a Godot built-in tooltip pops that
keyword's card. Scope v1: board `Item`s only (player cells + enemy-HUD cells +
ally-slot cells). Potions (Consumables, not Items) and out-of-combat draft
tooltips are a follow-on — the builder is `Item`-typed.

Shipped from [`docs/plans/tooltip_system.md`](../plans/tooltip_system.md), which
holds the design rationale, the ratified decisions, and the prior-art lineage
(`../a-machine` `BuildingTooltip`, `../battledraft` `TooltipManager`).

## What the player sees

- **Main panel** (nearest the item) — name (rarity-tinted), generated effect lines
  with **live values** and inline keyword **chips**, an optional authored flavor
  line, and a stat block (cooldown).
- **Keyword column** (cards beside the main panel) — one card per keyword the item
  references (statuses + mechanics), **all shown at once**.
- **Per-keyword tooltip** — hovering a chip pops a Godot built-in custom tooltip
  with that keyword's full card, positioned + clamped by the engine.

The cluster shows/hides as a unit; it is opaque (a scale reveal, no fade) and
**suppressed while the pause menu is open**.

## The pieces (`src/scenes/ui/tooltip/`)

| File | Role |
|------|------|
| `tooltip_cluster.gd` (+`.tscn`) | The cluster, on its own `CanvasLayer` (layer **50**, below pause's 100). Owns the main panel + keyword column, runs the hide-bridge state machine, positions/clamps, rebuilds on item change, clears its `Item` ref on hide + `_exit_tree`. |
| `tooltip_panel.gd` (+`.tscn`) | The main item panel. Fed a `TooltipContent` Dictionary; rebuilds its line rows (text / value / chip segments). Opaque framed stylebox. |
| `keyword_card.gd` (+`.tscn`) | **Frameless** keyword content (tinted name + description). Returned bare by a chip's `_make_custom_tooltip`; wrapped in a `PanelContainer` for the column. `setup()` reads nodes via `get_node` (called before the card is in the tree). |
| `keyword_chip.gd` (+`.tscn`) | Inline `PanelContainer` (icon + tinted name) in the body. Sets `tooltip_text = <id>` and overrides `_make_custom_tooltip` → a frameless `keyword_card`. |
| `tooltip_content.gd` | The builder (`class_name TooltipContent`). `TooltipContent.new().build(item)` → `{title, rarity, panel_color, lines, flavor, stat_lines, keyword_ids}`. **Instance** (not static) because the line templates call `tr()`. |

Supporting: `src/content/keywords/keyword_catalog.gd` (the keyword id → card map).

## Data flow (who drives what)

A **point-poll**, reusing the run screen's existing slow-mo hover (one hover
paradigm; the hide-bridge needs a per-frame cluster-rect check anyway):

1. `run_screen.gd::_process` drives `view.update_inspection(mouse)` while FIGHTING
   and not paused; `view.stop_inspection()` otherwise (pause / fight end).
2. `combat_view_framed.gd::inspectable_at(point)` hit-tests enemy-HUD cells, ally-slot
   cells, then player cells, returning `{item, rect (global), side}` or `{}`. The rect
   is re-read each frame (enemy HUDs reposition every frame, so the cluster tracks a
   moving cell). Helpers: `EnemyHud`/`AllySlot` `item_at(point)` + `cell_rect(item)`.
3. The view owns the cluster and feeds it the target via `update_target(target, mouse)`.
4. Keyword chips' built-in tooltips are entirely Godot-managed (no poll involvement).

The base `combat_view.gd` declares `inspectable_at` / `update_inspection` /
`stop_inspection` as no-ops; the framed view overrides them.

## The mouse-bridge hide-timer

The cluster sits beside the item with a gap. The poll considers the cluster alive
while the mouse is over **the cell rect OR the cluster rect** (their bounding merge
bridges the gap). Leaving that merged region starts a short hide-timer; re-entering
cancels it. This exists *because the chips are hoverable* — the cursor must be able
to leave the cell and land on the panel. The built-in keyword tips need no bridge
(non-interactive). State in `tooltip_cluster.gd`: `_current_item`, `_anchor_rect`,
`_cluster_rect`, `_hide_timer` (ticked off `get_process_delta_time()` inside
`update_target`, which the view calls every frame).

## Positioning

Default side first (**LEFT** — the player board is the right-edge column), the
screen-half flip as a fallback when the cluster won't fit, then clamp into the
viewport. Measure with `reset_size()` + `get_combined_minimum_size()` — never a
pre-layout `.size`. The main panel sits nearest the item; the keyword column on the
outer side. Coordinate space assumes the run-screen UI has **no custom canvas
transform** (it has no camera) — positions with the cell's global rect and clamps to
`get_viewport_rect()`. If a transform is ever added, convert via
`get_viewport().get_canvas_transform()`.

**Panels are fixed-width** (`TooltipPanel.PANEL_WIDTH`, `KeywordCard.CARD_WIDTH`) — no
content-driven width measurement. Long content wraps to stay within that width: effect-line
rows are `HFlowContainer`s, the title and the flavor `RichTextLabel` autowrap. Measurement
(`reset_size()` + `get_combined_minimum_size()`) reads the resulting **height** + footprint
for positioning/clamping, never to pick a width. The `RichTextLabel` `fit_content` width gotcha
(see `CLAUDE.md`) is handled by fixing `custom_minimum_size.x` on the panel **and** its flavor
label so height is computed at the real width.

## Live values (read-only — never `fire()`)

`Item.fire()` / `_resolve_effect()` mutate (reset the cooldown, spend fuel). The
tooltip computes display values with **separate pure methods** on `Item`:

- `display_value(effect)` — `base_value` then the outgoing stat-status seam
  (`StatusManager.modify_outgoing`, e.g. Weak). Pure.
- `base_value(effect)` — the authored value × enchant mult (a permanent modifier).

The builder highlights a value when `display_value != base_value` (a single accent +
a ▲/▼ direction glyph — the colour treatment is a placeholder, the owner's call; the
B&W theme makes literal green/red clash). **Consume-scaling is excluded from v1** —
reading it correctly needs a non-mutating stack peek (`StatusManager` has no
read-only stack getter); a static consume number would mislead.

## Keywords (catalog-gated)

`TooltipContent.keyword_ids(item)` collects candidate ids and keeps only those present
in `KeywordCatalog` (statuses first in effect order, then mechanics in a fixed order):

- per effect: `APPLY_STATUS` → its `status_id`; `consume_id` → that status + `kw:fuel`;
  `SUMMON` → `kw:summon`; AOE shapes → `kw:aoe`; item-target shapes → `kw:item_target`;
  the `UNBLOCKABLE` flag → `kw:unblockable`.
- `trigger_subs` → `kw:trigger` + each sub's `filter` (a status id).
- `item.enchant` → `kw:enchant`.

`KeywordCatalog` resolves a **status** id from its `StatusEffect` subclass
(name/desc/color/icon — one home per status) and a **mechanic** id (`kw:*`) from
entries authored in the catalog. An id absent from the catalog yields no card,
silently — that absence is how the owner gates a mechanic keyword.

## Built-in custom tooltip — the double-panel contract

A chip sets a non-empty `tooltip_text` (the keyword id, the lookup key) and overrides
`_make_custom_tooltip(for_text)` to return a **frameless** `keyword_card`. Godot wraps
the returned node in the theme's `TooltipPanel`, so `TooltipPanel` / `TooltipLabel` are
styled **opaque** in `black_white_ui.tres` (the theme panel is the only frame; the
returned node is frameless). The column cards are NOT Godot tooltips, so they wrap the
*same* `keyword_card` scene in their own `PanelContainer`. Unknown id →
`_make_custom_tooltip` returns `null` (no tip); the chip still renders its name.

## Owner's domain (content, scaffolded as marked placeholders)

- Each status's `desc_key` (the 7 `*_status.gd` classes).
- Mechanic keyword descriptions (and which mechanics exist) in `keyword_catalog.gd`.
- Optional per-item `description_key` flavor lines (`item_def.gd`).

  The keyword-card **description** and the item **flavor** are `RichTextLabel`s
  with `bbcode_enabled` (the keyword *name* and the effect lines stay plain
  Labels). Authored description/flavor text may therefore use BBCode — notably a
  font-relative inline icon, `[img height=1em]res://path/icon.png[/img]` (Godot
  4.7 `em` unit scales the icon to the text). **Caveat:** with BBCode on, a literal
  `[` in copy is parsed as a tag — escape it as `[lb]`. Interactive inline keyword
  references are still real `keyword_chip` nodes in the effect lines, not BBCode,
  because chips carry the built-in per-keyword tooltip.
- The generated-line baseline copy (templates + shape phrases in `tooltip_content.gd`).
- The changed-value highlight + rarity-tint colour treatment (a theme call).

## Dev host

`src/scenes/dev/tooltip_demo.tscn` (+`.gd`) — a throwaway host (like `combat_sandbox`):
builds one player `Item`, mounts an `ItemCell` + a `TooltipCluster`, and force-shows
the cluster over the cell. Supports `--shot`. The headless verification harness;
excluded from `extract_pot` (`EXCLUDE_FILES`). The live run screen (`--autostart`)
covers the real hover wiring.

```
/c/projects/godot/godot --path . res://src/scenes/dev/tooltip_demo.tscn --shot
```

## Settings

`project.godot` sets `gui/timers/tooltip_delay_sec = 0` (this system is the only
consumer — no hover delay on the keyword tips).
