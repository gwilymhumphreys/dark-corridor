# Dark Corridor — Actor PRD

Foundation PRD. Sits under the [Architecture Map](architecture.md). The `Actor` is the symmetric combatant: HP, a board of items, a status list — a **passive holder** that other systems act on. Player and enemy are the same `Actor` type.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

Boundaries (inbound / exposed surface) live in the hub: [architecture.md → Interface contracts → `Actor`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals* of that contract.

---

## Purpose

An `Actor` holds the three things a combatant *is*: **HP**, a **board of items**, and a **status list**. It is deliberately dumb — it exposes a small mutation surface (`take_damage` / `heal`, add/remove item, add/remove status) and a `died` signal, and otherwise just stores state. The rules that act on it live elsewhere: item behaviour ([Item PRD](item.md)), status behaviour ([StatusManager](status_manager.md)), targeting and win/loss (the `Combat manager`).

**An `Actor` never knows which side it's on.** Side, left-to-right ordering, and targeting are the `Combat manager`'s concern. Per the symmetry principle, **`Enemy` is not a subclass** — it's an `Actor` whose board is *authored* rather than *drafted* (the [Enemy PRD](enemy.md) covers only the authored-loadout / variety / composition specifics).

What it **is not**:

- Not the `Combat manager` — no ordering, no targeting, no win/loss; it only reports `died`.
- Not the `Item` — it *stores* item instances; it doesn't implement their behaviour (the `Combat manager` advances their Tickers each step).
- Not the `StatusManager` — it *holds* the (actor-targeted) status list; the stateless rules that apply/tick statuses live in the `StatusManager` autoload.
- Not run-flow — HP-economy *policy* (full-heal between acts, max-HP growth) is applied to it from outside, not decided here.

---

## State it owns

- **HP — current + max.** Reaches 0 → dead (emits `died`). Per [design](../design/game_design.md): HP **persists between encounters** (no auto-reset; damage carries forward); **max HP can grow within a run** (relics / events / rare items); a **full heal** is applied between acts. Those policies are *applied to* the Actor by run-flow / relics — the Actor just holds the values and exposes `heal` / max-HP mutation. (Numbers live in design/tuning, not here.)
- **Board — the item instances.** Uniform slots, **no spatial puzzle** (per design) — an *ordered collection*, not a grid. The order is used for deterministic ticking and display zoning, not adjacency. The board's item **Tickers are what the `Combat manager` registers and advances each step** at combat start, and what draft adds to (player) between fights. Sizes are content, not fixed here (player grows to ~20–25 by late run; enemy boards run small — see design).
- **Status list — actor-targeted statuses only.** Statuses can target an actor *or* an item (architecture); item-targeted ones live on the `Item`, so the Actor holds only the actor-targeted ones. **Block** is one of these — an actor-targeted status that absorbs damage (see `take_damage`). The `StatusManager` (stateless facade over the `StatusEffect` instances) reads/writes this list; the `Combat manager` advances each time-driven status each step (on the `Timekeeper`'s clock).

What it does **not** hold: **relics and potions** — both live in the **player run-state** (`{ actor, relics, potions, … }`), not in the Actor. Relics act on the Actor from outside (combat-start buffs via `StatusManager.apply`); potions are a separate reserve the `Combat manager` activates when thrown. Keeping them out keeps the Actor a pure, symmetric combatant.

---

## Interface (surface others act through)

- `take_damage(amount, …)` — runs the raw amount through the target's incoming-damage-modifier statuses via the `StatusManager` (absorbers like block consume before HP; the precise amplifier/absorber order is settled when `vulnerable`-type statuses exist — StatusManager PRD), applies the remainder to HP; at 0 HP → `died`. `heal(amount)` is straightforward. Called by Deliveries / items on arrival, and by potions/relics.
- `is_alive()` + a **`died` signal** — the `Combat manager` reads these for win/loss. No Actor decides the fight is over.
- **Board access** — read the item list (for the Combat manager's registry and UI); add/remove an item (draft adds to the player board between fights).
- **Status access** — add/remove/read actor-targeted statuses (the StatusManager operates here).

The Actor calls *up* to nothing; its one sideways call is `take_damage` asking the `StatusManager` (a foundation peer) to resolve damage-modifier statuses. Everything else acts on it.

---

## Symmetry & lifetime

- **Same type, both sides; no side-specific fields.** "We should be able to put characters-with-items on either side" is a constraint on the abstraction, not a feature.
- **Forward-compat: each side is a *party*.** Treat a side as a roster of `Actor`s — length 1 on the player side today, but don't hardwire "exactly one player `Actor`" (keeps drafting-allies / summoning additive — decision #22).
- **Lifetime differs by role, not by type:**
  - **Player Actor → run-lifetime.** HP carries across encounters; the board grows via draft; relics/events modify it. Owned by the run (seeded by `Characters`, held across the run).
  - **Enemy Actors → fight-lifetime.** Spawned by `Encounter` per fight from an authored board, discarded after.
  The `Combat manager` references both during a fight but owns *neither's* lifetime.
- **Cycle break on discard.** `Actor`/`Item` is a `RefCounted` cycle (the board holds each item; every item's `owner` points back). `Actor.dissolve()` breaks the whole board at discard; `Item.dissolve()` breaks **one** item's half — used when a single item leaves a live board mid-fight (Decay emptying it, or the combat-scoped strip of a created item — [`item_creation_and_decay.md`](item_creation_and_decay.md)). `Actor.dissolve()` is just a loop of `Item.dissolve()` plus clearing the board.

---

## Prototype scope

- HP (current / max) + `take_damage` / `heal` + the `died` signal.
- A board holding a few item instances, exposed for the Combat manager's registry.
- An actor-targeted status list the `StatusManager` can read/modify.
- One **persisting player Actor** + one **per-fight enemy Actor** — enough to prove the symmetry and the lifetime split.

**Not** in scope: relics/potions (player run-state, separate PRDs); max-HP-growth sources and full-heal-between-acts (run-flow applies these later). Block needs no special Actor field — it's a status on the status list, resolved by `take_damage` through the `StatusManager`.

---

## Open / deferred

- **Mid-flight death** — a target that dies before a Delivery lands → the Delivery fizzles (Combat PRD rule). The Actor just reports `died`; the fizzle is the `Combat manager`'s / Delivery's concern.

Resolved since first draft: **block** is an actor-targeted absorb-status (`take_damage` runs through modifier-statuses, block first — no special Actor field); **status ownership** — instances live on targets (Actor holds actor-targeted, `Item` holds item-targeted), `StatusManager` is stateless rules; **relics & potions** are run-level (player run-state), not Actor-owned.

## Dependencies

- **Above:** `StatusManager` only — `take_damage` calls it to resolve damage-modifier statuses (block, etc.). Both are foundation, so it's a sideways call, not upward. Otherwise a passive holder.
- **Used / acted on by:** `Combat manager` (holds the pair, reads board + `is_alive`), `Item` / Deliveries (damage / heal), `StatusManager` (statuses), `Relic` (direct modification), `Characters` / `Run manager` (create + seed the player Actor, max-HP growth, full heal). `Enemy` = an Actor with an authored board.
