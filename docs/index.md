# Docs index

Catalog of project documentation. Agents: scan this first to find the relevant
doc before diving into code. Entries are deliberately short — each doc opens
with its own summary; match on the keywords here, then read the doc.

The layout, by the kind of question you're answering:

- **`docs/handoff.md` + `docs/decision_log.md`** — start here: orientation + the decision record.
- **`docs/systems/`** — one doc per engineering system (spec + as-built together),
  including the corridor renderers and the dev tooling (autotest, localization).
- **`docs/design/`** — the creative layer: game design, art/audio direction,
  characters, content design, and the authoring how-to. **The owner's domain.**
- **`docs/history/`** — the build record: the chronological build log + the
  original phase plans (all built).

## Start here

| Doc | Covers | Keywords |
|-----|--------|----------|
| [handoff.md](handoff.md) | **Fresh-agent orientation.** What the game is, current build status, how to run/test, settled lessons, and the engineering backlog. | handoff, onboarding, orientation, start here, build status, how to run, autotest commands, next steps |
| [decision_log.md](decision_log.md) | **The canonical decision record** (#1–#29): what was decided and why, the working approach, and what's open/deferred. Don't re-litigate anything in it. | decisions, rationale, settled, open questions, deferred, naming history |
| [documentation.md](documentation.md) | **How the docs work** — where each kind lives, and the rules for writing/maintaining them (sync-with-code in the same change, catalog every doc, intent-not-numbers, plan→system lifecycle). | documentation, docs, conventions, style guide, index entry, update docs, keep in sync, plan to system, meta |

## Systems (`docs/systems/`)

One doc per system — the spec and its as-built state live together. Cross-system
edges are not duplicated: they live once in the architecture map's **Interface
contracts (boundary hub)**, which every system doc links to.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [systems/architecture.md](systems/architecture.md) | **Architecture map + boundary hub.** System map, the combat spine, the scene tree & node model, and the Interface contracts. | architecture, system map, autoload, dependencies, boundary hub, interface contract, scene tree, node model, RefCounted, presentation tree |
| [systems/combat_model.md](systems/combat_model.md) | **How effects resolve in combat.** The Ticker accrual primitive, accrual-only triggers (the Bazaar lesson), the fire/Delivery split, travel time, targeting/fizzle. | combat, Ticker, accrual, trigger, charges, fire, Delivery, travel_time, cooldown, targeting, fizzle |
| [systems/timekeeper.md](systems/timekeeper.md) | **The combat clock.** Fixed-step `sim_time` + continuous `render_time`, the one speed dial, and the step cadence; owned by the Combat manager. | timekeeper, clock, fixed timestep, sim_time, render_time, timescale, dial, slow-mo, pause, determinism |
| [systems/actor.md](systems/actor.md) | **The symmetric combatant.** HP, a board of items, a status list; player and enemy are the same type. | actor, HP, board, status list, symmetric, take_damage, heal, died, block, combatant |
| [systems/status_manager.md](systems/status_manager.md) | **The status system.** A stateless facade over polymorphic `StatusEffect` classes (one file per status, #29): apply/stacking, the incoming-damage pipeline (amplify → absorb), the hook interface. | status, StatusEffect, polymorphic, facade, hook, poison, block, weak, vulnerable, blind, silence, spores, stacks, duration, absorb |
| [systems/item.md](systems/item.md) | **The board participant.** Data-defined, owns a Ticker; the fire pipeline (gate → fire → resolve → target-shape; a gated cooldown freezes, #30). Triggers default to own-side events (`source_filter`). Rarity = complexity, size = tempo, one enchant slot, duplicates stack. | item, board, Ticker, trigger, source filter, own side, gate, freeze, silence, weapon, armor, AOE, rarity, enchant, duplicate, fire, payload, target-shape, synergy |
| [systems/combat_manager.md](systems/combat_manager.md) | **The per-fight orchestrator.** Live rosters + ordering, the Timekeeper lifecycle, the central tick, target-shape resolution, the trigger event bus (source identity + side filters + unsubscribe + listeners, #30), player input-intents. | combat manager, orchestrator, central tick, win/loss, targeting authority, event bus, source identity, side filter, listener, unsubscribe, rosters, Delivery, per-fight |
| [systems/game_manager.md](systems/game_manager.md) | **The session singleton** (autoload `Game`): the game-state machine, run lifecycle, and save-lifecycle calls. | game manager, session, autoload, state machine, title, death screen, run lifecycle |
| [systems/run_manager.md](systems/run_manager.md) | **The descent.** The map (acts/beats + auto-roll), encounter sequencing + corridor advance, player run-state, HP-economy policy, snapshot/rehydrate. | run manager, map, acts, beats, roll, encounters, run-state, HP economy, snapshot, resume, RNG |
| [systems/encounter.md](systems/encounter.md) | **The per-beat orchestrator.** One resolved beat (fight / event / rest); a fight Encounter spawns enemies + creates the Combat manager, then reports outcome + reward up. | encounter, beat, fight, event, rest, telegraph, elite, boss, composition, reward |
| [systems/draft.md](systems/draft.md) | **The 1-of-3 reward draw.** A stateless service producing three Draftable candidates; depth-weighting only (no hidden archetype weighting), seeded, no skip. | draft, reward, 1-of-3, pool, depth weighting, rarity, no skip, enchant, potion, seeded, Draftable |
| [systems/enemy.md](systems/enemy.md) | **Enemies.** Not a class — an Actor built from an authored enemy definition; enemy items are a content category; tiers are authoring conventions. | enemy, authored board, attack item, tier, regular, elite, boss, signature, summons |
| [systems/content.md](systems/content.md) | **Relics · enchants · consumables.** The three thin content categories beyond Item — persistent run modifier / one-per-item modifier / manually-fired reserve. | content, relic, enchantment, consumable, potion, draftable, run-state, modifier, throw |
| [systems/spore_engine.md](systems/spore_engine.md) | **Spore-engine seams** (engineering, not content — all built). Status-stack consumption, evasion (the "acts but misses" fizzle), the player-side mid-fight roster add. | spore engine, consume, stacks, fuel, evasion, miss, whiff, fizzle reason, summon, token, Spore Druid |
| [systems/save.md](systems/save.md) | **Run persistence.** A pushed snapshot on encounter entry, returned on load; run-persistent state only, combat ephemeral, no migration. | save, persistence, snapshot, encounter entry, resume, RNG, no migration, autosave |
| [systems/ui_layout.md](systems/ui_layout.md) | **UI / layout spec + the input layer.** Screen composition; input emits intents and never mutates state; framed-vs-full-screen is the open mockup question. | ui, layout, hud, boards, cooldown ring, hover, intents, draft, progress map, portrait, framed, full-screen |
| [systems/vfx_driver.md](systems/vfx_driver.md) | **The combat wall.** Renders projectiles, impacts, fire-emotes, damage numbers as a pure function of handed state + `render_time`; writes no game state. | vfx, wall, projectile, impact, render_time, fire-emote, damage numbers, screen shake, stateless |
| [systems/run_screen.md](systems/run_screen.md) | **The built run UI** (as-built companion to ui_layout + vfx_driver). The presentation tree, the real-time seam, the run-screen FSM, the framed combat view, overlays, character select, settings. | run screen, presentation tree, framed, combat view, corridor, occupant, approach, FSM, draft overlay, map strip, character select, settings, pause, slow-mo |
| [systems/tooltips.md](systems/tooltips.md) | **The combat item tooltip** (gen 3, built). Hover a board item → a cluster (main panel + always-shown keyword column) beside it; per-keyword info via Godot built-in custom tooltips on body chips; default-side + screen-half-fallback positioning; live read-only values with a changed-value highlight; the item↔cluster mouse-bridge; catalog-gated keywords. | tooltip, hover, keyword, custom tooltip, _make_custom_tooltip, positioning, mouse bridge, item panel, KeywordCatalog, live values, chip, cluster |
| [systems/audio.md](systems/audio.md) | **Audio.** Two autoloads + bus layout: `SfxManager` (polyphonic one-shots, per-key cooldown, pitch jitter) and `MusicManager` (shuffle + crossfade). | audio, sound, sfx, music, SfxManager, MusicManager, autoload, bus, crossfade, one-shot |
| [systems/ui_juice.md](systems/ui_juice.md) | **UI juice.** The `UIJuice` drop-in node: hover bounce + press squash + sounds for any Control; presets + per-value overrides. | juice, UIJuice, hover, press, bounce, squash, tween, preset, button feel |
| [systems/localization.md](systems/localization.md) | **Localization.** How player-facing text is authored (static `.tscn` auto-translate; dynamic `tr()`) and the headless POT pipeline. | localization, i18n, translation, tr, POT, locale, po, auto_translate, name_key, gettext |
| [systems/autotest.md](systems/autotest.md) | **AutoTest mode** (dev harness). Headless deterministic E2E: drives a full run (or one fight) with draft strategies, stuck/timeout guards over the live rosters, and a markdown report (per-item fires/damage/block/healing; stamped with seed + strategy) — what `tune` reads. | autotest, e2e, headless, deterministic, seed, speed, driver, strategy, regression, report, block, healing, exit code, tune |

The Black & White UI theme (`assets/themes/black_white_ui.tres`, the project
default) is not yet documented here.

### Corridors (`docs/systems/corridors/`)

The first-person "dark corridor" renderer — pseudo-3D from 2D pixel art, two
interchangeable renderers over a shared base. **Read `common.md` first**; it has
the which-renderer guide, the file map, and the embedding panel.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [systems/corridors/common.md](systems/corridors/common.md) | Shared base + host: the `CorridorRenderer` interface, movement/blur/filter model, project settings, the testbed, the drop-in clipping panel, which renderer to use. | corridor, base class, CorridorRenderer, host, testbed, toggle, sharp bilinear, blur, velocity ramp, panel, clipping, view_size |
| [systems/corridors/scale_and_place.md](systems/corridors/scale_and_place.md) | **`CorridorScaled`** (default). Rigid scaled tiles in a geometric series; four rotated sides = full box; per-side textures. | scale and place, rigid tiles, geometric series, depth_ratio, box, per-side textures, default |
| [systems/corridors/perspective_quad.md](systems/corridors/perspective_quad.md) | **`CorridorPerspective`** (toggle). Walls as textured `Polygon2D` trapezoids; depth quads subdivided into strips to kill affine swim. | perspective quad, Polygon2D, trapezoid, affine, swim, subdivision, vanishing point, toggle |

## Design (`docs/design/`)

Creative-direction + content working docs (the paper layer, distinct from the
system docs). **Content is the project owner's domain — don't author content
unless asked.** The authoring how-to is the bridge to implementation.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [design/game_design.md](design/game_design.md) | **The whole-game design snapshot** (working doc): pitch, core loop, combat, items/enchants/relics/consumables, statuses, encounters, characters, meta-progression, scope. | design, core loop, draft, auto-combat, items, rarity, synergy, status, encounters, characters, meta, roguelike, Bazaar, Slay the Spire |
| [design/art_audio.md](design/art_audio.md) | **Art direction & audio** (vibes doc): the corridor look, dark-fantasy tone, pixel-art resolution debate, cascade readability, dungeon-synth audio, candidate asset packs. | art, audio, pixel art, palette, readability, dungeon synth, lighting, tone, dread, asset packs, attribution |
| [design/influence_dcc.md](design/influence_dcc.md) | **Tone & concept — recombination** (touchstone: Dungeon Crawler Carl). Fuse two recognisable ideas so the seam shows; humour is a byproduct, delivery stays grim. | tone, recombination, Dungeon Crawler Carl, bestiary, fusion, dread, grim humour, signature mechanic |
| [design/spore_druid.md](design/spore_druid.md) | **Spore Druid — working file** (first character). Spores as the signature engine; Mass / Self pillars + Summon candidate; spore list, idea bank, commons table. | spore druid, character, spores, Mass, Self, Spread, summon, thallid, blinding, lethal, commons |
| [design/character_ideas.md](design/character_ideas.md) | **Character ideas — parking lot** (uncommitted concepts) + the resource-economy toolkit: a character = a resource dressed in a theme that isn't its obvious home. | character ideas, parking lot, concepts, blade mage, wizard, black hole, mechanic, resource economy, stock, flow, mana, heat, ammo, gold, allies |
| [design/card_pool_targets.md](design/card_pool_targets.md) | **Card-pool breadth targets** per character — signals by combat role, never quotas; skew inverts for status-identity characters. | card pool, targets, breadth, commons, attack, skill, quota, skew, archetype tag |
| [design/per_character_pools.md](design/per_character_pools.md) | **Per-character item pools** (decision #27 rationale). Pools split per character; the colorless *layer* rejected (individual colorless items allowed); enemies + reward relics stay shared. | per-character pools, shared pool, colorless, focus vs range, scope trap, Battledraft, decision #27 |
| [design/item_heuristics.md](design/item_heuristics.md) | **Item tuning heuristics** (starting numbers, not rules): the DPS curve, rider costs, spores free; real balance is decided in `/tune`. | item heuristics, DPS curve, cooldown, rider cost, spores free, starting properties, balance |
| [design/authoring.md](design/authoring.md) | **Content authoring guide** (companion to the `/content` skill): the def + catalog pattern, string ids, pool membership = active/disabled, import + POT gotchas. | authoring, how to add content, def, catalog, string id, src/content, pool membership, item_pool, colorless, import, POT |

## Plans (`docs/plans/`)

Approved-but-unbuilt designs. Each becomes a `systems/` doc on ship.

_None pending — the tooltip system (gen 3) shipped; see [systems/tooltips.md](systems/tooltips.md).
Its plan, [plans/tooltip_system.md](plans/tooltip_system.md), is kept for the design rationale + prior-art lineage._

## History (`docs/history/`)

The build record — useful for archaeology, not required reading.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [history/build_log.md](history/build_log.md) | **The chronological build log**: dated entries for everything built, with test counts. Current status lives in the handoff. | build log, history, chronology, phases, test counts |
| [history/phase1_plan.md](history/phase1_plan.md) · [phase3](history/phase3_plan.md) · [phase4](history/phase4_plan.md) · [phase5](history/phase5_plan.md) | **The original phase plans** (all built): combat spine (1), run loop (3), real UI / run screen (4), `tune` machinery (5). Phase 2 (autotest scaffolding) had no separate plan file. | phase plan, build order, steps, combat spine, run loop, run screen, tune |
