# Plan — Tooltip system (gen 3)

Implementation plan for the combat item tooltip. **Not yet built.** This is the
agreed, code-grounded design; it becomes `docs/systems/tooltips.md` once shipped.
Third time we've built tooltips (after `../a-machine` and `../battledraft`) — see
*Prior art*.

**Engine:** Godot 4.7. **Status:** approved, pre-build. Written to be implementable
by a fresh agent — every external fact is grounded against a file below.

---

## What the player sees

Hover any board item → a **cluster** appears beside it:

- **Main panel** (nearest the item) — the item's name + rarity tint, its effect
  lines (generated, with **live values**), an optional authored flavor line, and a
  small stat block (cooldown). Effect lines embed keyword **chips** (icon + name).
- **Keyword column** (cards stacked beside the main panel) — one card per keyword
  the item references (statuses + mechanics), **all shown at once** so meaning is
  there at a glance.
- **Per-keyword pinpoint tip** — hovering a chip pops a **Godot built-in custom
  tooltip** (`_make_custom_tooltip`) with that keyword's full card, positioned and
  clamped by the engine. No manual sub-tooltip layout.

The cluster shows/hides as a unit, driven by a per-frame hover poll. It is
**suppressed while the pause menu is open**.

---

## Verified against the code (grounding — read these before building)

| Fact | Source |
|------|--------|
| The framed view is the production target; `ItemCell` is instantiated **only** here (and `enemy_hud` / `ally_slot`), **not** in `combat_sandbox` (which uses `BoardView`/`ItemIcon`). | `src/scenes/combat/combat_view_framed.gd`, `item_cell.gd` |
| Hover detection is currently **point-based**: `CombatView.mouse_over_inspectable(point) -> bool` hit-tests enemy HUDs, ally slots, player cells, potion slots by `get_global_rect().has_point()`. (Cells are `Control`s, so `mouse_entered` signals are *also* viable — see *Driving*.) | `combat_view_framed.gd:196` |
| Widgets are **reconciled, not rebuilt**: `_build_player_items` builds the player column **once at `bind`**; `_sync_rosters` only **adds** a HUD/slot when an actor joins and **drops** it when it leaves (persists between). `_position_enemy_huds` **repositions** enemy HUDs every frame (their global rect moves). | `combat_view_framed.gd:71`, `:81`, `:131` |
| Player board cells: `_player_cells: Item -> ItemCell`. Enemy cells live inside `EnemyHud` (`cell_centre(item)`, `mouse_over(point)`, `_cells: Item -> ItemCell`); ally cells inside `AllySlot` (same shape). | `combat_view_framed.gd:36`, `enemy_hud.gd:90` |
| `ItemCell` is a `Control`; `cell_centre()` returns the global centre; `get_global_rect()` its global rect. | `item_cell.gd:103` |
| **No `Draftable` class exists** — it is a *design concept* in the docs, not code. The combat hover target is an **`Item`** (`item.def: ItemDef`, `item.statuses`, `item.enchant`). | grep `class_name Draftable` → none; `item.gd` |
| `ItemDef = {id, name_key, rarity, cooldown, effects[], trigger_subs[], panel_color}`. **No description field yet.** | `item_def.gd` |
| `ItemEffect = {kind, value, shape, status_id, duration, flags, consume_id, consume_amount, consume_from_target, consume_scale, summon_def_id, …}`. | `item_effect.gd` |
| `Delivery.Kind = {DAMAGE, HEAL, APPLY_STATUS, SUMMON}` — **no BLOCK** (block = `APPLY_STATUS` with `status_id == 'block'`). `Delivery.Flag = {NONE=0, UNBLOCKABLE=1}` (bitmask). | `delivery.gd:10` |
| `ItemEffect.Shape = {SELF, OPPONENT_LEFTMOST, ALL_OPPONENTS, OPPONENT_ITEM_RANDOM, ALL_OPPONENT_ITEMS}`. | `item_effect.gd:7` |
| The live-value path **mutates**: `Item.fire()` calls `cooldown.reset()`; `_resolve_effect()` calls `StatusManager.consume()` which **spends stacks**. `StatusManager.modify_outgoing(owner, v)` and `enchant.def.value_mult` are **pure**. | `item.gd:28`, `item.gd:50` |
| Statuses carry `id, name_key, color, icon` and live in `StatusRegistry` (7: block, poison, weak, vulnerable, blind, silence, spores). **No description text yet.** | `status_effect.gd:14`, `status_registry.gd` |
| `extract_pot.gd` extracts: `tr('…')`/`tr("…")` literals in `.gd`; `name_key`/`blurb_key`/`label_key = '…'`; `.tscn` `text`/`tooltip_text`. `EXCLUDE_FILES` drops throwaway hosts. | `tools/extract_pot.gd:90` |
| The pause menu is a `CanvasLayer` at **layer 100** with a full-rect Catcher; the run screen gates the slow-mo hover poll on `_paused`. | `docs/systems/run_screen.md` |

