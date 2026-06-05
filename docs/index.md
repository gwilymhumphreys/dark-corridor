# Docs index

Catalog of project documentation. Agents: scan this first to find the relevant
doc before diving into code. Each entry lists the path, what it covers, and
keywords to match against.

## Project design & PRDs (`docs/project/`)

> **Picking up the work?** Read [project/decision-log.md](project/decision-log.md) first — the decisions made, their rationale, the open items, and the next steps. The current build target is [project/phase1_plan.md](project/phase1_plan.md) (the combat spine, step-by-step).

The game-design layer — paper/pre-prototype, except the corridors which are built
(see below). Start at the **design snapshot** for the whole game, the
**architecture map** for how systems fit together, then the **per-system PRDs**.
Each system is specced in its own file; cross-system edges are not duplicated —
they live once in the architecture map's **Interface contracts (boundary hub)**,
which every PRD links to. New PRDs are added one layer at a time, with prototype
information — not all up front.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [project/design.md](project/design.md) | **Design snapshot** (working doc). Whole-game pitch, core loop, combat, items/enchants/relics/consumables, status system, encounters/choice layer, characters, meta-progression, scope, open questions. | design, core loop, draft, auto-combat, items, rarity, synergy, enchantments, relics, potions, status, encounters, elites, characters, meta, roguelike, Bazaar, Slay the Spire |
| [project/architecture.md](project/architecture.md) | **Architecture map + boundary hub.** System map (downward deps, input/output boundary), the settled combat spine, the **scene tree & node model**, prototype scope, and the **Interface contracts** every PRD links to for its edges. | architecture, system map, autoload, Timekeeper, combat manager, StatusManager, Actor, Save, tick, timescale, dependencies, boundary hub, interface contract, scene tree, node model, RefCounted, presentation tree |
| [project/timekeeper_prd.md](project/timekeeper_prd.md) | **Timekeeper PRD** (the combat clock). Fixed-step clock owned by the Combat manager: stepped `sim_time` + continuous `render_time` (the wall) + the one speed dial + the step cadence (`steps_due`: real time × dial → whole steps, capped + backlog dropped). It does NOT hold or advance components — the Combat manager does. Fixed step → deterministic + reproducible autotest. | timekeeper, clock, fixed timestep, sim_time, render_time, timescale, dial, slow-mo, pause, steps_due, determinism, cadence, physics_process |
| [project/actor_prd.md](project/actor_prd.md) | **Actor PRD** (foundation). The symmetric combatant — HP (current/max), a board of items, an actor-targeted status list; a passive holder others act on. Player and enemy are the same type; side / ordering / targeting live in the Combat manager. | actor, HP, board, status list, symmetric, player, enemy, take_damage, heal, died, block, combatant |
| [project/status_manager_prd.md](project/status_manager_prd.md) | **StatusManager PRD** (foundation). The stateless status rulebook — (target, count/stacks, behaviour) keyed by type; instances live on targets, advanced each step by the Combat manager (on the Timekeeper clock). apply() + the incoming-damage pipeline (block); status shapes; stat-statuses deferred. | status, statusmanager, poison, burn, block, regen, freeze, buff, debuff, stacks, apply, incoming damage, absorb, vulnerable, dual targeting |
| [project/item_prd.md](project/item_prd.md) | **Item PRD** (content). The board participant — data-defined, owns a Ticker; every item is active (ticks); triggers add event-push input on the same accumulator (no separate trigger type), and passive effects are statuses, not an item type. Fire pipeline (gate → fire → resolve with status/enchant modifiers → declare target-shape for the Combat manager). Rarity = complexity not power; size = tempo; one enchant slot; duplicates stack. | item, board, Ticker, active, trigger, passive, weapon, armor, heal, damage-shape, AOE, single-target, rarity, enchant, duplicate, fire, payload, target-shape, synergy |
| [project/combat_manager_prd.md](project/combat_manager_prd.md) | **Combat Manager PRD** (orchestrator). The per-fight orchestrator — instanced by Encounter; owns the live context (actor pair + ordering, Deliveries), the Timekeeper lifecycle, the central tick (advance→fire→land→events→win/loss, one link per tick), target-shape resolution, the trigger event bus, and player input-intents. | combat manager, orchestrator, central tick, win/loss, targeting authority, event bus, trigger, Delivery, target-shape, per-fight, registration, loop-proof |
| [project/game_manager_prd.md](project/game_manager_prd.md) | **Game Manager PRD** (session singleton). Autoload `Game` — the game-state machine (title → run → death → meta), the run lifecycle (create/resume/end the `Run manager`), and the save-lifecycle calls (`read`/`clear` + meta-save). Holds session state + a reference to the live run, never per-run state. | game manager, session, autoload, game-state machine, run lifecycle, save lifecycle, state machine, title, death screen, top of tree |
| [project/run_manager_prd.md](project/run_manager_prd.md) | **Run Manager PRD** (the descent). Instanced per run by the `Game manager` — owns the map (act/beat placement + 1D progress track), encounter sequencing + corridor advance, the player run-state (Actor + relics + potions + position + RNG), and HP-economy policy. Writes the per-encounter snapshot; rehydrates on resume. | run manager, map, encounters, run-state, descent, HP economy, corridor advance, snapshot, rehydrate, acts, beats |
| [project/encounter_prd.md](project/encounter_prd.md) | **Encounter PRD** (run-structure). The per-beat orchestrator — one resolved beat (fight / event / in-act rest), instanced per beat by the `Run manager`; a fight Encounter spawns enemies in left-to-right order + creates the `Combat manager`. The choice-layer candidates are drawn by the `Run manager`; the Encounter resolves the picked beat and reports outcome + reward up. | encounter, beat, fight, event, rest, choice layer, telegraph, elite, boss, composition, ordering, reward, two-tier choice |
| [project/draft_prd.md](project/draft_prd.md) | **Draft PRD** (run-structure). The 1-of-3 reward draw — a stateless service (`Draft`) producing 3 Draftable candidates (slot composition: usually item, low chance enchant/potion; depth-weighting; seeded by the run RNG). The `Run manager` holds the offer + applies the pick (board/potion/enchant/relic). No skip; weighting is depth-only (no hidden archetype weighting). | draft, reward, 1-of-3, pool, weighting, depth, rarity, no skip, enchant, potion, seeded, RNG, save-scum, Draftable |
| [project/enemy_prd.md](project/enemy_prd.md) | **Enemy PRD** (content). Not a class — an Actor built from an authored enemy definition (HP + authored board of enemy-pool Items + tier + boss signature), spawned by Encounter. Enemy items = a content category (per-enemy attack + shared utility pool), not a mechanism. Tiers = authoring conventions. Summons needs mid-fight roster changes (deferred). | enemy, authored board, enemy items, attack item, tier, regular, elite, boss, signature, summons, composition, variety, symmetric actor |
| [project/content_prd.md](project/content_prd.md) | **Content PRD** (relics · enchants · consumables). The three thin content categories beyond Item — a `Relic` (persistent run-state modifier: combat-start status / triggered Ticker / direct mod), an `Enchantment` (one-per-item modifier hooking the host item's fire/resolve), a `Consumable` (manually-fired reserve — a Delivery on throw, no Ticker). All lean on StatusManager / Combat manager / Item; held in run-state, saved. | content, relic, enchantment, consumable, potion, draftable, run-state, modifier, enchant, throw, persistent |
| [project/save_prd.md](project/save_prd.md) | **Save PRD** (foundation). Run-persistence service — persists a handed snapshot on encounter entry, returns it on load; push not pull (resolves the layering inversion). Saves run-persistent state only (HP, board+enchants, relics, potions, position, RNG); combat is ephemeral. No migration. | save, persistence, snapshot, encounter entry, resume, run state, push, RNG, no migration, autosave, run slot |
| [project/ui_layout_prd.md](project/ui_layout_prd.md) | **UI / Layout PRD** (presentation + input). Screen composition (corridor/combat scene, item boards zoned by effect family with colour panels + cooldown rings, portrait/HP, potions, the choice/draft/1D-map screens) and the input layer that emits intents (never mutates state). Framed-vs-full-screen is the central open mockup question; the next encounter approaches from depth into the corridor view. | ui, layout, hud, boards, colour panel, cooldown ring, slow-mo, hover, intents, choice layer, draft, progress map, portrait, framed, full-screen, approach |
| [project/vfx_driver_prd.md](project/vfx_driver_prd.md) | **VFX Driver PRD** (the combat wall). Renders combat visuals as a pure function of handed state + render_time — projectiles (f(render_time − fire_time)), impacts (f(render_time − impact_time)), fire-emotes, damage numbers, screen pulse, SFX one-shots; writes no game state. The projectile doesn't cause the damage; the Delivery's landing does. | vfx, wall, projectile, impact, render_time, fire-emote, damage numbers, screen shake, sfx, stateless, pure function, cascade, output layer |
| [testing/autotest.md](testing/autotest.md) | **AutoTest Mode** (dev harness — **Phase 3 built: drives a full run**). Headless auto-play for deterministic regression + balance testing; the driver is just another input-intent source, determinism is the seeded run RNG. Built: the Mode/Driver/Logger trio in `src/autotest/` (`autotest.tscn`) drives a whole descent (Game → Run → Encounter → Combat) — `run_full` (default) or `run_once` (`--single-fight`) — with draft picks, `--encounters`, stuck/timeout guards, damage-by-family, a markdown report, and exit codes. Real draft strategies + `tune` skill later. | autotest, e2e, headless, deterministic, seed, speed, driver, regression, balance, tune, stuck detection, intent, CI, exit code, damage-by-family, run loop, resume |
| [project/combat_prd.md](project/combat_prd.md) | **Combat PRD.** Effect resolution: the `Ticker` accrual primitive, accrual-only triggers (the Bazaar lesson), fire/Delivery split, travel_time, targeting/fizzle. | combat, Ticker, accrual, trigger, charges, fire, Delivery, travel_time, projectile, cooldown, fizzle |
| [project/art_audio.md](project/art_audio.md) | **Art Direction & Audio** (vibes doc). Rendering/corridor look, dark-fantasy tone, pixel-art resolution debate, VFX, cascade readability, inventory presentation, UI layout, dungeon-synth audio. | art, audio, pixel art, palette, VFX, cascade, readability, dungeon synth, lighting, tone, dread, UI layout, projectiles |

## Corridors (first-person renderer)

The game renders a first-person "dark corridor" from 2D pixel-art using a
fixed-perspective (pseudo-3D / 2.5D) approach — no `Camera3D`, no meshes. A thin
host scene (`corridor_testbed.tscn` / `corridor_testbed.gd`) instances one of two interchangeable
renderers and toggles between them at runtime with the **M key** / Mode button.
Both renderers extend a shared `CorridorRenderer` base, so they expose the same
interface and the host wiring is identical for either.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [corridors/common.md](corridors/common.md) | Shared setup & base class: project.godot config, pixel-art pipeline, `CorridorRenderer` base (movement, velocity ramp, blur/filter model), `sharp_bilinear.gdshader`, the host (`corridor_testbed.gd`) that instances/toggles renderers, how to run + screenshot. | base class, CorridorRenderer, view_size, aspect ratio, drop-in, project settings, stretch, nearest, sharp bilinear, aa_strength, blur slider, velocity ramp, input map, host, toggle, run, --shot |
| [corridors/scale-and-place.md](corridors/scale-and-place.md) | **`CorridorScaled`** (default; `CorridorScaledScene.tscn`). Rigid scaled tiles in a geometric series; four rotated sides = full box; per-side textures; `view_size` (any aspect, corners auto-meet) + `depth_ratio`. | scale and place, rigid tiles, geometric series, view_size, aspect ratio, depth_ratio, box, four sides, per-side textures, Underkeep, default |
| [corridors/perspective-quad.md](corridors/perspective-quad.md) | **`CorridorPerspective`** (toggle; `CorridorPerspectiveScene.tscn`). Walls as textured `Polygon2D` trapezoids; per-cell depth quads subdivided into strips to kill affine swim. | perspective quad, Polygon2D, trapezoid, affine, swim, subdivision, proj_x, proj_y, vanishing point, flat texture, toggle |

### Quick "which renderer?" guide
- **Default — `CorridorScaled`**: rigid (no swim), four-side box (walls+floor+ceiling),
  **per-side textures**, easy tile-size experimentation. Build the game on this.
- **Toggle — `CorridorPerspective`**: fully parametric perspective (tune FOV
  freely) with any flat wall texture; side walls only (floor/ceiling = backdrop).

(A third "nested-frames" prototype was removed — `CorridorScaled` does the same
more flexibly via per-side textures.)

### Class / file map
Renderers live in `src/scenes/corridors/`, the host in `src/scenes/`, the shader
in `src/shaders/` (class names stay PascalCase; files are snake_case).
- `corridor_renderer.gd` — base `CorridorRenderer` (shared movement/filter/interface)
- `corridor_scaled.gd` + `corridor_scaled.tscn` — default renderer (`CorridorScaled`)
- `corridor_perspective.gd` + `corridor_perspective.tscn` — toggle renderer (`CorridorPerspective`)
- `corridor_testbed.gd` + `corridor_testbed.tscn` — host/testbed: UI + instances/toggles the renderers
- `corridor_panel.tscn` — drop-in: SubViewportContainer that auto-sizes + clips a renderer
- `corridor_panel_example.gd` + `corridor_panel_example.tscn` — worked example: `corridor_panel.tscn` in a themed frame, driven by themed Buttons (+ `UIJuice`) through the renderer interface
- `src/shaders/sharp_bilinear.gdshader` — antialiased-nearest canvas shader

### Assets
- `assets/sprites/test_wall.png` (52×192) — the only bundled texture: default
  side-wall tile for `CorridorScaled` (all four sides), and a placeholder for
  `CorridorPerspective`'s wall + backdrop (its original Eye of the Beholder art
  was removed).

