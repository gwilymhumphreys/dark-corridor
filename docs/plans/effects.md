# Plan: the combat effects pass

Plan for turning the placeholder circles in the combat wall into real effects. Written after the
first pass ([`../systems/vfx_driver.md`](../systems/vfx_driver.md)) so it follows something that
runs rather than a guess. Nothing here is built yet, and the look is not chosen.

Plans are not catalogued in `docs/index.md`. If this ships, its content moves into
`../systems/vfx_driver.md`.

## What exists

`VfxDriver` draws a disc for a projectile in flight, a ring where it lands, and a rising damage
number, each in the delivery's colour and each a pure function of `render_time()`. The firing item
punches its own cell (`item_cell.gd`), a hit enemy flinches and is lit in the corridor
([`../systems/run_screen.md`](../systems/run_screen.md#enemies-in-the-corridor)), and each landing
plays one sound. The circles are placeholders. There is no effects framework and this plan does not
propose one: what is needed is one drawing layer with settings for comparing looks.

## The question for the owner, first

Effects can be drawn in two places, and the choice changes everything after it, so it is settled
before any of the work below.

- **In 2D over the corridor**, as now. Effects stay crisp at full resolution and are unaffected by
  the corridor look shader, the world palette and the print overlay.
- **Inside the 3D corridor**, so the corridor look shader, the world palette and the print overlay
  apply to them and they sit in the same image as the creature.

This is judged from screenshots of real fights, not decided by an agent. Following
[`corridor_look_handoff.md`](corridor_look_handoff.md): build both as a setting, take screenshots
at staggered delays, publish one comparison page, and let the owner pick.

## One effect per delivery kind

`Delivery.kind` already says what a delivery does, so it is the mapping key. The corresponding
effect for each kind, and the two cases that currently draw nothing:

| `Delivery.Kind` | In flight | On landing |
|---|---|---|
| `DAMAGE` | projectile | impact effect + damage number |
| `HEAL` | projectile | heal effect on the target, no damage number |
| `APPLY_STATUS` | projectile | the status's own effect, keyed on `status_id` |
| `SUMMON` | nothing | an arrival effect where the new body appears |
| `CREATE_ITEM` | nothing | an effect on the board slot the item lands in |

Two flags change the landing and are not drawn today, because `_draw()` skips every delivery with
`fizzled` set:

- `evaded` — the attack swung and whiffed. It needs a miss tell distinct from a hit.
- `fizzled` without `evaded` — the target died before arrival. The projectile should fade out rather
  than vanish on the frame.

`visual_only` deliveries carry a damage-over-time tick's number with no payload. They keep the
number and get no projectile or impact.

## The drawer interface

Each effect type becomes one file so the set can grow without `_draw()` growing. The shape:

- A base class with a draw call taking the delivery, the screen point and the render-time age, plus
  the duration it occupies. It holds no state, so slow motion and pause keep working.
- `VfxDriver` owns a dictionary from kind to drawer instance and calls the matching one. The
  existing ring and disc become the first two drawers, unchanged, so the refactor is testable before
  any new effect is written.
- Drawers live in `src/vfx/drawers/`. A drawer that needs a sprite sheet reads the frame from its
  age; a shader effect gets its progress as a uniform. Particle nodes keep their own state and
  cannot be rewound, so they are the exception, not the default (settled in the first pass).

## Settings for comparing looks

The debug panels are the place for this, matching how the corridor look and the palettes are
compared. F1 to F4 are taken, so an effects panel takes F5. What belongs in it:

- Where effects are drawn — 2D over the corridor, or inside the 3D corridor.
- Which drawer each kind uses, once there is more than one per kind.
- Durations and sizes, so the owner can judge the feel at his PC.
- Screen shake amount, including off.
- A start-up argument per setting, so screenshots of real fights can be scripted.

Saved sets follow the palette combo pattern in
[`../systems/debug_panel.md`](../systems/debug_panel.md) if more than a couple of settings survive.

## Damage numbers

Several numbers used to stack in one spot during a burst and could not be read. The owner's
decision was to randomise the hit location a little, which is enough for now. Done: a landing is
nudged from the target's centre by an offset derived from the delivery itself, so the ring, the
number and the projectile's destination all move together and stay put while they play.

## Screen shake

The next piece of the impact half after the drawers. Two constraints: it reads `render_time()` like
everything else, so slow motion slows it and pause holds it; and `PrintFrame` repositions the
corridor every frame, so the shake has to be applied in a way that survives that rather than
fighting it.

## Sound

`SfxManager.play_impact()` is wired and silent, because `assets/sound-effects/combat/impact.wav` does
not exist. A file is needed before the impact reads as a hit. Getting one is the owner's call.

## Order of work

1. Ask the owner to look at the current effect, running a fight or from screenshots.
2. Settle the 2D-versus-3D question with a comparison page.
3. Extract the existing disc and ring into drawers, with the tests staying green. **Done.**
4. Fix the damage numbers. **Done**, by scattering the landing point.
5. Add the missing landings: the miss tell, the death fade, and effects for `HEAL`,
   `APPLY_STATUS`, `SUMMON` and `CREATE_ITEM`.
6. Add screen shake.
7. Add the F5 panel and its start-up arguments alongside whichever of the above needs comparing.

Each step keeps the working standard: the full test suite green, the seeded autotest still winning
with exit 0, and the affected docs updated in the same change.

## Not in this pass

A definition or registry system, effect pooling, and per-effect-family particle variety. The game
needs one drawing layer and the settings to compare looks on it.
