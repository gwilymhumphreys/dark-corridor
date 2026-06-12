# Dark Corridor — Timekeeper PRD (the combat clock)

Foundation PRD. Sits under the [Architecture Map](architecture.md); the [Combat PRD](combat_model.md) assumes the clock specified here. The `Timekeeper` is the **combat clock**: the time source, the one speed dial, and the fixed-step cadence. It is **instanced per fight**, created and owned by the `Combat manager`. It does **not** hold the component registry, advance components, run a loop, orchestrate, target, or hold game state — the `Combat manager` does all of that, *on* this clock.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.
**Naming:** `class_name Timekeeper`, instanced (not an autoload), owned by the `Combat manager`. (It's now a slim clock; `Clock` is the literal alternative — kept as `Timekeeper`.)

Boundaries live in the hub: [architecture.md → Interface contracts → `Timekeeper`](architecture.md#interface-contracts-boundary-hub).

---

## Purpose

The single source of **combat time and speed**. Combat runs on a **fixed timestep**: a fixed `STEP` of game-time per *sim-step*. The Timekeeper owns:

- **`sim_time`** — the stepped clock (advances by `STEP` per sim-step); what *logic* reads.
- **`render_time()`** — a *continuous* clock for the VFX/audio "wall"; smooth between steps.
- **`timescale`** — the one speed dial.
- the **accumulator** + **`steps_due()`** — turns real elapsed time × the dial into a whole number of fixed steps.

It is **combat-scoped** (fresh per fight, `sim_time` from 0) and a **passive clock the `Combat manager` drives** — it doesn't loop or advance components itself.

## Why a fixed timestep

- **Determinism** — variable delta is frame-rate-dependent and non-reproducible. Fixed steps make the sim reproducible from a seed regardless of FPS → the deterministic-cascade goal, **bit-reproducible autotest**, and replay all fall out. *(Resolves the determinism open.)*
- **No high-speed artifact** — speed is *how many steps run*, not a scaled delta, so game-time is identical at any speed (no precision loss / tunnelling).
- **Simpler components** — a Ticker counts steps (`count += 1; if count >= threshold`); no per-component float-time math.

## The dial

One `timescale`, set via input-intent (the `Combat manager` sets it from a UI intent — UI never writes it directly):

| Use | `timescale` |
|-----|--------|
| Pause | ×0 |
| Hover slow-mo (inspect) | ~×0.05 |
| Player battle-speed | ×1 / ×2 / ×3 |
| Fast-test / dev | ×5+ |

**Base vs. momentary override:** a base speed (the battle-speed setting) and a momentary override (hover slow-mo) that returns *to the base*, not ×1. Slow-mo slows both sides proportionally (can't dodge by inspecting). **Resolved — replace:** the override is an absolute, consistently-readable slow-mo regardless of the player's battle-speed dial (the base ×1/×2/×3 only sets what it returns to). The dial lives on `Game` (a session preference); the run screen applies it to each fight's Timekeeper base scale.

## `steps_due()` — real time → fixed steps

Each physics frame the `Combat manager` hands the Timekeeper the (fixed) real delta; the Timekeeper resolves it into a step count — **delta is resolved here and nowhere else**:

```
steps_due(real_delta):
  acc += real_delta * timescale
  n = 0
  while acc >= STEP and n < MAX_STEPS:   # MAX_STEPS = live ceiling
    acc -= STEP; n += 1
  if acc > STEP: acc = 0                  # drop backlog: game-time slips, never spirals
  return n
```

So the dial becomes a **cadence**: pause → 0 steps; slow-mo → a step every ~N frames; ×1 → one per physics tick; fast-test → many. A frame hang runs up to `MAX_STEPS`, then drops the rest — the game briefly *slows*; it never stutter-jumps or spirals. `advance()` advances `sim_time` by one `STEP` (the `Combat manager` calls it once per sim-step, then advances the components — see the Combat manager PRD).

## Two reads: `sim_time` (stepped) vs `render_time()` (continuous)

- **`sim_time`** — stepped; logic and event timestamps (fire / impact) read it; deterministic.
- **`render_time()`** — continuous: `sim_time + acc` (the sub-step accumulator). The VFX/audio wall reads it, so motion is smooth *between* sim-steps (slow-mo glides at 1/20 speed rather than stuttering at 3 fps), and it **freezes the instant the sim stops** (resolved / paused). *(A `physics_interpolation_fraction × STEP × timescale` term was dropped: it keeps cycling while the sim is frozen, oscillating paused projectiles.)* Only discrete events snap to steps.

## The wall (sync source)

Renderer / VFX / audio hold no clock — they read `render_time()`. Projectile / impact positions are pure functions of a stored timestamp (`render_time() − fire_time`, `… − impact_time`); audio triggers one-shot at the sim timestamp and plays at wall-clock pitch. (Detail: architecture "Visuals and time" + the future VFX PRD.)

## What it does NOT do

Hold the component registry or advance components (the `Combat manager` owns the registry and advances each component one step in its `sim_step`); run a loop / `_physics_process` (the `Combat manager`); orchestrate, resolve targets, or hold the game-state machine.

## Lifecycle

Created by the `Combat manager` at combat start (`sim_time` 0); the manager calls `steps_due` / `advance` each tick and sets `timescale` from intents; torn down at combat end. Owns no state outliving one fight.

## Prototype scope

`STEP` + `timescale` + `steps_due` (accumulator, cap, backlog-drop) + `sim_time` / `render_time`; the `Combat manager` (or a stand-in) drives it. One base speed + a hover slow-mo override. Headless: the manager calls `advance` directly in a loop (no real delta).

## Open / deferred

- **`STEP` and `MAX_STEPS` values** — tuning (`STEP` likely = the physics period, so ×1 = one step per physics tick).
- **Resolved:** fixed timestep (was the timestep/determinism open); slim-to-clock (the registry + advance moved to the `Combat manager`); instanced-per-fight; **override replace-vs-multiply → replace** (absolute slow-mo; see *Base vs. momentary override*).

## Dependencies

- **Above:** nothing — a passive clock.
- **Driven by:** the `Combat manager` (per fight) — `steps_due` / `advance`, sets `timescale`, owns the registry it advances.
- **Read by:** logic (`sim_time`); the VFX/audio wall (`render_time()`).
