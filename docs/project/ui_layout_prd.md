# Dark Corridor — UI / Layout PRD

Presentation PRD (input layer + screen composition). Sits under the [Architecture Map](architecture.md). The `UI` is **how the player reads the game and acts on it** — the screen composition (the corridor/combat scene, the item boards, potions, portrait, the choice/draft/map screens) and the **input layer** that emits *intents* (it never mutates game state). Its companion is the [VFX driver](vfx_driver_prd.md) (the combat wall); this doc is the layout + the input seam.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Built with** the theme resource + `.tscn` scenes (`CLAUDE.md`: theme over code, scenes over code).

Boundaries live in the hub: [architecture.md → Interface contracts → `UI`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

Items are the game; the UI is how the player parses a 30-item cascade and makes the draft decision off it (design). Two jobs:

- **Screen composition** — lay out the corridor/combat scene, the item boards (player + enemy), potions, the portrait + HP, and the out-of-combat screens (choice layer, draft, the 1D progress map).
- **Input (intents)** — capture player commands and emit **intents**; logic interprets them. The UI **never mutates game state directly** (architecture). The intents: timescale (hover slow-mo), **battle-speed** (×1/×2/×3 dial — a `Game` session preference applied to the fight's `Timekeeper` base scale), throw-potion, draft-pick, choice-point pick, event-option pick, and **pause** (a run-screen gate, not a `Game` phase).

What it **is not**: not game logic (it emits intents — the `Combat manager` / `Run manager` / `Encounter` interpret them); not the combat wall (`VFX driver`); not the corridor renderer (`docs/corridors/`) — it composes *with* it.

---

## The central open question: framed vs. full-screen

**Unresolved — a mockup decision, not a paper one (design).** Two live approaches:

- **Small game-area + large-UI frame** (Wizardry / Eye of the Beholder family) — the combat scene small and framed, items dominating the surround; gets a cramped-corridor feel for free.
- **Full-screen scene** (Topdeck Automat-style) — the character on-screen, items around them, UI integrated into the scene; more room to breathe, but must *substitute* for the cramped feel (darkness-as-funnel + board-density-as-crowding — art doc).

Mock up one of each with placeholder items; decide on feel. Everything below holds either way.

## The corridor & the approaching encounter

The corridor view is **mood + feedback**, not the focus (design) — but it carries the **between-encounter beat**: the **next encounter is created right after the draft and approaches from depth**. The `Run manager` spawns the next `Encounter`'s enemies at the vanishing point; the corridor advance (the ~2–3s walk) scales them up into full view (enemies are 2D sprites with their own depth-scaling — art doc); on **arrival** (front segment locked at full scale — "encounters happen at a place") combat / event resolution begins and the boards activate. The walk *is* the encounter arriving, not dead time. (The advance + depth-scaling is the `docs/corridors/` renderer's; the UI composes the boards over it and times the board activation to arrival.)

## The boards (the cascade, made legible)

Colour is the readability mechanism that scales (design) — you can't parse 30 names in 15s, but you can parse "lots of red on my side, blue on theirs." The board:

- **Type-zoned** — items in fixed, learnable regions by effect family (weapon / armor / heal / status-applier); synergy groups cluster + glow together when one fires. Fixed positions, hover-tilt on the focused item only — *not* drifting (art doc: motion = signal; a still board that erupts on fire reads as the cascade).
- **Colour-coded value panel** per item (extruding over the top edge): the panel background = effect family (red attack, blue block, green heal, per-effect status colours), the number = the value. Usually one panel; rares may show more.
- **Cooldown ring** (Bazaar-style filling overlay) on each active item — **on enemy items too** (mutual cooldowns = the visible race).
- **Rarity border** (bronze / silver / gold); **build-anchor** is a separate glow channel (never the border or size); **size** = a tempo tag (if it ships — Item PRD).
- **Bigger than feels comfortable**, so activations stay legible in a packed cascade.

The enemy board mirrors the player's (loadouts visible — "watch the cascades collide").

## Portrait, HP, potions

- **Player portrait** separate from the scene (identity anchor); **HP** shown as the portrait getting progressively beaten-up + the value as text.
- **Potion slots** distinct from item slots (tactical reserve, not item-cousin UI); **slow-mo-on-hover** to inspect + throw.

## Slow-mo-on-hover (one verb)

Hover anything important (own items, enemy items, potions, enemies) → time slows (~×0.05) → read. One consistent verb. It is a **timescale intent** the `Combat manager` interprets (sets the `Timekeeper` dial) — slow-mo slows **both sides** proportionally (can't dodge by inspecting). Out of combat (draft / choice) there's no clock — inspection is just tooltips.

## Battle-speed dial + pause (built)

- **Battle-speed** — an always-visible ×1/×2/×3 HUD toggle (`speed_button.tscn`, bottom-right). A **session preference on `Game`** (`battle_speed`, never saved); the run screen applies it to each fight's `Timekeeper` **base** scale. The hover slow-mo override **replaces** the base absolutely (resolved — same readable speed at any dial), returning to it on release.
- **Pause** — `ui_cancel` (Escape) raises `pause_menu.tscn` (Resume / Quit-to-menu) and freezes the run-screen tick (approach + fight). A **run-screen gate, not a `Game` phase**. Opaque centered panel, **no translucent scrim** (the pixel-art opacity rule). Quit-to-menu keeps the save (Title's Resume re-enters the beat). See [run_screen](../ui/run_screen.md).

## The out-of-combat screens

- **Choice layer** — the 2–3 location options at a choice point (two-tier: pick a location, then the within-choice); telegraphs the *category* (first-run legible — design). The pick is a **choice-point intent** → `Run manager`.
- **Draft** — the 1-of-3 reward; tooltips on hover; the pick is a **draft-pick intent**. (Enchant-target / potion-drop sub-choices — Draft PRD.)
- **1D progress map** — the act's beats + the player's position (boss at the end, relic at midpoint); forward visibility on a linear track, not a route map (design).

## Localization

Static UI text → English in the `.tscn`, auto-translated (no `tr()`); dynamic / data-driven text (item / encounter / status names, formatted strings) → `tr()` (`CLAUDE.md` localization). Dev/debug panels stay English.

---

## Prototype scope

- One combat scene: the player board + an enemy board (zoned, colour panels, cooldown rings) over the corridor view; the portrait + HP; a potion slot or two.
- The **approach**: the next encounter spawns at depth after the draft and scales into view; boards activate on arrival.
- Slow-mo-on-hover (the timescale intent); the draft (1-of-3) + a minimal choice presentation.
- **Pick one layout** (framed *or* full-screen) to prototype — the other is a later mockup compare.

**Not** in scope: the final layout decision, the full theme/palette, the 1D-map polish, the enchant/potion sub-choice UIs, multi-enemy board scaling.

---

## Open / deferred

- **Framed vs. full-screen** (above) + **item arrangement** (type-zoned grid vs. arc-around-character) — mockup decisions (art doc).
- **UI implementation in Godot** — all-2D (z-order) vs. items-in-3D-via-SubViewport vs. viewport-texture-on-quad; the deciding factor is items travelling over the frame + authoring 60 items (art doc). Build 3 placeholder items in the simplest (all-2D) first.
- **The theme resource** (`assets/themes/`) — palette + control styling; a content pass.
- **Camera bob / walk feel** during the approach — a feel question (art doc).
- **Cascade-readability at 30 activations** — the hardest open problem; validated only by seeing it (art doc + design open questions).

## Dependencies

- **Emits intents to:** the `Combat manager` (timescale, throw-potion), the `Run manager` (draft-pick, choice-point pick), the live `Encounter` (event-option pick). Never mutates state directly.
- **Reads (to draw):** actor / board / item / status / potion state + the `Run manager`'s map / run-state; composes over the `docs/corridors/` corridor renderer and the [VFX driver](vfx_driver_prd.md)'s combat wall.
- **Does not:** decide outcomes (logic interprets intents); render the combat wall (`VFX driver`); hold game state.
