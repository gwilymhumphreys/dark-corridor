# Dark Corridor — Combat Log & Single Source of Truth PRD

> **Engineering work, NOT content — a building agent should implement it.** Adds a
> per-fight **observation log** of damage / healing / shield / effects + item-activation
> counts + timestamps, makes it the **single source of truth** for damage numbers (the
> autotest reads it instead of reconstructing), and surfaces it to the player **live** (a
> HUD readout) and on a **post-fight screen** (damage report · event log · continue).
> Session-only. **No replay, no scrubbing / step-back** (cut: combat effects that reach
> into run-state make a faithful re-sim disproportionately complex for the value).

Reuses the deterministic combat spine and the existing read-only observer discipline (the
VFX wall and the autotest both *read* logic and *write no game state*). Adds **no new
resolution model** and **does not touch the trigger
[event bus](../systems/combat_manager.md#the-trigger-event-bus)** — the loop-proof core is
untouched.

**Engine:** Godot 4.
**Date:** 2026-06-21. Approved scope (player-facing; live + post-fight screen; single
source of truth for damage; session-only; no replay / no scrub).

---

## Purpose

We have no record of what happened in a fight. The trigger `EventBus` publishes
`ITEM_FIRED` / `DAMAGE_DEALT` / `HEALED` / `STATUS_APPLIED` / `ITEM_DESTROYED`, but those
are **for triggers**, not accounting: `DAMAGE_DEALT` / `HEALED` carry `data = null` (no
magnitude), DoT ticks publish **no event** (they damage inside `_advance_statuses_on`),
and nothing records the stream — it evaporates each step. The only tallies that exist live
in the **autotest** (`AutoTestLogger`), which **reconstructs** them by diffing HP
before/after each `sim_step()` — a parallel, autotest-only code path with its own
attribution heuristics.

So we add a dedicated **`CombatLog`**: a per-fight, combat-scoped sink the
`CombatManager` writes to **at each mutation site** (where amount + source + `sim_time`
are already in hand), and we **route the autotest through it too** so there is one
canonical set of numbers. One observer, fed directly — no event-bus changes, no HP-diff
reconstruction — and it captures the cases the bus misses (DoT, block magnitude).

**In scope:**

- **Tallies** per source item: damage dealt, healing done, **shield (block) applied**,
  count of other statuses applied — split by side; the **single source of truth**, used by
  the live readout, the post-fight report, **and** the autotest / `/tune` report.
- **Item activation counts** + **timestamps** (every fire logged with its `sim_time`).
- An ordered **event timeline** (`{ t, type, source, target, amount }`) — the post-fight
  **event log** view (the "log of every event" with timestamps).
- **Live** HUD readout + a **post-fight screen**: damage report · event log · continue.

**Out of scope:** replay; scrubbing / step-back-forward; combat-state snapshots; save
persistence (the log is session-only, combat-scoped, gone at fight teardown).

---

## Design A — direct-write observer (not the bus)

The `CombatManager` holds an **optional** `var combat_log: CombatLog = null`. The run
screen creates one per fight and assigns it after `start()`; the autotest does the same
headlessly. At each mutation site the manager makes one **null-guarded** call. Why direct
calls, not the `EventBus` listener channel:

- The listener signature `(data, source_actor, source_item)` carries **no amount and no
  timestamp**, and `data` is the trigger filter key — it **can't** carry block's value
  (`STATUS_APPLIED` already uses `data` for the status id).
- DoT publishes no event; we'd have to add one anyway.
- The bus is the loop-proof trigger core — keep it untouched. Direct calls hand the log
  the full rich data at the exact moment, with zero risk to triggers.

**No game-object references are stored.** The log records `name_key` strings + ids +
primitives at write time and drops the object — so no `Actor`/`Item` cycle, nothing to
clean up (cf. the RefCounted cycle rules in `CLAUDE.md`). Combat-scoped: a fresh
`CombatLog` per fight; the run screen retains its ref after the fight (for the post-fight
screen) — `teardown()` nulls only the manager's ref.

## Design B — single source of truth (decision: do it now)

`CombatLog` becomes **the** damage/heal/block/fire tally; the autotest stops
reconstructing. Concretely:

- `AutoTestMode` attaches `cm.combat_log = CombatLog.new()` before its `sim_step()` loop
  and reads it at fight end — **deleting** the per-step HP snapshots, `_observe_damage`,
  `_observe_support`, and `AutoTestLogger.attribute_damage` / `_split_remainder`.
- `AutoTestLogger` keeps only what is **not** a damage tally: the per-encounter records
  (`record_encounter`, run-mode), the summary/report **formatting**, and the file writers
  — now **sourced from `CombatLog`** (its `fires_by_item` / `damage_by_item` /
  `block_by_item` / `healing_by_item` / totals replace the local dicts).
- **Attribution is now more correct, not just unified.** The old HP-diff path split a
  multi-DoT remainder *proportionally by weight*; direct emission credits **each DoT tick
  to its own status's source exactly**. Block-absorbed and killing-blow-capped numbers
  already match (both use net-after-block HP delta — see Design C).

## Design C — `Actor` return values (effective amounts)

`take_damage` / `heal` currently return `void`; the net-after-block / HP-capped amount is
computed and discarded. Widen both to return the **actual HP delta**:

- `Actor.take_damage(amount, flags) -> float` → `hp_before - hp` (post-block, capped at
  remaining HP — a killing blow logs effective damage, not inflated raw).
- `Actor.heal(amount) -> float` → HP actually restored (post-overheal-cap).

Additive and safe — statement-callers ignore the return and still compile. This is what
lets the log show honest numbers with no HP-diff machinery.

---

## The pieces

### Capability 1 — `CombatLog` (the sink)

New `src/combat/combat_log.gd`, `class_name CombatLog extends RefCounted`. Pure tally +
timeline, unit-testable on synthetic input:

- **Timeline:** `events: Array` of `{ t: float, type: String, source: String,
  source_side: int, target: String, amount: float, data: String }` (type ∈ fire / damage /
  heal / block / status / throw; `data` holds the status id or thrown consumable id where
  relevant). Append order = sim order. This is the post-fight **event log**.
- **Per-source-item tallies, side-aware:** `fires_by_item`, `damage_by_item`,
  `healing_by_item`, `block_by_item`, `statuses_by_item` (count) — keyed **per side**
  (nested `side → name_key → value`, or a dict pair), **not** flat `name_key`. Side-keying
  is required: a colorless item can sit on both sides (a flat key would conflate them), and
  the player report + the autotest contribution table both want **player-side only**.
  `summary(side)` returns one side's rows. Totals also split by side
  (`total_damage_dealt` / `_taken`, `total_healing`, `total_block`). A source-less DoT (no
  applier item) falls to a generic bucket (the old `DOT_FAMILY` role moves here).
- **Write methods** (manager-called; each takes resolved `name_key`s + side + `sim_time`):
  `on_item_fired`, `on_damage`, `on_heal`, `on_block`, `on_status_applied`, `on_throw`.
- **Read surface:** the tallies + `summary(side)` (flat per-item rows Item · Fires ·
  Damage · Block · Healing + totals) + the timeline. Localization: stores `name_key`s /
  ids, never display strings — views `tr()` at draw.

### Capability 2 — wire the `CombatManager` mutation sites

Six null-guarded one-liners; `sim_time` is `timekeeper.sim_time`. Confirmed sites in
current `src/combat/combat_manager.gd`:

1. **Fire** — `_fire_item`, after `ITEM_FIRED` (line ~333): `on_item_fired(it, t)`.
2. **Direct damage** — `_land` DAMAGE (~442): `var dealt := d.target.take_damage(d.value,
   d.flags)` then `on_damage(source_item, source_actor, target, dealt, t)`.
3. **DoT damage** — `_advance_statuses_on` (~298): `dealt` is **already computed** for the
   DoT visual; add `on_damage(...)` with the status's source (`st.source` may be an `Item`
   → name + owner; an `Actor` → no item; or null — resolve like `_source_item_of`).