---

## Decisions (ratified)

| Topic | Decision |
|-------|----------|
| Keyword info | Shown **all at once** in a stacked column beside the main panel. |
| Per-keyword hover | **In addition**, body keyword chips carry Godot **built-in custom tooltips** (same card). |
| Sub-tooltip layout | Delegated to Godot — **no manual sub-tooltip positioning / recursion**. |
| Cluster positioning | A **default side** (global default LEFT — the player board is the right-edge column); **fall back** to the screen-half flip if it won't fit; then clamp. |
| Description text | **Hybrid** — generated mechanical lines always (they hold live values); optional authored `description_key` **appended** as a flavor line. |
| Values | **Live** (enchant mult + `modify_outgoing`); a value differing from base is **highlighted** (accent colour + ▲/▼). Consume-scaling display **deferred** (it would need a non-mutating stack peek — see *Live values*). |
| Pause | Cluster **off** while the pause menu is open. |
| Hover delay | **None.** Set `gui/timers/tooltip_delay_sec = 0` (global; this system is the only consumer). |
| Mouse-bridge | **One level kept** (item ↔ cluster) so the cursor can travel onto the panel to hover chips. Recursive bridge dropped (Godot owns the keyword-tip lifetime). |
| Opacity | Opaque only. Opaque styleboxes + a scale reveal; **no fade**. |
| Scope (v1) | **Board `Item`s only** (player cells + enemy-HUD cells + ally-slot cells). Potions (Consumables, not Items) and out-of-combat draft tooltips are a follow-on. |

---

## Data flow (who drives what)

