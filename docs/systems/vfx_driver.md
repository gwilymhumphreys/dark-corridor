# Dark Corridor — VFX Driver PRD

Presentation PRD (output layer). Sits under the [Architecture Map](architecture.md). The `VFX driver` is **the wall** — it renders combat visuals as a **pure function of handed state + the clock**, and **writes no game state**. It computes where every projectile / impact / number is from the [Combat manager](combat_manager.md)'s Delivery set and the [Timekeeper](timekeeper.md)'s `render_time()`; the renderer paints what it computes.

**Engine:** Godot 4.
**Date:** 2026-06-05 (written before the build; the driver and its drawers are built).
**Naming:** a driver + leaf render nodes — *not* a manager (it holds no game state); one `VfxDriver` node (`src/vfx/vfx_driver.gd`) with one drawer class per effect in `src/vfx/drawers/`.

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
- **Screen shake** on big hits — a real-time tween on the view (below), not a function of the sim clock.
- **SFX one-shots** — triggered at `impact_time` (the sim clock), then **played at wall-clock pitch** (unslowed — slowing audio sounds bad). Same stored timestamp as the flash, read two ways: a continuous function (visual) and a fire-and-forget event (sound). *(What the SFX sound like is `art_audio.md`, not here.)*

Because fire-rate and travel are decoupled (combat_model.md), many Deliveries can be in flight at once; the driver renders each independently from its own timestamps — chaos at full speed reads as "the machine went off," and under slow-mo-hover a single inspected chain resolves cleanly (art doc).

## What is built

`VfxDriver` (`src/vfx/vfx_driver.gd`) draws a solid projectile in flight on a slight upward arc
(`VfxDriver.arc_point`, height set by `ARC_HEIGHT` as a fraction of the distance), a ring that snaps outward
where it lands, and a number for damage and healing, each in the delivery's colour. The number
(`DamageNumberDrawer`) has a black outline. Its size grows with the amount on a logarithmic curve,
from a fixed base size to a maximum, so it rises quickly for small amounts and slowly for large
ones. It floats up while drifting sideways, away from the target's centre on the side its landing
point was nudged to, by an amount that grows with how far off centre it landed plus a small
random amount fixed per delivery, with a slight side-to-side wave, then quickly
grows and shrinks away. Heals show a '+' in front. The landed delivery is kept for
`Balance.DELIVERY_VISUAL_HOLD`, which must be at least the number's duration.

**Attack hits (trial).** While `VfxDriver.attack_sprites` is on, an attack landing draws
`AttackHitDrawer` instead of the ring. A firing item whose `attack_sound` is `blade` gets a slash: a
crescent that draws across from one end to the other, turned to face the direction the projectile
was travelling as it landed (`VfxDriver.landing_direction`), with a small random tilt and a random
mirror fixed per delivery, then fades. Any other attack gets an impact: a sharp flash that grows
fast, over a spreading ring and a burst of debris, turned by a fixed random angle. The images are
from Kenney's Particle Pack, stored in `assets/vfx/attack/` as white shapes so they can be tinted:
each has a base drawn in the delivery's colour and a core (its brightest part) drawn in the
off-white text colour. The switch is **Attack Sprites** in the debug panel's Feedback tab (F5), and
`--attack-effect=ring` starts with it off. The `hit_effects_preview` dev scene
([dev_tools.md](dev_tools.md)) repeats both effects and shows a strip of frames through each.

**Poison, burn and bleed (trial).** While `VfxDriver.status_sprites` is on, a poison, burn or bleed
landing draws `PoisonDrawer`, `BurnDrawer` or `BleedDrawer` instead of the ring. Each has two
effects: one where the status is applied, and one when it deals damage (the visual-only delivery of
a poison or burn tick or a bleed trigger, told apart by `Delivery.visual_only`).

- Poison applied: a green puff swells, blobs of goo are thrown outward and sag as they slow, and
  bubbles rise from around the landing point and pop one after another.
- Poison damage: a few small bubbles rise from the holder and pop. Bigger ticks raise more bubbles,
  up to a limit (`PoisonDrawer.tick_bubbles`).
- Burn applied: a burst of fire flares, flame tongues spring up around the landing point, and
  embers rise. A tongue shoots up, then dies down while lifting off, and flickers by switching
  between two flame images and changing width. Each has a paler core at its base.
