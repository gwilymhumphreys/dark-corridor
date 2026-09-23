# Tooltips

The combat item tooltip (gen 3, built). Hover a board item → a **cluster** appears
beside it: a main panel plus one card per keyword the item references. Scope: board
`Item`s (player cells + enemy-HUD cells + ally-slot cells) and the reward icons on the
draft overlay. Potions (Consumables, not Items)
are a follow-on — the builder is `Item`-typed.

Shipped from [`docs/plans/tooltip_system.md`](../plans/tooltip_system.md), which
holds the design rationale, the ratified decisions, and the prior-art lineage
(`../a-machine` `BuildingTooltip`, `../battledraft` `TooltipManager`).

## What the player sees

- **Main panel** (nearest the item) — four parts, in this order: the name (rarity-tinted), a type
  line (the item's type tags, hidden when it has none), the `charge_time` glyph followed by the
  charge time, and the generated effect lines. An optional authored flavor line sits under them.
- **Keyword column** (cards beside the main panel) — one card per keyword the item
  references (statuses + mechanics), **all shown at once**. A card is the keyword's icon and its
  tinted name on one row, with its description under them.

The cluster shows/hides as a unit; it is opaque (a scale reveal, no fade) and
**suppressed while the pause menu is open**. Nothing in it is interactive — the whole
cluster ignores the mouse, so it never swallows a click on what is underneath, and it
hides the moment the cursor leaves the item's cell. It holds no keyword **chips**: a keyword
inside an effect line is drawn as a bare icon, and the column beside it already shows every
card at once. A chip used elsewhere in the interface can still carry a pop-up card, see below.

### The effect lines

A **basic apply** — an effect that applies to a single actor in the direction its mechanic already
implies (yourself, or the enemy in front of you), spends no fuel and is not unblockable — reads as
its **icon followed by its value**, with no words at all (`TooltipContent._is_basic_apply`). An item's crit
chance reads as one more line in the same shape: the crit glyph followed by the percentage.

Anything more complicated — an item target, all enemies, a summon, a trigger, a charge or decharge
— keeps a **worded line** for now, with an icon where a keyword chip used to be. Those strings are
the owner's to design as the effects that need them are authored.

A trigger line names its event and then the charge icon with the seconds the trigger fills each time
it goes off: "When [poison] is applied, [charge] 1s". A trigger on destroyed items reads as the
Reclaim keyword instead.

An effect whose value is read from a status its owner holds (`ItemEffect.per_owner_stack_id`) names
that status instead of a number: "[attack] equal to your [shield]".

## The pieces (`src/scenes/ui/tooltip/`)

| File | Role |
|------|------|
| `tooltip_cluster.gd` (+`.tscn`) | The cluster, on its own `CanvasLayer` (layer **50**, below pause's 100). Owns the main panel + keyword column, positions/clamps, rebuilds on item change, hides when the target is empty, clears its `Item` ref on hide + `_exit_tree`. |
| `tooltip_panel.gd` (+`.tscn`) | The main item panel. Fed a `TooltipContent` Dictionary; rebuilds its charge row and its line rows (text / value / icon segments). Opaque `PanelFramed` stylebox — now a flat, palette-following fill with no border ([ui_theme.md](ui_theme.md#flat-palette-following-panels)), so it reads as a plain block over the corridor rather than a bordered frame. |
| `keyword_card.gd` (+`.tscn`) | **Frameless** keyword content: the icon and the tinted name on one row, the description under them. Wrapped in a `PanelContainer` for the column; returned bare by a hoverable chip's `_make_custom_tooltip`. `setup()` reads nodes via `get_node` (called before the card is in the tree). |
| `keyword_chip.gd` (+`.tscn`) | `PanelContainer` tag (icon + tinted name), used **outside** the item tooltip. `setup(id, hoverable = false)`: inert to the mouse by default, or, with `hoverable = true`, `MOUSE_FILTER_STOP` + `tooltip_text = <id>` so the built-in per-keyword tooltip pops. |
| `keyword_icon.gd` | `class_name KeywordIcon`, static only: the one rule for drawing a keyword's icon. `dress(rect, path, colour)` sets the modulate and material by kind (see below); `make(id, size)` returns a ready square `TextureRect`. Shared by the chip, the card and the panel's inline icons. |
| `tooltip_content.gd` | The builder (`class_name TooltipContent`). `TooltipContent.new().build(item)` → `{title, rarity, panel_color, type_line, charge_line, lines, flavor, keyword_ids}`. **Instance** (not static) because the line templates and the type line call `tr()`. |

Supporting: `src/content/keywords/keyword_catalog.gd` (the keyword id → card map).

## Data flow (who drives what)

A **point-poll**, reusing the run screen's existing slow-mo hover (one hover paradigm,
and the cluster has to re-read a moving cell's rect every frame anyway):

1. `run_screen.gd::_process` drives `view.update_inspection(target)` every frame a
   combat view exists — during the approach, the fight, the post-fight summary and the reward
   draft — and calls `view.stop_inspection()` only while the pause menu is open. The run screen
   picks the target: a reward icon from `DraftOverlay.inspectable_at` first; nothing when the
   mouse is over the draft or summary panel; otherwise the view's `inspectable_at`. The view exists
   during events too (built without a fight), so board tooltips work there as well. Slow-mo is still requested only while fighting.
2. `combat_view_framed.gd::inspectable_at(point)` hit-tests enemy-HUD cells, ally-slot
   cells, then player cells, returning `{item, rect (global), side}` or `{}`. The rect
   is re-read each frame (enemy HUDs reposition every frame, so the cluster tracks a
   moving cell). Helpers: `EnemyHud`/`AllySlot` `item_at(point)` + `cell_rect(item)`.
3. The view owns the cluster and feeds it the target via `update_target(target)`, and sets
   `hovered` on the target's `ItemCell` so it takes the hover highlight
   ([control_feedback.md](control_feedback.md)). Board items take no mouse events of their own, so
   this poll is the only thing that knows which cell the pointer is over.
4. The run screen passes only the target; there is no cursor position to track once the cluster
   is placed, because the cluster has no hover behaviour of its own.

The base `combat_view.gd` declares `inspectable_at` / `update_inspection` /
`stop_inspection` as no-ops; the framed view overrides them.

## Showing and hiding

The cluster follows the poll's target directly: a new item rebuilds and reveals it, the same item
repositions it, an empty target hides it at once. There is no hover grace period and no travel
path onto the panel, because the player never needs to reach the cluster with the cursor. State in
`tooltip_cluster.gd`: `_current_item`, `_anchor_rect`, `_pending_show`.

An earlier version held the cluster open while the mouse was over the merge of the cell rect and
the cluster rect, so the cursor could travel onto the panel to hover a chip. It was removed with
the chips' pop-up tooltips: it misbehaved when moving between items, and the keyword column made it
unnecessary.

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

- `display_value(effect)` — the value read from a status the owner holds (`per_owner_stack_id`),
  the enchant, plus, for an attack, the status bonuses on the owner and
  on the item (`StatusManager.outgoing_bonuses`, e.g. Weak, the attack bonuses), rounded to the
  whole number that will land (decision #49). Pure.
- `base_value(effect)` — the authored value × enchant mult (a permanent modifier), rounded the same way.

The builder marks a value as `changed` when `display_value != base_value`, and the panel tints it
with a single accent colour (a placeholder, the owner's call). It used to carry a ▲/▼ glyph as
well, for direction; that was dropped once the mechanic's icon sat beside the number. **Consume-scaling is excluded from v1**,
because a static consume number would mislead.

## Keywords (catalog-gated)

`TooltipContent.keyword_ids(item)` builds the column in three parts and keeps only the ids present
in `KeywordCatalog` (an absent id yields no card — that absence is how the owner gates a mechanic
keyword):

- **The authored `mechanics` list** (`ItemDef.mechanics`, alphabetical) — the mechanic ids the item
  counts as, including crit (an item with a crit chance lists `crit` like any other mechanic; the
  floor check in `test_pool_integrity.gd` enforces it).
- **The derived non-mechanic ids**, in effect order: an `APPLY_STATUS` effect's `status_id`
  (weak, vulnerable, …); each effect's `consume_id`, then its `per_owner_stack_id`; and each `trigger_subs` entry's `filter`
  (a status id).
- **The structural keywords**, in `KeywordCatalog.MECHANIC_ORDER` (only those the item references):
  `consume_id` set → `kw:fuel`; `SUMMON` → `kw:summon`; AOE shapes → `kw:aoe`; item-target shapes
  → `kw:item_target`; the `UNBLOCKABLE` flag → `kw:unblockable`; `trigger_subs` → `kw:trigger`
  (an **`ITEM_DESTROYED`** sub instead surfaces **`kw:reclaim`**, the destroy-payoff keyword —
  the Fleshmancer's; `character_ideas.md`, and its trigger line renders the Reclaim chip);
  `item.enchant` → `kw:enchant`.

`KeywordCatalog` resolves a **mechanic** id from its `Mechanic` class (name/desc/color/icon —
one home per mechanic, [mechanics.md](mechanics.md)), a **status** id from its `StatusEffect`
subclass, and a **mechanic keyword** id (`kw:*`) from entries authored in the catalog. An id
absent from the catalog yields no card, silently.

### Dressing an icon

The three kinds of entry bring two kinds of icon, and `KeywordIcon.dress` treats them
oppositely. A mechanic's icon is an [icon slot](mechanics.md#iconslots) glyph: a white shape
under `res://assets/icons/mechanics/`, so it is tinted with the keyword's colour and drawn
through `InterfaceLook.element_material`, which keeps the effects that would move a pixel off
its palette colour switched off ([interface_look.md](interface_look.md)). A status or `kw:*`
icon is painted pack art with its own colours, so it keeps white modulate and
`InterfaceLook.material`, the picture material.

Every icon in the tooltip goes through this one function — the chip's, the card's and the panel's
inline ones.

### The inline icon segment

A line segment of `{'t': 'icon', 'id': <id>}` is rendered by `TooltipPanel` through
`KeywordIcon.make`. The id is a **keyword** id (a mechanic, a status or a `kw:` id) when
`KeywordCatalog` has an entry for it, and otherwise an **icon slot** id such as `charge_time`,
which has no keyword card and so is drawn in `Colours.UI_TEXT_DIM`. An id that resolves to neither
yields an empty rect rather than an error.

An icon is drawn at exactly the body font's height (`TooltipPanel.ICON_SCALE`, one), so it is as
tall as the line it sits in. The body size is chosen to match the icons
([ui_theme.md](ui_theme.md#the-text-ladder-and-the-text-size-setting)), and both follow the player's
text size setting, since the size is read from the theme each time a line is built.

## Hoverable chips outside the item tooltip — the double-panel contract

A chip built with `setup(id, true)` sets a non-empty `tooltip_text` (the keyword id, the lookup
key); its `_make_custom_tooltip(for_text)` override returns a **frameless** `keyword_card`. Godot
wraps the returned node in the theme's `TooltipPanel`, so `TooltipPanel` / `TooltipLabel` are
styled **opaque** in `dark_corridor.tres` (the theme panel is the only frame; the returned node is
frameless). The column cards are NOT Godot tooltips, so they wrap the *same* `keyword_card` scene
in their own `PanelContainer`. Unknown id → `_make_custom_tooltip` returns `null` (no tip); the
chip still renders its name.

The item tooltip holds no chips, so this path is unused there. The debug Icons tab
(`src/debug/icon_panel.gd`) is the current user.

## Owner's domain (content, scaffolded as marked placeholders)

- Each status's `desc_key` (the 7 `*_status.gd` classes).
- Mechanic keyword descriptions (and which mechanics exist) in `keyword_catalog.gd`.
- Optional per-item `description_key` flavor lines (`item_def.gd`).

  The keyword-card **description** and the item **flavor** are `RichTextLabel`s
  with `bbcode_enabled` (the keyword *name* and the effect lines stay plain
  Labels). Authored description/flavor text may therefore use BBCode — notably a
  font-relative inline icon, `[img height=1em]res://path/icon.png[/img]` (Godot
  4.7 `em` unit scales the icon to the text). **Caveat:** with BBCode on, a literal
  `[` in copy is parsed as a tag — escape it as `[lb]`. An inline keyword reference in an effect
  line is a real `KeywordIcon` node, not BBCode.
- The generated-line baseline copy (templates + shape phrases in `tooltip_content.gd`), and the
  strings for the effects that are not a basic apply, as those effects are authored.
- The changed-value highlight + rarity-tint colour treatment (a theme call).

### Filtered target phrases

An effect's target phrase names what its `target_filter` narrows to (`tooltip_content.gd::_shape_text`).
The **actor** shapes (self / all opponents / the enemy) ignore the filter — a filter narrows an item
pool, not an actor — and read their unfiltered baseline phrase. The four **item** shapes read the
unfiltered phrase ("all your items") when the filter is null or empty, and a filtered phrase with the
filter's term in the gap ("each of your weapon items") when it is not. A filter of exactly one
`MECHANIC` condition fills the gap with that mechanic's icon ("each of your [attack] items"), so
`_shape_text` returns segments. Otherwise the gap is words: a `TYPE` condition contributes its
lowercased singular type display name, a `MECHANIC` condition the lowercased mechanic name (an id that
does not resolve is skipped, so a bad id never crashes a tooltip), and several terms join with a
mode-dependent translated word (` and ` / ` or `). A filter whose term resolves to nothing falls back
to the unfiltered phrase rather than emit an empty gap.

The attack bonus lines show the attack icon followed by the signed value: "[attack] +10 to each
of your [attack] items", "[attack] +50% to a random [attack] item of yours".

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

`project.godot` sets `gui/timers/tooltip_delay_sec = 0` — no hover delay on a built-in
tooltip anywhere in the game, which is what a hoverable keyword chip wants.