Both per-cell `mouse_entered` signals (cells persist, so signals would survive) and a
point-poll are viable. We use a **point-poll**, for these reasons (not because signals
can't work): it reuses the existing slow-mo hover (`mouse_over_inspectable`), keeping
one hover paradigm; the hide-bridge needs a cluster-rect check every frame regardless
(signals can't cover the floating cluster, and `mouse_exited` would hide the panel
before the cursor reaches the chips); and it avoids threading signals up through the
nested `EnemyHud` / `AllySlot` cell ownership. Flow:

1. **The run screen drives a hover poll** (the same place it already polls
   `mouse_over_inspectable` for slow-mo, gated by `_paused` and FIGHTING). Each frame
   it calls `view.update_inspection(mouse_pos)` while active, `view.stop_inspection()`
   on pause / fight end.
2. **The view hit-tests** via a new `inspectable_at(point) -> InspectTarget` (an
   `Item` + its global rect + a default side), iterating the same structures
   `mouse_over_inspectable` does. Returns null when the point is over no cell.
3. **The view owns the cluster** (`TooltipCluster` on a child `CanvasLayer`) and feeds
   it the target. The cluster handles show / re-target / the item↔cluster hide-bridge
   / positioning.
4. **Keyword chips** inside the cluster are plain `Control`s; their built-in tooltips
   are entirely Godot-managed (no involvement from the poll).

New view-side helpers required: `EnemyHud.item_at(point) -> Item` and
`AllySlot.item_at(point) -> Item` (mirror their existing `mouse_over`, returning the
item); `CombatView.inspectable_at(point)` + `update_inspection` / `stop_inspection`
(base no-ops; framed override real).

---

## The mouse-bridge hide-timer (why it stays)

The cluster sits beside the item with a gap. The hover poll considers the cluster
"alive" while the mouse is over **the item cell OR the cluster rect** (their bounding
merge bridges the gap). When the mouse leaves that merged region, a **~0.12s
hide-timer** starts; re-entering cancels it. This is needed *because the chips are
hoverable* — the cursor must be able to leave the cell and land on the panel. The
built-in keyword tips need no bridge (non-interactive: appear at the cursor, vanish on
move).

State per frame: `current_item`, `hide_timer`. Poll returns an item → set/retarget,
cancel timer. Poll returns null but mouse over cluster rect → hold. Poll null and
mouse outside merged region → tick the timer; hide at zero.

---

## Positioning algorithm (the cluster only)

The cluster rect = `main_w + gap + column_w` × `max(main_h, column_h)`. Per-keyword
tips are Godot's problem.

1. **Build + measure** — set content, set `custom_minimum_size.x` on each panel **and**
   on its `RichTextLabel` (= panel width − margins) so `fit_content` height is computed
   at the right width (the documented gotcha — `CLAUDE.md` "RichTextLabel fit_content
   Sizing"), then `reset_size()` and read `get_combined_minimum_size()`. Never trust a
   pre-layout `.size` (battledraft's first-show bug).
2. **Width cap** — cap each panel's max width so the cluster fits beside the item:
   `max_w = min(authored, (screen.w − anchor.w)/2 − 2·gap)`.
3. **Side** — try the default side (LEFT); if the cluster width doesn't fit there, flip
   to the side with more room; clamp x into `[margin, screen.w − w − margin]`.
4. **Vertical** — centre on the item (`anchor.center.y − h/2`), clamp to
   `[margin, screen.h − h − margin]`.
5. **Layout** — main panel nearest the item; keyword column on the outer side.
6. **Column overflow** — if the column exceeds screen height, wrap overflow into a
   second adjacent column toward the main (safety net; real items reference ~1–4
   keywords). `log`/note the wrap so it isn't silent.

**Coordinate space:** position with `cell.get_global_rect()` and clamp to
`get_viewport_rect()`. The cluster is a `CanvasLayer` (layer **50**, below pause's
100). This assumes the run-screen UI has **no custom canvas transform** (it has no
camera) — *verify on first run*; if it does, convert via `get_viewport().get_canvas_transform()`
as `a-machine`'s `BuildingTooltip._position_above_building` does.

---

## Live values (the read-only preview — do NOT reuse `fire()`)

`Item.fire()` / `_resolve_effect()` **mutate** (reset the cooldown, spend fuel via
`consume`). The tooltip must compute display values with a **separate pure method**:

```
# on Item — read-only, no side effects
func display_value(effect: ItemEffect) -> float:
  var v: float = effect.value
  if enchant != null:
    v *= enchant.def.value_mult                       # pure
  if effect.kind == Delivery.Kind.DAMAGE and owner != null:
    v = StatusManager.modify_outgoing(owner, v)        # pure (Weak etc.)
  return v
```

- **Base** for the "changed?" comparison is `effect.value` (× enchant mult, which is
  permanent, so the highlight reflects *combat-scoped* status changes, not the enchant).
  Decide base = `effect.value * enchant_mult` so only live statuses trigger the
  highlight. *(Confirm this framing on first content pass.)*
- **Consume-scaling is excluded from v1** — it's dynamic per-fire and reading it
  correctly needs a non-mutating stack peek (`StatusManager` has no read-only stack
  getter today). Showing a static consume number would mislead. Add a
  `StatusManager.stack_count(target, id)` peek + fold it in as a follow-on if wanted.
- **Highlight:** when `display_value != base`, tint the number + a ▲ (buff) / ▼ (nerf)
  glyph. Exact treatment is a theme/art call (the B&W theme makes literal green/red
  clash) — owner decides.

---

## Keyword extraction (catalog-gated)

From an `Item`, collect candidate keyword ids, then **keep only those present in
`KeywordCatalog`** (an absent id → no card, silently — that is how the owner enables a
mechanic keyword: by authoring its catalog entry). Dedup, statuses first (effect
order) then mechanics (fixed order):

- Per `effect`: `kind == APPLY_STATUS` → `status_id` (status). `consume_id != ''` →
  `consume_id` (status) + `kw:fuel`. `kind == SUMMON` → `kw:summon`. `shape ∈
  {ALL_OPPONENTS, ALL_OPPONENT_ITEMS}` → `kw:aoe`. `shape ∈ {OPPONENT_ITEM_RANDOM,
  ALL_OPPONENT_ITEMS}` → `kw:item_target`. `flags & Delivery.Flag.UNBLOCKABLE` →
  `kw:unblockable`.
- `def.trigger_subs` non-empty → `kw:trigger`; each sub's `filter` (a status id) →
  that status.
- `item.enchant != null` → `kw:enchant`.

---

## Generated effect lines (baseline copy — owner may rewrite)

Templates are `tr()` strings (auto-extracted), values via `.format()`. The status /
summon name is a **keyword chip**, not plain text. Baseline English (adjustable copy,
the owner's domain to refine):

| Kind / case | Template |
|-------------|----------|
| `DAMAGE`, single-target | `tr('Deal {0} damage to {1}')` |
| `DAMAGE`, AOE | `tr('Deal {0} damage to all enemies')` |
| `HEAL` | `tr('Heal {0}')` |
| `APPLY_STATUS`, SELF (e.g. block) | `tr('Gain {0}')` + chip |
| `APPLY_STATUS`, opponent (e.g. poison) | `tr('Apply {0}')` + chip |
| `SUMMON` | `tr('Summon')` + name |
| cooldown (stat block) | `tr('Every {0}s')` |
| trigger | `tr('On {0}: +{1}')` |

Shape→phrase map ({SELF, OPPONENT_LEFTMOST 'the enemy', ALL_OPPONENTS 'all enemies',
OPPONENT_ITEM_RANDOM 'a random enemy item', ALL_OPPONENT_ITEMS 'all enemy items'}) is
copy too.

---

## Built-in custom tooltip — the contract + the double-panel gotcha

- Each keyword chip is a `Control` that sets `tooltip_text = <keyword id>` (non-empty,
  required to trigger) and overrides `func _make_custom_tooltip(for_text: String) ->
  Object` to build + return a **frameless** keyword-card content node (icon + name +
  desc) from `KeywordCatalog.get(for_text)`. Godot frees the returned node on hide —
  hold no reference. *(Confirm the exact 4.7 signature/behaviour on first build.)*
- **Double-panel:** Godot wraps the returned node in the theme's `TooltipPanel`. So
  style `TooltipPanel` / `TooltipLabel` **opaque** in `black_white_ui.tres` and return a
  **frameless** node (the theme panel is the only frame). The manually-shown **column
  cards** are NOT Godot tooltips, so they wrap the *same content scene* in their own
  `PanelContainer`. (Shared content scene `keyword_card.tscn`; column wraps it, the
  built-in tip returns it bare.)
- Unknown id → `_make_custom_tooltip` returns `null` (no tip); the chip still renders
  its name. Never crash.

---

## Files

### New

| File | Role |
|------|------|
| `src/scenes/ui/tooltip/tooltip_cluster.gd` (+ `.tscn`) | The cluster on a `CanvasLayer` (layer 50). Owned by the view. Builds main panel + keyword column, runs the hide-bridge state machine, positions/clamps, shows/hides, clears its `Item` ref on hide + `_exit_tree`. |
| `src/scenes/ui/tooltip/tooltip_panel.gd` (+ `.tscn`) | The main item panel: title (name + rarity tint), body `RichTextLabel` (generated lines + chips + flavor), stat block. Fixed `custom_minimum_size.x`. |
| `src/scenes/ui/tooltip/keyword_card.gd` (+ `.tscn`) | **Frameless** keyword content (icon + name + desc). Returned bare by `_make_custom_tooltip`; wrapped in a `PanelContainer` for column cards. |
| `src/scenes/ui/tooltip/keyword_chip.gd` (+ `.tscn`) | Inline `Control` (icon + name) in the body. Sets `tooltip_text = <id>`, overrides `_make_custom_tooltip` → `keyword_card` from `KeywordCatalog`. |
| `src/scenes/ui/tooltip/tooltip_content.gd` | Builder: `Item → {title, generated body lines (with chips), flavor, stat block}` + the extracted keyword id list. Uses `item.display_value(effect)`. |
| `src/content/keywords/keyword_catalog.gd` | `id → {name_key, desc_key, color, icon}`. Status entries pulled from `StatusRegistry` (id/name_key/color/icon) + each status's new `desc_key`; **mechanic** entries (`kw:fuel`, `kw:summon`, `kw:aoe`, `kw:item_target`, `kw:unblockable`, `kw:trigger`, `kw:enchant`) authored here. **Owner writes `desc_key` text;** scaffold as marked placeholders. |
| `src/scenes/dev/tooltip_demo.tscn` (+ `.gd`) | **Throwaway host** (like `combat_sandbox`): builds one player `Item` with a couple of effects + a status or two, mounts an `ItemCell` + a `TooltipCluster`, force-shows the cluster, supports `--shot`. The verification harness for steps 1–4. Add to `extract_pot.gd` `EXCLUDE_FILES`. |
| `docs/systems/tooltips.md` | The as-built doc on ship (+ `index.md` entry + `decision_log.md` line). |

### Changed

| File | Change |
|------|--------|
| `src/combat/item.gd` | Add **read-only** `display_value(effect) -> float` (above). Must not call `fire()`/`_resolve_effect()`. |
| `src/content/statuses/status_effect.gd` | Add `desc_key: String` (plain-assigned in each subclass `_init`, like `name_key`). |
| The 7 status classes | Add `desc_key = '<placeholder>'` — **owner writes the text**. |
| `src/content/items/item_def.gd` | Add optional `description_key: String = ''` (authored flavor; `tr()`'d; empty = generated-only). |
| `src/scenes/combat/combat_view.gd` (base) | Add no-op `inspectable_at(point)`, `update_inspection(point)`, `stop_inspection()`. |
| `src/scenes/combat/combat_view_framed.gd` | Implement them; own the cluster `CanvasLayer`; hide + clear on `release()` + `_exit_tree`. |
| `src/scenes/combat/enemy_hud.gd`, `ally_slot.gd` | Add `item_at(point) -> Item` (mirror `mouse_over`). |
| `src/scenes/screens/run_screen.gd` | Drive `view.update_inspection(mouse)` while FIGHTING + not paused; `view.stop_inspection()` on pause / fight end (alongside the existing slow-mo poll). |
| `assets/themes/black_white_ui.tres` | Opaque `TooltipPanel` / `TooltipLabel` (battledraft's `tooltip_panel.tres` is precedent). |
| `tools/extract_pot.gd` | Add `desc_key` and `description_key` to the field-scan list (line ~98). Add `tooltip_demo` to `EXCLUDE_FILES`. |
| `project.godot` | `gui/timers/tooltip_delay_sec = 0`. |

---

## Build order

1. **Content builder + main panel** — `tooltip_content` (generated lines via
   `display_value`, changed-value highlight) + `tooltip_panel`, shown in
   `tooltip_demo.tscn`; verify via `--shot`.
2. **Cluster + positioning** — default side, screen-half fallback, clamp, the
   item↔cluster hide-bridge state machine. Main panel only, still in the demo.
3. **Keyword column** — extraction (catalog-gated) + `keyword_card` column from
   `KeywordCatalog` (statuses wired; mechanic entries scaffolded as placeholders).
4. **Chips + built-in tip** — `keyword_chip` in the body, `_make_custom_tooltip` →
   frameless `keyword_card`; opaque `TooltipPanel` theme; `tooltip_delay_sec = 0`.
5. **Real-view wiring** — `inspectable_at` + `item_at` helpers, `update_inspection`
   from the run screen, pause suppression. Verify by **manual hover** in the live run
   screen (`--autostart`) — `--shot` can't simulate a hover, so the demo scene covers
   headless and the run screen covers the real wiring.
6. **POT extension, docs, decision-log.**
7. **Owner authors content** — status `desc_key`s, mechanic descriptions in
   `keyword_catalog.gd`, optional item `description_key`s; refine the generated-line
   copy. All scaffolded as marked placeholders by the build.

---

## Edge cases

- Cluster wider than either side → width cap; worst case clamp + partial overlap.
- Cluster taller than screen → vertical clamp; column overflow wraps to a second column.
- Item in a corner / near screen centre → side by room, vertical clamp.
- Rapid item-to-item hover → poll retargets instantly (no show delay).
- Mouse leaves cell toward the panel → hide-bridge holds it (the core reason it exists).
- Live fight / slow-mo → read-only (`display_value`); never `fire()`; mutates nothing.
- Pause → poll stops + explicit `stop_inspection()` hides the cluster; the pause
  Catcher (layer 100) also blocks new hovers.
- Player / enemy-HUD / ally-slot cells → all resolved by `inspectable_at`. Enemy HUDs
  are **repositioned** every frame (`_position_enemy_huds`), so the cluster re-reads the
  hovered `cell.get_global_rect()` each frame to track a moving cell (re-query, don't
  cache the rect).
- Enemy reaped / item leaves the board mid-hover → poll returns null next frame →
  hide-timer dismisses. Cluster must `is_instance_valid` / null-check its `Item`.
- Enchanted / triggered item → extra lines; enchant + trigger filter as chips.
- Unknown keyword id → chip renders its name, `_make_custom_tooltip` returns null, no
  column card. Never crash.
- Locale switch → rebuild on next show (the cluster is transient).
- Teardown → `release()` + `_exit_tree` hide the cluster and drop the `Item` ref (the
  Actor↔Item RefCounted cycle is broken at `dissolve()` — the cluster must not retain
  an Item across teardown). See the *combat-object-lifetime* note.
- Window resize / multi-monitor → read `get_viewport_rect()` each show.
- Potions / relics / enchants → **out of v1 scope** (potions are Consumables on
  `potion_slot` Buttons, not Items). The builder is `Item`-typed; extend later.

---

## Prior art (what was kept)

- **battledraft `TooltipManager`** — reuse one persistent instance; the screen-half
  flip kept as the **fallback** (it was chosen there after layout bugs made other
  methods unstable — hence "default side first, screen-half as fallback").
- **a-machine `BuildingTooltip`** — the mouse-bridge + hide-timer; `reset_size()`
  measurement; the scale reveal; the canvas-transform conversion (only if the verify
  in *Positioning* shows we need it); the `TextFormat` token-registry idea.
- **New this generation** — Godot built-in custom tooltips for per-keyword tips
  (removing manual sub-tooltip positioning + recursion); body keywords as discrete
  chips (built-in tooltips are per-Control, not per-word); point-poll driving (reuses
  the view's existing point-hover for slow-mo and unifies the hide-bridge, vs per-cell
  signals — both viable).

---

## Owner's domain (content)

Engineering builds the system + scaffolds; the **text is the owner's**, left as marked
placeholders by the build:

- Each status's `desc_key` (7 classes).
- Mechanic keyword descriptions + which mechanics exist, in `keyword_catalog.gd` (a
  mechanic keyword appears only if it has a catalog entry).
- Optional per-item `description_key` flavor lines.
- The generated-line baseline copy (templates + shape phrases) — refine wording.
- The changed-value highlight treatment (colour / glyph) — a theme call.

---

## Open micro-decisions (defaults unless changed)

- **Base for the changed-value highlight** = `effect.value × enchant_mult` (so only
  combat-scoped statuses highlight). Confirm on first content pass.
- **Column form** — full cards (default) vs compact + detail-on-hover.
- **Whether column cards also carry the built-in tip** — default off (the body chips
  are the hover surface; the column already shows the text).
- **Consume-scaling in `display_value`** — deferred (needs a `StatusManager` stack
  peek); default off for v1.
</content>
