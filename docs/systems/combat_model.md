# Dark Corridor — Combat PRD

First per-system PRD. Sits under the Architecture Map. This specifies how effects resolve during the combat state; it assumes the foundation spine (central fixed-step tick, symmetric Actor, renderer wall) from the architecture doc and doesn't re-state it.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

## Resolution model (settled)

### One accrual primitive — the Ticker
Items, active effects (poison / burn / regen / etc.), and triggered relics all have a Ticker: an accumulator, a threshold, an accrual source (the fixed time-step, or an event-push), and a payload that runs when the accumulator crosses the threshold.
The central tick advances every Ticker by one fixed step; those that cross fire their payload and reset (or decrement, for stack-based effects). A poison status ticking its damage and an item charging toward activation are the same mechanism, configured differently — same loop, no separate "status tick" vs "item tick". A **gated** item's Ticker is skipped entirely — accrual *and* trigger pushes — while the gate holds (decision #30: silence freezes the item's time; the gate lifting releases no banked burst).

Composition, not inheritance. Entities own a Ticker; they are not subclasses of one. This keeps item / status / relic distinct in identity, ownership, and presentation while sharing the accrual engine. (Avoids the if type == branching that signals a wrongly-carved abstraction.)
Potions have no Ticker — they're manually fired. The one thing that doesn't accrue-toward-firing is the one thing excluded, which is the tell that the boundary is right.

### Triggers accumulate the Ticker — by convention
"When X, do Y" is expressed as X pushing Y's accumulator (the charges model). There is no instant trigger-resolution and no deferred-resolve queue. Everything that "happens in response" happens by an accrual crossing its threshold on a tick. An instant reaction is just a push large enough to fill the bar (≈100%). "When X" defaults to "when **my side** does X" (decision #30) — events carry source identity, and a trigger opts into `ANY` / opponent-side listening per item.
This is a convention, not an enforced rule — nothing stops a trigger being written as an instant effect. We don't, for the reason below.
### Why not instant triggers (the Bazaar lesson)
Bazaar began with instant "when X happens to Y" triggers, spent its entire beta unable to tame the degenerate infinite loops they produced (A triggers B triggers A…), and ultimately moved to cooldown-pushes — a trigger does at most one thing, on the next tick. We adopt that from the start rather than rediscovering it: accrual-only is loop-proof by construction, no per-item caps, no drain guards, no recursion within a tick. A chain advances at most one link per tick, which at tick rate reads as "the machine went off" at speed and as a legible step-through under slow-mo.
We are not building a deferred-resolve queue. If a genuine event-reactive case ever appears that truly cannot be a push (a response with no item to charge), we build the minimum then, with a real example in hand — not speculatively. The queue's hidden cost (ordering rules, loop guards) isn't worth paying on spec.

### Fire / Delivery

When an item's Ticker crosses, the item fires: it resets its cooldown immediately and plays its fire-emote (recoil / flash). It does not resolve its payload at fire time — it produces a payload (kind, value) and a target-shape, and a Delivery is spawned carrying (payload, target, travel_time).

The Delivery counts down on the same tick and applies its payload (damage / status / etc.) when travel elapses — landing on arrival, not on fire.
Fire-rate and travel are decoupled. A fast item can have several Deliveries in flight at once. Preserves the size→cooldown tempo design (fast items ping often regardless of travel) and looks correct in a cascade.
This is why the causal bind works: the projectile arriving is the damage event, so fire-emote, flight, and damage-landing are three things sharing one clock rather than one tangled event — which is what keeps slow-mo coherent.
travel_time may be zero. Self-buffs, heals, instant potions, AOE-on-all resolve same-tick via zero countdown. Not a special path — just the zero case.

## Targeting

Leftmost living enemy for single-target; all for AOE. Never gets smart (no lowest-HP, no highest-threat). Consistency over optimality — predictability is what lets the player learn their build.
Target dies mid-flight → the Delivery fizzles. No retarget. (Consistent with "never gets smart".)
**Item targets** (effects that hit an opponent's *items* — e.g. silence): single-item selection is **random** (seeded RNG — provisional, may become a rule after testing); all-items is deterministic. Same fizzle rule — an item removed before arrival fizzles. Random here is a deliberate exception to the actor rule's determinism, traded for variety.


## Open / deferred

Timescale override return logic — hover slow-mo overrides the player's base battle-speed and returns to base, not ×1. Replace-vs-multiply when stacking the override on base: **resolved — replace** (absolute slow-mo, independent of the ×1/×2/×3 dial; see Timekeeper PRD).
Stack/decrement semantics per effect type — how poison stacks decrement, whether regen counts down, etc. — is per-effect content, settled as effects get authored, not here.
Anything requiring a deferred-resolve queue: explicitly not built until a real case forces it (see above).