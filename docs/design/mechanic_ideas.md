# Mechanic Ideas — Parking Lot

> **Uncommitted.** A holding pen for *mechanics* sampled from other games (the way
> [`character_ideas.md`](character_ideas.md) parks character concepts). Nothing here is
> decided or scheduled. A mechanic graduates only when the owner attaches it to a character /
> status / item and chooses to build it — most should stay parked. Ideas that close move to
> [Retired](#retired) with the reason and anything salvageable.
>
> **Mechanics vs. characters.** A character is a *resource dressed in a theme*
> ([`character_ideas.md` → resource economies](character_ideas.md#cross-cutting--resource-economies));
> a mechanic here is a smaller part — a status rule, a trigger, a cost — that could slot into a
> character's pool or the shared baseline. Record the **source game**, the **rule as seen**, and a
> sounding-board read (where it fits our built systems, what it would cost to wire).
>
> Sounding-board notes (**Read**, **Engine cost**, **Open**) are *options to react to*, not
> proposals — pitched, not chosen.

---

## Bleed — *parked (source: grail, 2026-06-21)*

- **Rule as seen:** each time an item activates, the holder takes damage equal to **bleed**, then
  bleed is reduced by 1. A stacking value that pays itself down as the board fires.
- **Read — it's activation-paced (a new clock for us).** Every status we have runs on *time*
  (poison/burn tick per second) or *incoming damage* (block absorbs). Bleed runs on **board
  tempo** — it advances on item activations. So a wide/fast board burns through it quickly and a
  lean board stretches it out. Because of the `−1`, the **total** self-damage is a fixed triangular
  number (bleed 5 → 5+4+3+2+1 = 15 over five activations, then gone), but the **rate** tracks how
  hard the board is being driven. A front-loaded spike that always terminates.
- **The `−1` decay is the safety rail.** Without it, bleed on an auto-firing board is a runaway
  spiral; with it, it's a bounded, tunable cost. Treat the self-paydown as the core of the design,
  not an incidental.
- **Two polarities, two homes:**
  - **Enemy debuff (apply bleed to them):** turns the enemy's *own* aggression against it — fast
    attackers bleed themselves out. The likely grail reading.
  - **Self-cost (bleed yourself):** the [Fleshmancer](character_ideas.md#flesh-golem--meat--parked-new-2026-06-16) fit.
    Its identity is *HP-as-resource + a churning board*; bleed = "every item you fire taxes your HP,
    scaled by board activity" — the masochist knife-edge the design already names as the core loop.
    A different *texture* from the existing one-shot **Flensing Hook**: bleed is a spread-out,
    board-wide, decaying tax, and the churning chunks each tick it (thematically apt, a `/tune`
    watch — chunk count would spike it). For a self-cost, likely **unblockable** (the Flensing-Hook
    precedent: blockable would let the Fleshmancer's own block silently no-op the cost).
- **Engine cost — small, not free-wired.** `EventBus.Event.ITEM_FIRED` already exists, and there's
  already a per-fire hook for *item*-targeted statuses (`on_holder_fired`, used by Decay). Bleed is
  *actor*-targeted, so it'd need the actor-level twin: one new no-op `StatusEffect` hook + one call
  site in the fire path (where ITEM_FIRED publishes). Comparable to the decay seam. Ordering: the
  self-hit + decrement want a deterministic slot right after the payload resolves (#24).
- **Open:** which polarity (or both); blockable-vs-not per polarity; whether it's a character-bound
  status (Fleshmancer) or joins the shared baseline like Weak/Vulnerable (probably too complex for
  baseline); the starting magnitude (small — the triangular total grows fast).

---

## To add

- Mechanics from other games as they're sampled — record the source, the rule as seen, and the read.

## Retired

> Ideas taken off the bench — kept so they aren't re-pitched from scratch, with the reason. A
> retired mechanic's good parts get credited to wherever they went.

*(none yet)*
