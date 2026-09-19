# Dark Corridor — Combat Log (as-built)

The per-fight **observation log**: a combat-scoped sink the [Combat manager](combat_manager.md)
writes to at each mutation site (damage / heal / shield / status / fire / charge / throw), and the
**single source of truth** for combat numbers — the [autotest](autotest.md) reads it instead
of reconstructing tallies from HP diffs. Session-only, combat-scoped, gone at fight teardown.

**Engine:** Godot 4. **Built:** 2026-06-21 (data layer + presentation: the live HUD readout +
the combat report — see *Presentation*). Plan lineage: `docs/plans/combat_log.md`.

---

## What it is

`class_name CombatLog extends RefCounted` (`src/combat/combat_log.gd`) — a pure tally +
ordered timeline, unit-testable on synthetic input. It is a **direct-write observer, not an
[event-bus](combat_manager.md#the-trigger-event-bus) listener**: the bus's listener signature
`(data, source_actor, source_item)` carries no amount and no timestamp, `data` is the trigger
filter key (it can't also carry shield's value), and DoT publishes no event at all. So the
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

- **Per-item:** `fires_by_item`, `damage_by_item` (net, **direct hits only**), `gross_by_item`
  (pre-mitigation), `healing_by_item`, `shield_by_item`, `statuses_by_item` (count of non-shield
  statuses applied — the item's attributable contribution to a status).
- **Per-status:** `damage_by_status` (net) — DoT / cash-out (Bleed) damage, bucketed by the
  **status's own `name_key`**, not the applier item (see *Status damage is by-status* below).
- **Totals (per side):** `total_damage_dealt` / `total_damage_taken` (net), `total_gross`
  (pre-mitigation dealt), `total_healing`, `total_shield`. Status damage still folds into these —
  only its per-item *breakdown* is replaced by the per-status one.
- A **source-less DIRECT hit** (a thrown consumable's damage — no source item) falls to the
  generic `CombatLog.SOURCELESS` (`'Poison'`) bucket on the dealer's side. Status damage never
  needs this fallback — it always keys by the status's own name.

`summary(side)` flattens one side's per-item rows (Item · Fires · Damage · Shield · Healing ·
Statuses) — the union of every item that did anything on that side; `status_damage(side)` returns
the per-status damage rows (Status · Damage). Both view `tr(name_key)` at draw; the log never
stores display strings (localization).

### Status damage is by-status (why per-applier was a fiction)

DoT / cash-out damage is bucketed by the **status**, not credited to the applier item. Appliers of
the same status (same `id` + `flags`) **merge into one instance** and the merge keeps the **first**
applier as `source` ([status_manager.md](status_manager.md)) — so a per-item DoT credit dumps the
*whole* stack's damage on whoever applied it first the moment a second item feeds the pool. The
honest split the log keeps instead: **the item applied the status N times** (`statuses_by_item`) +
**the status dealt N damage overall** (`damage_by_status`). Direct hits stay per-item (exact and
attributable); only status damage moves.

---

## Write methods + the timeline

Eight manager-called writers, each taking resolved `name_key`s + side + `sim_time`:
`on_item_fired`, `on_damage`, `on_status_damage`, `on_heal`, `on_shield`, `on_status_applied`,
`on_charge`, `on_throw`. `on_damage` is the **direct-hit** writer (credits the item); `on_status_damage` is the
**DoT / cash-out** writer (credits the status's `name_key`, carries the status `id` on the event
`data`). Every write also appends to the ordered **`events`** timeline (append order = sim order) —
the post-fight event log. Each entry: `{ t, type, source, source_side, target, amount, data }`,
`type` in fire / damage / heal / shield / status / charge / throw; `data` holds the status id (a
status tick or a status apply) or thrown consumable id (throw). The amount writers ignore a
non-positive amount (record nothing, append no event).

`on_charge` is the [charge and decharge](mechanics.md#charge-and-decharge) writer: `amount` is the
seconds of cooldown progress actually applied to the target item, negative for a decharge, and
`target` is that item's `name_key`. It keeps no per-item tally, because charge moves no health,
shield or status, and it records nothing when the seconds are zero.

The numbers are **honest** because `Actor.take_damage` / `Actor.heal` now return the actual HP
delta (see [actor.md](actor.md)) — post-shield, capped on a killing blow, post-overheal-cap —
so the log shows effective (net) damage/healing with no HP-diff machinery.

**Net vs gross.** `on_damage(…, net, t, raw)` records two numbers: **net** (effective HP
removed — the `take_damage` return) and **gross** (the pre-mitigation hit, `raw`; defaults to
net when omitted). Gross is recorded **even when shield absorbs the whole hit** (net 0), because
*incoming pressure* tuning needs the enemy's real threat — a shield-heavy build would otherwise
read every enemy as harmless. The autotest's "Incoming damage (gross, by enemy item)" report is
the enemy side's gross; net survivability is the per-encounter HP attrition. The direct-damage
land site passes `raw = d.value`; a DoT tick has no pre-shield value to hand, so its gross
defaults to net (enemy DoT through player shield is an uncommon edge — flagged, not solved).
`on_status_damage` still accrues `total_gross` (so total incoming stays complete), but enemy
status pressure (Bleed / enemy poison) is attributed **per status** — the autotest's "Incoming
damage" report breaks it out under a `[status]` line, not per enemy item.

---

## Single source of truth (Design B)

`CombatLog` is **the** damage/heal/shield/fire tally; the autotest no longer reconstructs it.
The manager writes the log at each mutation site (see [combat_manager.md](combat_manager.md)),
the autotest attaches a `CombatLog` before its `sim_step()` loop and reads the player side at
fight end, and the [logger](autotest.md) sources its `fires_by_item` / `damage_by_item` /
`shield_by_item` / `healing_by_item` + totals from it. The old HP-diff path
(`AutoTestLogger.attribute_damage` / `_split_remainder`, the per-step HP snapshots,
`_observe_damage` / `_observe_support`) is **deleted**.

**Attribution is more honest, not just unified.** The old path split a multi-DoT remainder
*proportionally by weight* across appliers. Direct emission logs each DoT tick at its source
(`_advance_statuses_on` / `_drain_actor_fire_statuses`) — but it credits the **status**, not the
applier item, because appliers of one status merge to a single instance (first-applier-kept), so a
per-item DoT credit was a fiction (see *Status damage is by-status*). Shield-absorbed and
killing-blow numbers already matched (both are net-after-shield HP delta — `Actor.take_damage`'s
return).

**Precondition:** direct emission only sees HP routed through `take_damage` / `heal` (the
logged sites). Any in-combat HP poke straight to `Actor.hp` would under-count; route it through
`take_damage` / `heal` instead. (Out-of-combat HP economy — between-act heal, max-HP growth —
is correctly excluded: no fight is live.)

---

## Presentation (built)

Both surfaces read the live log; the run screen owns its lifetime (`run_screen.gd` creates a
`CombatLog` per fight, assigns it to the live `CombatManager.combat_log`, and keeps the last
finished fight's log in `_last_log`, so the report still reads after the manager's teardown
nulls its side). See [run_screen.md](run_screen.md).

- **Live HUD readout** — `combat_stats_readout.tscn` on the run-screen HUD: the player's
  running *Dealt · Taken* (net) this fight, refreshed each tick. Shown only while FIGHTING.
- **Combat report** — `combat_summary.tscn`, raised and dismissed by the **Report** button in the
  run screen's information section. It shows the **last finished fight** and parks nothing: a fight
  resolves straight on to the reward draft, and the button stays available through the beats that
  follow. Shows the player per-item damage report (Item · Fires · Damage · Shield · Healing, from
  `summary(PLAYER)` — Damage is **direct hits only**), a **Status damage** section (Status ·
  Damage, from `status_damage(PLAYER)`, hidden when no status dealt damage), and the ordered
  event-log timeline (from `events`), with a Close button.

## Deferred / cut

- **Replay / scrub** — cut deliberately (combat effects reach into run-state; a faithful
  re-sim is disproportionately complex). The `events` timeline is captured + shown as the
  event log, but the fight is not re-runnable.