4. **Heal** — `_land` HEAL (~446): `var healed := d.target.heal(d.value)` then `on_heal`.
5. **Shield** — `_land` APPLY_STATUS (~449): `d.status_id == BlockStatus.ID` → `on_block(
   source_item, d.value, t)`; …
6. **Other effects** — …else `on_status_applied(source_item, d.status_id, target, t)`.

Plus **throws** — `throw_consumable` (~667): `on_throw(consumable def id, thrower, t)` so a
thrown potion shows in the event log. Source identity reuses `_source_item_of(d)` +
`d.source_actor`; side via `_on_player_side`.

### Capability 3 — `Actor` return values

As Design C: `take_damage` / `heal` return the HP delta.

### Capability 4 — live HUD readout

`combat_view_framed` reads the live `CombatLog` each frame for a small totals widget
(*Dealt · Taken*). Minimal; the per-source data is present to grow into per-item live
contribution later. Static labels in the `.tscn` (auto-translate).

### Capability 5 — post-fight screen

A new screen shown at fight resolution, **before** the draft overlay (parks the run-screen
FSM like the draft/event overlays — `FIGHTING ─(resolved)→ SUMMARY → after-beat`):

- **Damage report** — the per-item contribution table from `CombatLog.summary(player)`
  (Item · Fires · Damage · Block · Healing); item names via `tr(name_key)`.
