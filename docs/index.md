# Docs index

Catalog of project documentation. Agents: scan this first to find the relevant
doc before diving into code. Each entry lists the path, what it covers, and
keywords to match against.

## Project design & PRDs (`docs/project/`)

> **Picking up the work?** Read [project/decision-log.md](project/decision-log.md) first — the decisions made, their rationale, the open items, and the next steps.

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
| [project/architecture.md](project/architecture.md) | **Architecture map + boundary hub.** System map (downward deps, input/output boundary), the settled combat spine, prototype scope, and the **Interface contracts** every PRD links to for its edges. | architecture, system map, autoload, Timekeeper, combat manager, StatusManager, Actor, Save, tick, timescale, dependencies, boundary hub, interface contract |
| [project/timekeeper_prd.md](project/timekeeper_prd.md) | **Timekeeper PRD** (the combat clock). Fixed-step clock owned by the Combat manager: stepped `sim_time` + continuous `render_time` (the wall) + the one speed dial + the step cadence (`steps_due`: real time × dial → whole steps, capped + backlog dropped). It does NOT hold or advance components — the Combat manager does. Fixed step → deterministic + reproducible autotest. | timekeeper, clock, fixed timestep, sim_time, render_time, timescale, dial, slow-mo, pause, steps_due, determinism, cadence, physics_process |
| [project/actor_prd.md](project/actor_prd.md) | **Actor PRD** (foundation). The symmetric combatant — HP (current/max), a board of items, an actor-targeted status list; a passive holder others act on. Player and enemy are the same type; side / ordering / targeting live in the Combat manager. | actor, HP, board, status list, symmetric, player, enemy, take_damage, heal, died, block, combatant |
| [project/status_manager_prd.md](project/status_manager_prd.md) | **StatusManager PRD** (foundation). The stateless status rulebook — (target, count/stacks, behaviour) keyed by type; instances live on targets, advanced each step by the Combat manager (on the Timekeeper clock). apply() + the incoming-damage pipeline (block); status shapes; stat-statuses deferred. | status, statusmanager, poison, burn, block, regen, freeze, buff, debuff, stacks, apply, incoming damage, absorb, vulnerable, dual targeting |
| [project/item_prd.md](project/item_prd.md) | **Item PRD** (content). The board participant — data-defined, owns a Ticker; every item is active (ticks); triggers add event-push input on the same accumulator (no separate trigger type), and passive effects are statuses, not an item type. Fire pipeline (gate → fire → resolve with status/enchant modifiers → declare target-shape for the Combat manager). Rarity = complexity not power; size = tempo; one enchant slot; duplicates stack. | item, board, Ticker, active, trigger, passive, weapon, armor, heal, damage-shape, AOE, single-target, rarity, enchant, duplicate, fire, payload, target-shape, synergy |
| [project/combat_manager_prd.md](project/combat_manager_prd.md) | **Combat Manager PRD** (orchestrator). The per-fight orchestrator — instanced by Encounter; owns the live context (actor pair + ordering, Deliveries), the Timekeeper lifecycle, the central tick (advance→fire→land→events→win/loss, one link per tick), target-shape resolution, the trigger event bus, and player input-intents. | combat manager, orchestrator, central tick, win/loss, targeting authority, event bus, trigger, Delivery, target-shape, per-fight, registration, loop-proof |
| [project/enemy_prd.md](project/enemy_prd.md) | **Enemy PRD** (content). Not a class — an Actor built from an authored enemy definition (HP + authored board of enemy-pool Items + tier + boss signature), spawned by Encounter. Enemy items = a content category (per-enemy attack + shared utility pool), not a mechanism. Tiers = authoring conventions. Summons needs mid-fight roster changes (deferred). | enemy, authored board, enemy items, attack item, tier, regular, elite, boss, signature, summons, composition, variety, symmetric actor |
| [project/save_prd.md](project/save_prd.md) | **Save PRD** (foundation). Run-persistence service — persists a handed snapshot on encounter entry, returns it on load; push not pull (resolves the layering inversion). Saves run-persistent state only (HP, board+enchants, relics, potions, position, RNG); combat is ephemeral. No migration. | save, persistence, snapshot, encounter entry, resume, run state, push, RNG, no migration, autosave, run slot |
| [testing/autotest.md](testing/autotest.md) | **AutoTest Mode** (dev harness — design/scaffolding, pre-build). Headless auto-play (draft → fight → advance) for deterministic regression + balance testing; the driver is just another input-intent source, `--speed` is the Timekeeper dial, determinism is seeded RNG. Scaffolding now (Mode/Driver/Logger + flags + stuck detection); decision AI + `tune` skill later. | autotest, e2e, headless, deterministic, seed, speed, driver, regression, balance, tune, stuck detection, intent, CI |
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
- `src/shaders/sharp_bilinear.gdshader` — antialiased-nearest canvas shader

### Assets
- `assets/sprites/test_wall.png` (52×192) — the only bundled texture: default
  side-wall tile for `CorridorScaled` (all four sides), and a placeholder for
  `CorridorPerspective`'s wall + backdrop (its original Eye of the Beholder art
  was removed).
