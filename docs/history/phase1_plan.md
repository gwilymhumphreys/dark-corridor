# Dark Corridor — Phase 1 Build Plan (the combat spine)

> **A build plan, not a spec.** The systems are specced in their PRDs; this is the ordered, test-first path to building the first runnable slice. Sits under [decision_log.md](../decision_log.md) → *Build order* (step 2.1) and the [architecture scene tree](../systems/architecture.md#scene-tree--node-model).

**Engine:** Godot 4.6.
**Date:** 2026-06-05.

---

## Goal

One player `Actor` vs one authored enemy — a deterministic fixed-step fight (advance → fire → land → events → win/loss) with a minimal VFX wall + stub UI so the fight is **watchable**. No `Game` / `Run` / `Encounter` yet; a throwaway `combat_sandbox` host creates the fight directly (the run loop is Phase 3).

## Why this shape

It's the spine every other system hangs off, and it ends on the design's explicit **go/no-go gate** — *does one item firing punch through the dark and feel good, and does a small cascade satisfy?* ([art_audio.md](../design/art_audio.md) atomic test; [design.md](../design/game_design.md) open Q3). If yes → Phase 2. If no, the design says combat needs input or items need richer interaction **before** scaling — so we stop and re-evaluate, not push on.

## Discipline

Logic is pure `RefCounted`, driven by `sim_step()` called directly in GUT — no `_physics_process`, no presentation. That's identical to how the autotest harness (Phase 2) will drive it, so Phase 1's tests *are* the autotest seam in miniature. **Each step's GUT tests go green headless before the next starts.** Run them with:

```
…console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

---

## Build order

### Step 1 — Clock + primitives (pure logic)

- **Build:** `Ticker` (accumulator, threshold-in-steps, accrual source, push), `Delivery` (payload + resolved target + travel-Ticker), `EventBus` (subscribe / publish, next-step delivery), `Timekeeper` (STEP, `timescale` base+override, `steps_due()` accumulator + `MAX_STEPS` cap + backlog-drop, `sim_time`, `render_time()`).
- **Files:** `src/combat/ticker.gd`, `delivery.gd`, `event_bus.gd`, `timekeeper.gd`.
- **Tests:** `tests/combat/test_timekeeper.gd`, `test_ticker.gd` — `steps_due` cadence at dial ×0 / ×0.05 / ×1 / ×5; backlog-drop on a simulated hang; K `advance()`s ⇒ exact `sim_time`; a Ticker crosses at `ceil(cooldown / STEP)`; a push adds to the accumulator.
- **Done when:** clock + Ticker are deterministic and the cadence matches `Balance`.

### Step 2 — Actor + StatusManager

- **Build:** `Actor` (HP cur/max, `take_damage` / `heal`, `died`, ordered `board`, actor-status list). `StatusManager` autoload (stateless): instance model + behaviour-by-type for the three shapes — **block** (pool / absorber, no decay), **poison** (periodic DoT → fires a travel-0 Delivery), **one timed debuff** (counts down → `on_expire`); `apply()`, `resolve_incoming_damage()`, `info(type) → {icon, colour, name}`.
- **Files:** `src/combat/actor.gd`, `src/content/status_def.gd` + `status_catalog.gd`, `src/autoloads/status_manager.gd` (register autoload `StatusManager`).
- **Tests:** `test_actor.gd`, `test_status_manager.gd` — block absorbs before HP, `unblockable` skips it; poison ticks N times then gone; timed status expires on schedule; `take_damage` to 0 emits `died` once; `apply` returns the instance for registration + emits on-apply.
- **Done when:** damage-through-block and a poison DoT both resolve deterministically with no Combat manager yet (drive statuses by stepping their Tickers in-test).

### Step 3 — Item + fire pipeline

- **Build:** one `Item` class configured by `ItemDef`; tiny catalog — **weapon** (opponent-leftmost damage, `travel > 0`), **armor** (self block, travel 0), **poison-applier** (opponent-leftmost, applies poison), **trigger item** (ticks normally *and* "on poison applied → push"). Fire pipeline: gate → fire (reset + emote event) → resolve payload(s) with status / enchant modifiers → hand `(payload, shape, travel)` up.
- **Files:** `src/combat/item.gd`, `src/content/item_def.gd` + `item_catalog.gd`, `enemy_def.gd` + `enemy_catalog.gd` (one enemy: HP + one attack item).
- **Tests:** `test_item.gd` — weapon produces the right payload + shape on cross; armor self-targets; poison-applier calls `StatusManager.apply`; a gated (silenced) item suppresses fire; duplicates tick independently.
- **Done when:** an item, stepped in isolation, fires on cadence and hands up correct payloads.

### Step 4 — Combat manager (the fight)

- **Build:** the central `sim_step()` (advance every registered component by `seq_id` → fire crossed → spawn / land Deliveries → route events → win/loss); pull-based registry with a monotonic `seq_id`; target-shape resolution (self, opponent-leftmost; AOE path stubbed for one enemy); Delivery travel + **fizzle on mid-flight death**; `EventBus` wired with the one trigger; `Timekeeper` lifecycle; `request_timescale` intent; `resolved(winner)` signal. `_physics_process` calls `steps_due` × `sim_step` (real run); tests call `sim_step` directly.
- **Files:** `src/combat/combat_manager.gd`.
- **Tests:** `test_combat_manager.gd` — full headless fight reaches a deterministic win/loss; **same seed ⇒ identical step-by-step trace** (the reproducibility proof); a trigger push fires on the *next* step (one link / step); a Delivery fizzles if its target dies mid-flight; simultaneous death → loss.
- **Done when:** "K sim-steps, bit-reproducible" holds end-to-end for a real fight.

### Step 5 — The wall + sandbox (watch it)

- **Build:** minimal `VfxDriver` (one projectile `f(render_time − fire_time)`, fire-emote, travelling damage number, screen pulse — all read-only off the Delivery set), a minimal board view (HP + per-item cooldown ring), and `combat_sandbox.tscn` host that builds one fight and runs it through a real `CombatManager`. Slow-mo-on-hover wired as a `request_timescale` intent (use **replace** for the override now — base → slowmo → base; replace-vs-multiply stays flagged in [combat_model.md](../systems/combat_model.md)).
- **Files:** `src/vfx/vfx_driver.gd` (+ leaf nodes), `src/scenes/combat/board_view.gd`, `src/scenes/combat_sandbox.tscn` / `.gd`.
- **Done when:** you run the sandbox, watch the weapon fire → projectile → impact → number → HP drop with the item recoiling, hover to slow-mo — and judge the **feel gate**.

---

## Interfaces to lock at the start (so steps don't drift)

```
Timekeeper:  steps_due(real_delta:float)->int · advance()->void · sim_time:float ·
             render_time()->float · set_timescale(base, override)
Actor:       take_damage(amount:float, flags:int)->void · heal(amount:float) ·
             is_alive()->bool · signal died · board:Array · statuses:Array
StatusManager: apply(target, type, count, source)->Status ·
             resolve_incoming_damage(target, raw, flags)->float · info(type)->Dictionary
Item:        owns Ticker · fire()->Array[payload] · trigger_subs:Array · shape per effect
CombatManager: sim_step() · register(component)->int(seq_id) · request_timescale(...) ·
             signal resolved(winner)
```

## Phase-1 micro-decisions (pre-flagged)

- Ticker threshold = `ceil(cooldown_seconds / Balance.STEP)`.
- Hover override = **replace** (simplest); `combat_model.md`'s replace-vs-multiply stays open.
- Simultaneous death → loss; `seq_id` ascending order; trigger push next-step — per the decision log (#24, #12).
- `combat_sandbox` is throwaway scaffolding (like `corridor_testbed`), not `main.tscn`.

## Explicitly NOT in Phase 1

Multi-enemy composition; potions / relics / enchants; the full event catalog; the ~100-item pool; stat-statuses; the run loop (`Game` / `Run` / `Encounter` / `Save` / `Draft`); real UI / theme; the palette / pixel pipeline. All later phases.

## The gate (end of Phase 1)

Run the sandbox and judge: **does one item firing feel good against black, and does a small cascade satisfy?**

- **Yes** → proceed to Phase 2 (autotest scaffolding), then Phase 3 (the run loop).
- **No** → stop. The design's contingency is combat input or richer item interaction; resolve that before scaling content.