- **Event log** — the ordered timeline with timestamps ("`1.4s  Venom Fang → Goblin  8`").
- **Continue** button — dismiss → the draft.

Static labels in the `.tscn`; dynamic rows via `tr()`. **On a loss** the run ends (death
screen) — see Open/deferred for whether the summary shows first.

---

## Build order

Test-first, each its own green commit; headless autotest is the regression backstop:

1. **Capabilities 1 + 3** — `CombatLog` + `Actor` return values. Pure logic, fully
   unit-tested, no UI.
2. **Capability 2** — wire the six manager sites + throws (incl. the new DoT log).
3. **Design B (single source of truth)** — route the autotest through `CombatLog`; delete
   the HP-diff path; rewrite the helper's unit tests. *After this, one canonical number set.*
4. **Capability 4** — live HUD readout.
5. **Capability 5** — post-fight screen (report · log · continue).

Stop after step 3 and the data layer + single source of truth are complete; 4–5 surface it.

---

## Testing

- **GUT units (`CombatLog`):** fires increment per item; damage/heal/block accumulate per
  source + in totals; timeline records `t` · type · amount in order; throws log + carry the
  def id; side tagging correct (the same `name_key` on both sides stays separate); null/
  unknown source falls back cleanly.
- **`Actor`:** `take_damage` returns net-after-block, capped on a killing blow; `heal`
  returns post-cap healed.
- **Single source of truth:** the autotest report numbers come from `CombatLog`. Blast
  radius (confirmed against the suite): **`test_auto_test_logger.gd` is ~10 unit tests of
  the `attribute_damage` / `_split_remainder` HP-diff helper** — deleted with the helper
  and **rewritten** as `CombatLog` tests (direct per-tick attribution has no proportional
  weight-split, so those cases become moot, by design — more correct, note it in the
  as-built doc). The **E2E** tests (`test_auto_test_run.gd`) assert `total_damage > 0`,
  cross-seed **equality** (determinism), `fires_by_item` non-empty, and
  `block_by_item[armor] > 0` — **not exact damage** — so they stay green once sourced from
  `CombatLog` (the side-aware `block_by_item` must key the armor under the player side).
- **Autotest E2E** stays green (`--nosave --notutorial`).

---

## Dependencies / files touched

- **New `src/combat/combat_log.gd`** — the sink (Cap 1) + the source of truth (Design B).
- **`src/combat/combat_manager.gd`** — `var combat_log` + the six write calls + throw log;
  capture the new `take_damage` / `heal` returns; the DoT log in `_advance_statuses_on`.
- **`src/combat/actor.gd`** — `take_damage` / `heal` return the HP delta (Cap 3).
- **`src/autotest/auto_test_mode.gd` / `auto_test_logger.gd`** — read `CombatLog`; delete
  `_observe_damage` / `_observe_support` / HP snapshots / `attribute_damage` /
  `_split_remainder` (Design B).
- **`src/scenes/combat/combat_view_framed.*`** — live totals readout (Cap 4).
- **`src/scenes/screens/`** — a post-fight screen + the run-screen FSM hook (Cap 5).
- **Docs (same change):** new **`docs/systems/combat_log.md`** (as-built, incl. the
  single-source-of-truth note) + a row in **`docs/index.md`**; note the observer + the
  `Actor` return values in **`combat_manager.md`** / **`actor.md`** / **`autotest.md`** +
  the hub interface contract.

## Open / deferred

- **Source-of-truth precondition (verify before deleting the HP-diff path).** Direct
  emission only sees HP changes routed through `Actor.take_damage` / `heal` (the logged
  sites); the old HP-diff path saw **any** HP delta. Audit for any **in-combat** HP
  mutation that pokes `hp` directly (e.g. a relic's direct `Actor` modification) — route it
  through `take_damage` / `heal` so the log catches it, or the totals under-count. (Out-of-
  combat HP economy — `RunManager` between-act heal, max-HP growth — is correctly excluded:
  no fight is live, nothing to log.)
- **Post-fight screen on a loss** — the win path is `resolved → SUMMARY → draft`. On a
  **loss** the run ends (death screen); decide whether the summary shows first
  (summary-then-death) or is skipped. Default: skip on loss (death screen as today);
  confirm with the owner.
- **Block status id** — use **`BlockStatus.ID`** (`src/content/statuses/block_status.gd`,
  = `'block'`), not a literal, in the shield-detection branch (Cap 2 site 5).
- **Replay / scrub — cut.** The ordered `events` timeline is captured and shown as the
  event log, but the fight is **not** re-runnable or scrubbable. Cut deliberately: combat
  effects that reach into run-state make a faithful re-sim disproportionately complex. Not
  planned; noted only so the data shape doesn't accidentally foreclose it later.
