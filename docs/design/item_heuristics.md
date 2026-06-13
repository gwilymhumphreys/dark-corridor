# Item Tuning Heuristics

> **Guidelines for the *starting* properties of new items — not fixed rules.** They give a
> first number to react to, so a new item lands roughly on-budget instead of guessed from
> scratch. Real balance is decided in tuning (the `/tune` skill, real fights); any item may
> deliberately break a heuristic for a reason. Numbers live in `src/data/balance.gd`; this doc
> records the *reasoning* (per the docs-describe-systems-not-numbers rule).

## The DPS curve — `DPS = cooldown + 3`

A pure-damage attack's expected DPS rises **+1 per second of cooldown**, anchored at the
**2s = 5 DPS** baseline (Capped Cudgel — 10 dmg / 2s). So 1s→4, 2s→5, 3s→6, 4s→7, 5s→8.

> *Recorded from code, owner to resolve in `/tune`:* **Rusted Blade** (6 dmg / 1.2s = 5 DPS)
> sits **+0.8 over the curve** (the line gives 4.2 at 1.2s) — the starter weapon out-earns
> its cooldown. Flagged, not changed: whether the starter rides above the line is a tuning call.

**Why slow items need *more* DPS** (not the same): a slow item gives up value to —
- **Overkill** — a big hit into a near-dead target wastes the damage past 0 HP. Fast small hits spend almost exactly to the kill.
- **Trigger density** — anything per-*hit* (on-hit relics, the Spores-applied event, charge-pushers) fires per swing, not per damage. Slow weapons swing rarely → fewer procs.
- **Commitment** — fast weapons contribute immediately and can be redirected; a slow weapon front-loads a long wind-up.

**Applicability:** linear holds across the **1–6s** authoring range. The tail must taper — overkill/trigger loss is bounded, so a pure +1/s line would make ultra-slow weapons (10s+) oppressive nukes. Revisit the slope if anything slower than ~6s is authored.

## Effect riders cost DPS

A non-damage effect bolted onto an attack is paid for by **dropping the item's damage below
its curve DPS**. The damage portion = `(curve DPS − effect cost) × cooldown`.

**Effect cost depends on the effect** — there's no flat rate. Starting points:
- **Generic timed debuff (e.g. Weak): ~2 DPS.** First example: a 4s attack applying Weak → curve DPS 7, minus 2 = 5 DPS of damage = 20 dmg, plus the Weak.
- **Blinding: ~2.7 DPS** *(recorded from code — implied by Pocket Shrooms: 10 dmg / 3s = 3.3 DPS
  against a curve 6, paying for the 2s blind; owner to ratify or retune).*
- More costs get added here as items are authored and tuned.

**Spores are free.** A Spores rider costs **0 DPS** — a Spores applier pays its full curve DPS
in damage *and* stacks Spores. Rationale: Spores do nothing on their own (pure Mass ammo,
[`spore_druid.md`](spore_druid.md)); their value is realized only by a Mass payoff the player
must *also* draft, so the applier alone isn't getting a free effect. Revisit if Spores ever
earn a solo effect.

## The block curve — `block/sec = cooldown + 2` *(recorded from code, owner to ratify)*

The self-block items follow a parallel curve, **anchored at 2s = 4 block/sec** (Iron Guard —
8 block / 2s) and rising **+1 per second of cooldown**, mirroring the weapon line's
fast-taxed / slow-rewarded shape (the leather spread in `src/data/balance.gd`: Gloves 1s→3,
Trews 2s→4, Breastplate 3s→5). This section records what the authored numbers already do —
it lived only in a `balance.gd` comment; the rule itself is the owner's to keep or change.

## Status durations are per-application

A timed status's **duration rides the application** — an applier sets `ItemEffect.duration` and it
flows through to the status instance (the 2026-06-10 status refactor). So "apply 2s Weak" is just
this item's `duration = 2.0`; a different item can apply a longer Weak. The `Balance` constants
(`STATUS_WEAK_DURATION`, …) are now *default durations an applier reuses*, not a global the status
owns. Re-applying a timed status **stacks** (extends the timer) by default. (Non-timed statuses —
block, poison, spores — ignore `duration`; their `count` is the magnitude.)