## UI & feel (`docs/ui/`)

Built UI systems: the theme, the audio managers, and the drop-in juice node that
gives interactive controls life.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [ui/audio.md](ui/audio.md) | **Audio.** Two autoloads + bus layout: `SfxManager` (polyphonic one-shot SFX, per-key cooldown, pitch jitter, generic `play()` + shared UI hover/click/press bank, no-op when streams missing) and `MusicManager` (shuffle + crossfade from `assets/music/`, web autoplay gating). Trimmed port of a-machine's audio. | audio, sound, sfx, music, SfxManager, MusicManager, autoload, bus, Effects, Music, polyphonic, cooldown, pitch jitter, crossfade, shuffle, one-shot |
| [ui/ui-juice.md](ui/ui-juice.md) | **UI Juice.** `UIJuice` drop-in node: attach as a child of any Control for a centred hover bounce + press squash + hover/click sounds. Presets (BUTTON/CARD/ICON) + per-value overrides; recipe from a-machine's `HoverButton`. | juice, UIJuice, hover, press, bounce, squash, tween, pivot, preset, overshoot, settle, drop-in, button feel, interactive |

The Black & White UI theme (`assets/themes/black_white_ui.tres`, the project
default) is not yet documented here.

Files: `src/autoloads/sfx_manager.gd`, `src/autoloads/music_manager.gd`,
`default_bus_layout.tres`, `src/ui/ui_juice.gd`.