- Burn damage: two to four smaller flame tongues lick up from the holder, throwing off embers.
  Bigger ticks raise more (`BurnDrawer.tick_tongues`).
- Bleed applied: a splat of round drops bursts where it lands, and drops spray on in the direction
  the projectile was travelling, falling under gravity.
- Bleed damage: a smaller splat, and a spurt of drops thrown upward that fall back down.

The images are from Kenney's Particle Pack, in `assets/vfx/status/`: a round blob, a rim-lit
bubble, a puff, four flame tongues and a fire burst. They are drawn in the delivery's colour, with a
small off-white glint on blobs, bubbles and drops and a paler core on flames. Each particle's path
comes from `EffectDrawer.fixed_random`, so it stays the same for as long as the effect shows. The
switch is **Status Sprites** in the same Feedback tab, and `--status-effect=ring` starts with it off. The preview scene has a page for each.

**Projectiles (trial).** While `VfxDriver.comet_projectiles` is on, a delivery in flight is drawn by
`ProjectileCometDrawer` instead of the disc: a comet in the delivery's colour, with a solid head half
the disc's width, a paler middle, a soft glow, and a tail that trails back along the arc
(`VfxDriver.arc_direction` gives the direction at any point of the flight). The tail grows out from
the head just after launch, so it never reaches back past the firing item. The tail is Kenney's
`trace_01` and the glow `star_05`, in `assets/vfx/projectile/`; the head is the round blob from
`assets/vfx/status/`. The switch is **Comet Projectiles** in the Feedback tab, and
`--projectile=disc` starts with it off. The preview scene's projectile page flies comets in four
colours at an enemy and shows each beside the old disc.

