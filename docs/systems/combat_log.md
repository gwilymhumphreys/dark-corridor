# Dark Corridor — Combat Log (as-built)

The per-fight **observation log**: a combat-scoped sink the [Combat manager](combat_manager.md)
writes to at each mutation site (damage / heal / shield / status / fire / throw), and the
**single source of truth** for combat numbers — the [autotest](autotest.md) reads it instead
of reconstructing tallies from HP diffs. Session-only, combat-scoped, gone at fight teardown.

**Engine:** Godot 4. **Built:** 2026-06-21 (data layer + presentation: the live HUD readout +
the post-fight summary screen — see *Presentation*). Plan lineage: `docs/plans/combat_log.md`.

---

## What it is

`class_name CombatLog extends RefCounted` (`src/combat/combat_log.gd`) — a pure tally +
ordered timeline, unit-testable on synthetic input. It is a **direct-write observer, not an
[event-bus](combat_manager.md#the-trigger-event-bus) listener**: the bus's listener signature
`(data, source_actor, source_item)` carries no amount and no timestamp, `data` is the trigger
filter key (it can't also carry block's value), and DoT publishes no event at all. So the
manager hands the log the full rich data — amount + resolved `name_key`s + side + `sim_time` —
at the exact mutation site, with zero risk to the loop-proof trigger core.

**Stores no game-object references.** Every write resolves to `name_key` strings, ids, side
ints, and primitives at write time and drops the object — so the log never joins the
`Actor`<->`Item` RefCounted cycle and has nothing to tear down (cf. CLAUDE.md runtime cleanup).

---

## Side-awareness (why tallies aren't keyed by name alone)

Per-item tallies are nested **`side -> name_key -> value`**, not flat `name_key`. A colorless
item can sit on **both** sides, so a flat key would conflate the player's copy with the
enemy's; and the player report + the autotest contribution table want **player-side only**.
`Side` is an enum (`PLAYER` / `ENEMY`); the manager resolves it per write via `_on_player_side`.

- **Per-item:** `fires_by_item`, `damage_by_item` (net), `gross_by_item` (pre-mitigation),
  `healing_by_item`, `block_by_item`, `statuses_by_item` (count of non-block statuses).
- **Totals (per side):** `total_damage_dealt` / `total_damage_taken` (net), `total_gross`
  (pre-mitigation dealt), `total_healing`, `total_block`.
- A **source-less DoT** (a damaging status with no applier item — enemy-supplied or item-less)
  falls to the generic `CombatLog.SOURCELESS` (`'Poison'`) bucket on the dealer's side.

`summary(side)` flattens one side's per-item rows (Item · Fires · Damage · Block · Healing ·
Statuses) — the union of every item that did anything on that side. Views `tr(name_key)` at
draw; the log never stores display strings (localization).

---

## Write methods + the timeline

Six manager-called writers, each taking resolved `name_key`s + side + `sim_time`:
`on_item_fired`, `on_damage`, `on_heal`, `on_block`, `on_status_applied`, `on_throw`. Every
write also appends to the ordered **`events`** timeline (append order = sim order) — the
post-fight event log. Each entry: `{ t, type, source, source_side, target, amount, data }`,
`type` in fire / damage / heal / block / status / throw; `data` holds the status id (status)
or thrown consumable id (throw). `on_damage` / `on_heal` / `on_block` ignore a non-positive
amount (records nothing, appends no event).

The numbers are **honest** because `Actor.take_damage` / `Actor.heal` now return the actual HP
delta (see [actor.md](actor.md)) — post-block, capped on a killing blow, post-overheal-cap —
so the log shows effective (net) damage/healing with no HP-diff machinery.

**Net vs gross.** `on_damage(…, net, t, raw)` records two numbers: **net** (effective HP
removed — the `take_damage` return) and **gross** (the pre-mitigation hit, `raw`; defaults to
net when omitted). Gross is recorded **even when block absorbs the whole hit** (net 0), because
*incoming pressure* tuning needs the enemy's real threat — a block-heavy build would otherwise
read every enemy as harmless. The autotest's "Incoming damage (gross, by enemy item)" report is
the enemy side's gross; net survivability is the per-encounter HP attrition. The direct-damage
land site passes `raw = d.value`; a DoT tick has no pre-block value to hand, so its gross
defaults to net (enemy DoT through player block is an uncommon edge — flagged, not solved).

---

## Single source of truth (Design B)

`CombatLog` is **the** damage/heal/block/fire tally; the autotest no longer reconstructs it.
The manager writes the log at each mutation site (see [combat_manager.md](combat_manager.md)),
the autotest attaches a `CombatLog` before its `sim_step()` loop and reads the player side at
fight end, and the [logger](autotest.md) sources its `fires_by_item` / `damage_by_item` /
`block_by_item` / `healing_by_item` + totals from it. The old HP-diff path
(`AutoTestLogger.attribute_damage` / `_split_remainder`, the per-step HP snapshots,
`_observe_damage` / `_observe_support`) is **deleted**.

**Attribution is more correct, not just unified.** The old path split a multi-DoT remainder
*proportionally by weight* across appliers; direct emission credits **each DoT tick to its own
status's source exactly** (logged in `_advance_statuses_on`). Block-absorbed and killing-blow
numbers already matched (both are net-after-block HP delta — `Actor.take_damage`'s return).

**Precondition:** direct emission only sees HP routed through `take_damage` / `heal` (the
logged sites). Any in-combat HP poke straight to `Actor.hp` would under-count; route it through
`take_damage` / `heal` instead. (Out-of-combat HP economy — between-act heal, max-HP growth —
is correctly excluded: no fight is live.)

---

## Presentation (built)

Both surfaces read the live log; the run screen owns its lifetime (`run_screen.gd` creates a
`CombatLog` per fight, assigns it to the live `CombatManager.combat_log`, and retains a ref so
the summary can read it after the manager's teardown nulls its side). See
[run_screen.md](run_screen.md).

- **Live HUD readout** — `combat_stats_readout.tscn` on the run-screen HUD: the player's
  running *Dealt · Taken* (net) this fight, refreshed each tick. Shown only while FIGHTING.
- **Post-fight summary** — `combat_summary.tscn`, a `SUMMARY` FSM state parked before the draft
  on a **won, non-final** fight (a loss / final win ends the run → the outcome screen instead).
  Shows the player per-item damage report (Item · Fires · Damage · Block · Healing, from
  `summary(PLAYER)`) + the ordered event-log timeline (from `events`), with a Continue button.

## Deferred / cut

- **Replay / scrub** — cut deliberately (combat effects reach into run-state; a faithful
  re-sim is disproportionately complex). The `events` timeline is captured + shown as the
  event log, but the fight is not re-runnable.
