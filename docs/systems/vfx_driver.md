# Dark Corridor — VFX Driver PRD

Presentation PRD (output layer). Sits under the [Architecture Map](architecture.md). The `VFX driver` is **the wall** — it renders combat visuals as a **pure function of handed state + the clock**, and **writes no game state**. It computes where every projectile / impact / number is from the [Combat manager](combat_manager.md)'s Delivery set and the [Timekeeper](timekeeper.md)'s `render_time()`; the renderer paints what it computes.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** a driver + leaf render nodes — *not* a manager (it holds no game state); concrete node split is impl (deferred).

Boundaries live in the hub: [architecture.md → Interface contracts → `VFX driver`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals* of the wall the architecture's "Visuals and time" section sketches.

---

## Purpose

The combat cascade's spectacle is the game's payoff (design); the `VFX driver` is how it reaches the screen — **without** ever deciding what happens. It reads the live fight (actors, items, statuses, the in-flight Deliveries) + the clock, and produces visuals; combat already decided *what* and *when*.

The boundary that defines it (architecture): **output → logic is one-way.** Every position / frame the driver produces is computed from data; it tracks no animation state and holds no clock of its own. Its only read-up is `render_time()`.

What it **is not**:

- **Not game logic.** The projectile arriving does **not** cause the damage — the Delivery's landing (the `Combat manager`, on the sim tick) is the damage event; the projectile is just the pretty thing in flight while that resolves. Wiring the visual to *cause* the effect is the breach to avoid.
- **Not a second clock.** It never tracks animation progress; every visual is `f(render_time − stored_timestamp)`. (The breach: the renderer stepping its own animation state.)
- **Not the UI / input** (a separate inbound layer — [UI PRD](ui_layout.md)) or the corridor renderer (the existing `docs/systems/corridors/` scaling-tile renderer; the `VFX driver` is the *combat* wall over it).

---

## The wall (how visuals sync to the sim)

Combat decides *what happens and when*; the driver decides *where the pretty thing is while that resolves*. They sync by reading the same clock, not by one triggering the other:

- **Projectiles** — position is a pure function of `render_time() − fire_time` (the Delivery's fire timestamp). Continuous → smooth at any speed; slow-mo *glides* (the dial slows `render_time` with everything else). A coloured projectile per activation, colour by effect family (art doc).
- **Impact visuals** (flash / particle on landing) — `f(render_time() − impact_time)` (the Delivery's stored impact timestamp). Same stateless pattern; honours the clock (the flash slows with the bind).
- **Fire-emotes** — when an item fires it recoils / flashes / punches: the *source* half of the causal bind (art doc — silent-source + damage-on-enemy reads as a weak connection). The driver plays the item's fire-reaction; the same-coloured impact lands simultaneously so the eye binds them.
- **Damage numbers** — a travelling / popup number, a pure function of time; for precision under hover (the gestalt is carried by flinch + flash + thud, not the numbers — art doc).
- **Screen pulse / shake** on big hits — `f(time)` off the same timestamps.
- **SFX one-shots** — triggered at `impact_time` (the sim clock), then **played at wall-clock pitch** (unslowed — slowing audio sounds bad). Same stored timestamp as the flash, read two ways: a continuous function (visual) and a fire-and-forget event (sound). *(What the SFX sound like is `art_audio.md`, not here.)*

Because fire-rate and travel are decoupled (combat_model.md), many Deliveries can be in flight at once; the driver renders each independently from its own timestamps — chaos at full speed reads as "the machine went off," and under slow-mo-hover a single inspected chain resolves cleanly (art doc).

## Reading the Combat manager's Delivery set

The `Combat manager` keeps a resolved Delivery until its visual's max duration elapses (so the driver can read `render_time − impact_time` *after* the damage has landed), then drops it. The driver reads that set each frame + `render_time()`; it never mutates it.

---

## Prototype scope

Per the architecture's "full VFX *path*, minimal *content*" — build the driver + the wall and prove them on a few effects:

- one **projectile** type (position from `render_time − fire_time`),
- one **fire-emote** (item recoil / flash),
- **travelling damage numbers** — including DoT ticks, which carry no landing Delivery of their own, so the Combat manager hands the wall a **visual-only** Delivery (pre-landed, payload-less) per tick to pop the number,
- a **screen pulse**.

This validates the cleanest boundary on the map at the cheapest moment.

**Not** in scope: the palette-clamp shader, pixel-snapped particles, banded light falloff, per-effect-family particle variety, the 32–64 palette pipeline — content/polish on a driver that already works (`art_audio.md`).

---

## Open / deferred

- **VFX content + the pixel pipeline** (palette clamp, pixel-snap, banded falloff, per-effect particles) — `art_audio.md` + a content pass.
- **Projectile density tuning** (small/fast tracers for commons vs. crisp arcs for rares) — art doc, when the cascade is real.
- **The node split** (driver vs. leaf render nodes; all-2D vs. SubViewport) — impl, settled when the UI-layout approach is picked (`art_audio.md` UI-implementation note).

## Dependencies

- **Reads:** the `Combat manager`'s in-flight Delivery set (fire / impact timestamps, payload colour) + actor / item / status state; the `Timekeeper`'s `render_time()`. **Writes no game state.**
- **Does not:** decide outcomes or timing (`Combat manager` / `combat_model.md`); hold a clock (`Timekeeper`); advance combat; capture input (`UI`); render the corridor (the `docs/systems/corridors/` renderer).
