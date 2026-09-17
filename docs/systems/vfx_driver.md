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
- **Not the UI / input** (a separate inbound layer — [UI PRD](ui_layout.md)) or the corridor ([`Corridor3D`](corridors/corridor_3d.md); the `VFX driver` draws over it, outside the corridor look shader).

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

## What is built

`VfxDriver` (`src/vfx/vfx_driver.gd`) draws a solid projectile in flight, a ring that snaps outward
where it lands, and a number for damage and healing, each in the delivery's colour. The number
(`DamageNumberDrawer`) has a black outline. Its size grows with the amount on a logarithmic curve,
from a fixed base size to a maximum, so it rises quickly for small amounts and slowly for large
ones. It floats up while drifting toward the side its landing point was nudged to, then quickly
grows and shrinks away. Heals show a '+' in front. The landed delivery is kept for
`Balance.DELIVERY_VISUAL_HOLD`, which must be at least the number's duration.

**Big hits.** A damage landing of at least `VfxDriver.BIG_HIT_DAMAGE` emits `big_hit` with a
strength from 0 to 1 (`big_hit_strength`), once, alongside its sound. `CombatViewFramed` answers
with a short pause of the fight (`CombatManager.request_hit_pause`, which calls `Timekeeper.hold`)
and a shake of the whole view, both growing with the strength. The pause only delays steps, so
results are unchanged, and the autotest has no view, so it never pauses. The shake is a tween of
the view's `offset_transform_position` on real time, so it plays through the pause. The firing item's own
reaction is not the driver's: `item_cell.gd` punches the cell's scale off the same clock. A hit
enemy also flinches back in the corridor and is lit ([run_screen.md](run_screen.md#enemies-in-the-corridor)).

Each shape is its own class under `src/vfx/drawers/`, extending `EffectDrawer`: `duration()`,
`progress(age)` and `draw_effect(canvas, delivery, point, age)`. A drawer holds no state, so slow
motion and pause keep working. The driver keeps a dictionary from a mechanic id (for a `MECHANIC` delivery) or
`Delivery.Kind.APPLY_STATUS` to the drawer, so a new effect is a new file rather than another branch in
`_draw()`. The seven built [mechanics](mechanics.md) (crit is a string literal until its class
exists) and status application currently share one
`ImpactRingDrawer`; `SUMMON` and `CREATE_ITEM` have no entry and so draw nothing. Numbers draw for
attack and heal landings and for every visual-only delivery (a poison tick or bleed carries its status
id as its mechanic).

A landing point is nudged from the target's centre by `VfxDriver.scatter_offset`, within
`SCATTER_RADIUS`. The nudge comes from the delivery's own identity rather than being drawn each
frame, so an effect stays where it landed, and the projectile flies to the same nudged point. This
is what stops several hits on one creature stacking their rings and numbers in a single unreadable
spot.

Each landing that draws an impact (so not `SUMMON` or `CREATE_ITEM`) plays one sound through `SfxManager.play_impact()` ([audio.md](audio.md)), the first
frame the delivery shows as landed — the one thing here that is an event rather than a function of
`render_time`. The driver remembers which deliveries it has sounded and forgets them as the Combat
manager drops them.

**The circles are placeholders.** The projectile disc and the impact ring are drawn shapes standing
in for real VFX animations, there so the timing and the causal link between firing and damage can be
judged. They are to be replaced once proper animations exist, and their shape is not the intended
look. The effects style is open (`art_audio.md`). A screen pulse for ordinary hits is not built.

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

**Not** in scope: the final effects style and per-effect-family particle variety — polish on a driver that already works (`art_audio.md`).

---

## Open / deferred

- **Replacing the placeholder circles** — the projectile disc and the impact ring wait on real VFX
  animations. Until those exist the drawn shapes stand in. The pass that replaces them is planned in
  [`../plans/effects.md`](../plans/effects.md).
- **Effects style** — open. The look is being explored with full-resolution painted art, post-processing and palettes, not pixel art. Effect colours are the interface's effect colours in `Colours` ([interface_palette.md](interface_palette.md)). See `art_audio.md`.
- **Hit lights** — a short light at a hit enemy inside the 3D corridor already exists as a look setting ([corridor_3d.md](corridors/corridor_3d.md#hit-lights)); the effects pass keeps, changes or replaces it.
- **Projectile density tuning** (small/fast tracers for commons vs. crisp arcs for rares) — art doc, when the cascade is real.
- **The node split** (driver vs. leaf render nodes; all-2D vs. SubViewport) — impl, settled when the UI-layout approach is picked (`art_audio.md` UI-implementation note).

## Dependencies

- **Reads:** the `Combat manager`'s in-flight Delivery set (fire / impact timestamps, payload colour) + actor / item / status state; the `Timekeeper`'s `render_time()`. **Writes no game state.**
- **Does not:** decide outcomes or timing (`Combat manager` / `combat_model.md`); hold a clock (`Timekeeper`); advance combat; capture input (`UI`); render the corridor (`Corridor3D`).
