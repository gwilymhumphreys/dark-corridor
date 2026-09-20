# Docs index

Catalog of project documentation. Agents: scan this first to find the relevant
doc before diving into code. Entries are deliberately short — each doc opens
with its own summary; match on the line here, then read the doc.

The layout, by the kind of question you're answering:

- **`docs/handoff.md` + `docs/decision_log.md`** — start here: orientation + the decision record.
- **`docs/systems/`** — one doc per engineering system (spec + as-built together),
  including the corridor and the dev tooling (autotest, localization).
- **`docs/design/`** — the creative layer: game design, art/audio direction,
  characters, content design, and the authoring how-to. **The owner's domain.**
- **`docs/history/`** — the build record: the chronological build log + the
  original phase plans (all built).

## Start here

| Doc | Covers |
|-----|--------|
| [handoff.md](handoff.md) | Fresh-agent orientation: what the game is, build status, how to run and test, settled lessons, the engineering backlog. |
| [decision_log.md](decision_log.md) | The canonical decision record (#1–#41): what was decided and why, and what is open or deferred. Don't re-litigate anything in it. |
| [documentation.md](documentation.md) | How the docs work: where each kind lives and the rules for writing them (sync with code in the same change, catalog every doc, intent not numbers, plan to system). |

## Systems (`docs/systems/`)

One doc per system — the spec and its as-built state live together. Cross-system
edges are not duplicated: they live once in the architecture map's **Interface
contracts (boundary hub)**, which every system doc links to.

| Doc | Covers |
|-----|--------|
| [systems/architecture.md](systems/architecture.md) | Architecture map and boundary hub: the system map, the combat spine, the scene tree and node model, and the interface contracts between systems. |
| [systems/combat_model.md](systems/combat_model.md) | How effects resolve in combat: the Ticker accrual primitive, accrual-only triggers, the fire/Delivery split, travel time, targeting and fizzle. |
| [systems/timekeeper.md](systems/timekeeper.md) | The combat clock: fixed-step `sim_time`, continuous `render_time`, the one speed dial and the step cadence; owned by the Combat manager. |
| [systems/actor.md](systems/actor.md) | The symmetric combatant: HP, a board of items, a status list. Player and enemy are the same type. |
| [systems/mechanics.md](systems/mechanics.md) | One class per combat rule (attack, shield, heal, poison, burn, bleed, regen, crit, charge, decharge) holding its name, description, icon, colour and landing behaviour, plus `MechanicRegistry`, the mechanic colours, and `IconSlots` (the twelve icon slots and the icon chosen for each). |
| [systems/status_manager.md](systems/status_manager.md) | The status system: a stateless facade over polymorphic `StatusEffect` classes, one file per status; stacking, the incoming-damage pipeline (amplify then absorb), the hook interface. |
| [systems/item.md](systems/item.md) | The board participant: data-defined, owns a Ticker; the fire pipeline (gate, fire, resolve, target-shape), target filters and the authored mechanics list, own-side trigger source filters, rarity, size, the one enchant slot, duplicate stacking. |
| [systems/combat_manager.md](systems/combat_manager.md) | The per-fight orchestrator: rosters and ordering, the Timekeeper lifecycle, the central tick, target resolution as pool then filter then pick, the trigger event bus, player input-intents. |
| [systems/combat_log.md](systems/combat_log.md) | The per-fight observation log: a combat-scoped sink written at each mutation site, holding side-aware per-item tallies and an ordered event timeline; read by the autotest, the live HUD and the combat report. |
| [systems/game_manager.md](systems/game_manager.md) | The session singleton (autoload `Game`): the game-state machine, run lifecycle, and save-lifecycle calls. |
| [systems/run_manager.md](systems/run_manager.md) | The descent: the map of acts and beats, encounter sequencing and corridor advance, player run-state, the HP economy, snapshot and rehydrate. |
| [systems/encounter.md](systems/encounter.md) | The per-beat orchestrator: one resolved beat (fight, event or rest); a fight spawns enemies, creates the Combat manager, then reports outcome and reward up. |
| [systems/draft.md](systems/draft.md) | The 1-of-3 reward draw: a stateless service producing three Draftable candidates, depth-weighted and seeded, skippable to bank gold. |
| [systems/enemy.md](systems/enemy.md) | Enemies: not a class, but an Actor built from an authored enemy definition. Enemy items are a content category and tiers are authoring conventions. |
| [systems/content.md](systems/content.md) | Relics, enchants and consumables: the three content categories beyond Item — a persistent run modifier, a one-per-item modifier, a manually-fired reserve. |
| [systems/spore_engine.md](systems/spore_engine.md) | Spore-engine seams (engineering, all built): status-stack consumption, evasion as an "acts but misses" fizzle, and the player-side mid-fight roster add. |
| [systems/item_creation_and_decay.md](systems/item_creation_and_decay.md) | Item creation, decay and consume seams (engineering, all built): the `CREATE_ITEM` Delivery kind and `add_item`, decay as an item-targeted use-status, the `ITEM_DESTROYED` event, and own-board item consume. |
| [systems/save.md](systems/save.md) | Run persistence: a snapshot pushed on encounter entry and returned on load. Run-persistent state only, combat is ephemeral, no migration. |
| [systems/ui_layout.md](systems/ui_layout.md) | The UI and layout spec plus the input layer: screen composition and the four `ScreenSections` (split point, padding, reflow); input emits intents and never mutates state. |
| [systems/vfx_driver.md](systems/vfx_driver.md) | The combat wall: projectiles, impacts, fire-emotes and damage numbers rendered as a pure function of handed state and `render_time`, writing no game state. |
| [systems/run_screen.md](systems/run_screen.md) | The built run UI: the presentation tree, the real-time seam, the run-screen state machine, the framed combat view, overlays, character select and settings. |
| [systems/tooltips.md](systems/tooltips.md) | The combat item tooltip: hovering a board item opens a main panel and a keyword column beside it, with per-keyword built-in custom tooltips, live values and the item-to-cluster mouse bridge. |
| [systems/audio.md](systems/audio.md) | Audio: `SfxManager` (polyphonic one-shots, per-key cooldown, pitch jitter), `MusicManager` (shuffle and crossfade), the bus layout, and the volume and silent-run defaults in `Prefs`. |
| [systems/cursor.md](systems/cursor.md) | The mouse cursor: the stone pointer replaces the operating system's cursor, with a brightened copy shown over clickable controls through the `Cursor` autoload and `mouse_default_cursor_shape`. |
| [systems/control_feedback.md](systems/control_feedback.md) | How a control answers the pointer: the printed border on a hovered or selected control, the wash that lights a button's body, the press drop and the release pulse; the F5 tab. |
| [systems/ui_juice.md](systems/ui_juice.md) | The `UIJuice` drop-in node (press squash and drop, the hover and press highlight, and hover and click sounds for any Control, with presets and overrides) and `PortraitBreath`, the slow zoom on portraits. |
| [systems/localization.md](systems/localization.md) | How player-facing text is authored (static `.tscn` auto-translate, dynamic `tr()`) and the headless POT pipeline. |
| [systems/testing.md](systems/testing.md) | How tests are written: GUT conventions, the per-area `tests/` folders, `TestCleanup` for resetting autoloads between tests, and signal assertions. |
| [systems/godot_notes.md](systems/godot_notes.md) | Godot 4 engine behaviours that have cost time here: reimporting after adding files or a `class_name`, `RichTextLabel` `fit_content` sizing, shader built-ins and includes, runtime cleanup in `_exit_tree()`, and the two known causes of scripts leaking at exit. |
| [systems/autotest.md](systems/autotest.md) | AutoTest mode: headless deterministic runs driven by draft strategies, with stuck and timeout guards and a markdown report of per-item fires, damage, shield and healing — what `tune` reads. |
| [systems/delegate.md](systems/delegate.md) | Handing a planned change to the local model: the project's `.claude/delegate.json`, its denied paths, and the three verification stages (code-standards check, Godot reimport, GUT suite). |
| [systems/debug_panel.md](systems/debug_panel.md) | The dev-only `DebugPanels` autoload: one panel with a preset bar and six tabs — F1 corridor, F2 interface and palette colours, F3 print, F4 background wear, F5 control feedback, F6 icon slots — plus the start-up arguments used for screenshots. |
| [systems/look_presets.md](systems/look_presets.md) | Look presets: the whole look in one file in five parts, the default preset loaded at start-up, the history folder kept by Make default, and the preset bar. |
| [systems/corridor_look.md](systems/corridor_look.md) | The corridor look: a post-processing shader on the corridor image (grade, colour ramp, halftone, hatching, bloom, scanlines, grain, vignette, posterize, pixelate), the F1 tab built from its uniform groups, and the corridor light and Environment controls. |
| [systems/interface_look.md](systems/interface_look.md) | The interface look: the corridor look's effects applied to interface images (icons, portraits, HP bars, value pills) through two shared materials, one for the pictures and one for the interface elements that keep their palette colour, the F2 tab, and copying settings to and from the corridor look. |
| [systems/interface_glow.md](systems/interface_glow.md) | Making a specific interface node glow from code (`InterfaceGlow.set_glow`, `flash`) by raising `self_modulate` above white, with 2D HDR and a screen glow that is only on while something glows. |
| [systems/palette_clamp.md](systems/palette_clamp.md) | The palette clamps: a screen shader snapping every pixel to a chosen palette and a world clamp on the combat corridor viewport, with RGB or OKLab matching and ordered dithering; `PaletteLoader` reads Lospec PNG strips and `.gpl` files. |
| [systems/background_wear.md](systems/background_wear.md) | A shader drawing print wear (faded areas, specks, rubbed edges, creases, folds) on each screen's background rectangle, shared with the corridor overlay through `print_wear.gdshaderinc`; the F4 tab. |
| [systems/print_frame.md](systems/print_frame.md) | The F3 Print tab (the screen sections' split point and padding) and `PrintFrame`, which draws a rough printed border behind it and an overlay carrying the background wear across the corridor. |
| [systems/panel_wear.md](systems/panel_wear.md) | Print wear on UI panels, applied by default through the theme: `WornStyleBox` wraps a panel's stylebox and draws it worn through a shared `PrintLook.panel_material`, which also draws the control feedback. |
| [systems/interface_palette.md](systems/interface_palette.md) | The interface palette: a named `.gpl` file replaces the `Colours` variables and recolours the theme's fonts, images and panels by brightness; `PaletteStyleBox`, `NamedColourRect` and `--ui-palette`. |
| [systems/ui_theme.md](systems/ui_theme.md) | The `dark_corridor` theme: flat palette-following panel and button styles with no pack art left, the chunky-UI-on-a-1440p-canvas approach, the `UI_SCALE` sizing unit, and Rakkas as the default font. |

### Corridors (`docs/systems/corridors/`)

The first-person "dark corridor": one real 3D corridor.

| Doc | Covers |
|-----|--------|
| [systems/corridors/corridor_3d.md](systems/corridors/corridor_3d.md) | `Corridor3D`, the only corridor: a SubViewport 3D scene with a fixed camera, one OmniLight3D at the camera, enemies as lit `Sprite3D` nodes sized and placed by depth, and sections built by a swappable piece source (code-built quads or a bought kit). |

## Design (`docs/design/`)

Creative-direction + content working docs (the paper layer, distinct from the
system docs). **Content is the project owner's domain — don't author content
unless asked.** The authoring how-to is the bridge to implementation.

| Doc | Covers |
|-----|--------|
| [design/game_design.md](design/game_design.md) | The whole-game design snapshot: pitch, core loop, combat, items, enchants, relics, consumables, statuses, encounters, characters, meta-progression and scope. |
| [design/art_audio.md](design/art_audio.md) | Art direction and audio: the look being explored with existing art, post-processing and palettes; art sources, world and interface colours, readability, dungeon-synth audio, candidate asset packs. |
| [design/asset_credits.md](design/asset_credits.md) | Who made the third-party assets we ship and where they came from: the three dungeon synth music packs, plus the art packs and font whose sources still need filling in. |
| [design/asset_library.md](design/asset_library.md) | Where the source art packs live (`../dark-corridor-design/`), how to find a file by name, what each pack folder holds, and where copies land in `assets/`. |
| [design/influence_dcc.md](design/influence_dcc.md) | Tone and concept, with Dungeon Crawler Carl as the touchstone: fuse two recognisable ideas so the seam shows; humour is a byproduct and delivery stays grim. |
| [design/spore_druid.md](design/spore_druid.md) | Spore Druid working file (the first character): spores as the signature engine, the Mass and Self pillars with Summon a candidate, the spore list, idea bank and commons table. |
| [design/armourer.md](design/armourer.md) | Armourer working file (the starter character): the low-load anchor, the shield stack-and-spend engine, about three overlapping archetypes, shield as fuel on the built consume seam. |
| [design/character_ideas.md](design/character_ideas.md) | Uncommitted character concepts, plus the resource-economy toolkit: a character is a resource dressed in a theme that isn't its obvious home. |
| [design/mechanic_ideas.md](design/mechanic_ideas.md) | Uncommitted mechanics sampled from other games — status rules, triggers and costs — each with its source game and a sounding-board read. |
| [design/card_pool_targets.md](design/card_pool_targets.md) | Card-pool breadth targets per character: signals by combat role, never quotas; the skew inverts for status-identity characters. |
| [design/per_character_pools.md](design/per_character_pools.md) | Why item pools split per character (decision #27): the colorless layer was rejected though individual colorless items are allowed, and enemies and reward relics stay shared. |
| [design/item_heuristics.md](design/item_heuristics.md) | Item tuning heuristics as starting numbers rather than rules: the DPS curve, rider costs, spores free. Real balance is decided in `/tune`. |
| [design/authoring.md](design/authoring.md) | Content authoring guide (companion to the `/content` skill): the def and catalog pattern, string ids, pool membership, and the import and POT gotchas. |

## Plans (`docs/plans/`)

Approved-but-unbuilt designs (temporary working specs). **Not catalogued here** — they're transient;
browse [`docs/plans/`](plans/) directly. A plan that ships becomes a `docs/systems/` doc, which *is*
catalogued above (the plan file stays for rationale/lineage).

## History (`docs/history/`)

The build record — useful for archaeology, not required reading.

| Doc | Covers |
|-----|--------|
| [history/build_log.md](history/build_log.md) | The chronological build log: dated entries for everything built, with test counts. Current status lives in the handoff. |
| [history/phase1_plan.md](history/phase1_plan.md) · [phase3](history/phase3_plan.md) · [phase4](history/phase4_plan.md) · [phase5](history/phase5_plan.md) | The original phase plans, all built: combat spine (1), run loop (3), real UI and run screen (4), `tune` machinery (5). Phase 2 (autotest scaffolding) had no separate plan file. |