**Big hits.** A damage landing of at least `VfxDriver.BIG_HIT_DAMAGE` emits `big_hit` with a
strength from 0 to 1 (`big_hit_strength`), once, alongside its sound. `CombatViewFramed` answers
with a short pause of the fight (`CombatManager.request_hit_pause`, which calls `Timekeeper.hold`)
and a shake of the whole view, both growing with the strength. The pause only delays steps, so
results are unchanged, and the autotest has no view, so it never pauses. The shake is a tween of
the view's `offset_transform_position` on real time, so it plays through the pause. The firing item's own
reaction is not the driver's: `item_cell.gd` punches the cell's scale off the same clock. A hit
enemy also flinches back in the corridor and is lit ([run_screen.md](run_screen.md#enemies-in-the-corridor-the-approach)).

**Look.** `VfxWall` is drawn through the interface look's effects material, so the effects can take
the pictures' halftone, palette and dithering; it is off by default
([interface_look.md](interface_look.md#the-combat-effects)). The damage numbers are drawn on a
`Numbers` child the driver creates, from the same delivery set and clock, so they sit above every
other effect and can take the element material instead (`_numbers_material_update`).

Each shape is its own class under `src/vfx/drawers/`, extending `EffectDrawer`: `duration()`,
`progress(age)` and `draw_effect(canvas, delivery, point, age)`. A drawer holds no state, so slow
motion and pause keep working. The driver keeps a dictionary from a mechanic id (for a `MECHANIC` delivery) or
`Delivery.Kind.APPLY_STATUS` to the drawer, so a new effect is a new file rather than another branch in
`_draw()`. Five [mechanics](mechanics.md) (attack, poison, burn, bleed, crit) and status application currently share one
`ImpactRingDrawer`, which attack, poison, burn and bleed replace with their own drawers while the trial switches above are on; the other mechanics have no ring; `SUMMON` and `CREATE_ITEM` have no entry, so they draw a projectile in flight and nothing on landing. Numbers draw for
attack and heal landings and for every visual-only delivery (a poison tick or bleed carries its status
id as its mechanic).

**Status applications land on their icon.** A status application (`Delivery.Kind.APPLY_STATUS`,
such as Mighty Blow's Empowered) on an actor flies to that status's icon on the actor's panel,
through `CombatView.status_pos` and `CharacterPanel.status_centre`. If the actor does not have the
status yet, it flies to the slot its icon will take (`StatusIcons.slot_centre`). When the status
appears, its icon pops in, and when its stacks rise the icon bumps (`PopAnimation`, see
[run_screen.md](run_screen.md)). A status application on an item lands on the centre of the item's
cell, not nudged; statuses on items are not drawn on the cell yet. No ring is drawn for a status
application; **Ring At Status Icons** in the Feedback tab turns it back on. The mechanics that are
statuses (shield, poison, burn, bleed, regen) are not status applications and land as below.

**Shield, heal and regen.** Shield, healing or regen given to an actor flies to the centre of
that actor's health bar (the mechanics in `VfxDriver.BAR_MECHANICS`) through `CombatView.health_bar_pos`, instead of to the actor. These landings are not nudged by the
scatter below. A view with no health bars, such as the combat sandbox, falls back to the actor's
point.

- Shield lands with `ShieldDrawer`: the shield mechanic's icon appears small, quickly grows and
  fades out. Each landing draws its own icon, so a burst of shield shows several at once.
- Heal lands with `HealDrawer`: a few small heal icons, more for bigger heals, start one after
  another in separate sections of the bar, float up with a slight wiggle and fade out. The heal
  number still shows.
- Regen lands with the same `HealDrawer`, made for the regen mechanic so it floats regen's icon in
  regen's colour. A regen tick's healing (a visual-only delivery) shows it on the bar too.

A landing point is nudged from the target's centre by `EffectDrawer.scatter_offset`, within
`EffectDrawer.SCATTER_RADIUS`. It lives on the drawer base class so drawers never refer back to
`VfxDriver`; the two scripts referring to each other made Godot leak scripts at exit. The nudge comes from the delivery's own identity rather than being drawn each
frame, so an effect stays where it landed, and the projectile flies to the same nudged point. This
is what stops several hits on one creature stacking their rings and numbers in a single unreadable
spot. A projectile starts from the firing item's cell (`item_pos`), or for a thrown consumable from
the potion slot it was thrown from (`consumable_pos`, read from `Delivery.consumable`).

Each landing except a `SUMMON` or `CREATE_ITEM` (`has_impact_sound`) plays one sound the first
frame the delivery shows as landed — the one thing here that is an event rather than a function of
`render_time`. The driver remembers which deliveries it has sounded and forgets them as the Combat
manager drops them.

Which sound comes from the delivery: a `MECHANIC` delivery plays the mechanic's own folder
(`Mechanic.sound_key`, see [mechanics.md](mechanics.md)) and an `APPLY_STATUS` delivery plays
its status id, both through `SfxManager.play_sound` ([audio.md](audio.md)). It is not
cooldown-guarded, so a cascade is heard as every hit that lands rather than as one sound. Charge
and decharge draw no ring on the item they move but are still heard. A delivery flagged `crit`
also plays `mechanics/crit` on top; that layer is cooldown-guarded, because one critting fire can
land on several targets at once.

**The circles are placeholders.** The projectile disc and the impact ring are drawn shapes standing
in for real VFX animations, there so the timing and the causal link between firing and damage can be
judged. The trials above (attack hits, poison, burn and bleed, and the comet) replace them where
they are switched on; the ring is still drawn for every other mechanic. Their shape is not the
intended look. The effects style is open (`art_audio.md`). A screen pulse for ordinary hits is not built.

## Reading the Combat manager's Delivery set

The `Combat manager` keeps a resolved Delivery until its visual's max duration elapses (so the driver can read `render_time − impact_time` *after* the damage has landed), then drops it. The driver reads that set each frame + `render_time()`; it never mutates it.

---

## Prototype scope

Per the architecture's "full VFX *path*, minimal *content*" — build the driver + the wall and prove them on a few effects:

- one **projectile** type (position from `render_time − fire_time`),
- one **fire-emote** (item recoil / flash),
- **travelling damage numbers** — including DoT ticks, which carry no landing Delivery of their own, so the Combat manager hands the wall a **visual-only** Delivery (pre-landed, payload-less) per tick to pop the number,
- a **screen pulse** (not built; big hits shake the view instead).

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

## Dependencies

- **Reads:** the `Combat manager`'s in-flight Delivery set (fire / impact timestamps, payload colour) + actor / item / status state; the `Timekeeper`'s `render_time()`. **Writes no game state.**
- **Does not:** decide outcomes or timing (`Combat manager` / `combat_model.md`); hold a clock (`Timekeeper`); advance combat; capture input (`UI`); render the corridor (`Corridor3D`).
