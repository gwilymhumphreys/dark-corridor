# Dark Corridor — Phase 5 Build Plan (tune machinery)

> **A build plan, not a spec.** Sits under [decision-log.md](decision-log.md) →
> *Build order* step 2.5 (scale content + `tune`), on top of Phases 1–4. The
> `tune` workflow + `tune-run` agent already exist as scaffolding
> ([`.claude/commands/tune.md`](../../.claude/commands/tune.md)); this builds the two
> things they need to function.

**Engine:** Godot 4.6.
**Date:** 2026-06-06.
**Status: IN PROGRESS.**

## Scope (resolved with the user 2026-06-06)

**Machinery first, content later.** `tune` needs three things; the harness + a
content pool exist, so Phase 5's first bite is the missing two:

1. **Draft strategies** — the `AutoTestDriver` is a stub (picks candidate 0).
   Build real, *seeded* strategies so `--strategy` is live and the harness can
   play *different builds* (the `tune` "build viability" lever).
2. **A richer per-encounter report** — the logger tallies run-wide damage-by-family;
   `tune` needs **per-encounter** breakdowns (duration vs window, HP attrition) and
   **per-item contribution** (so trap picks / dead items show up).

**Deferred to a follow-up:** scaling the content pool. When it comes, the archetype
focus is **raw damage + scaling** (the cascade enabler — workhorse damage commons +
a multiplier/scaling rare). The machinery is built to support that (a `damage`/
`scaling` strategy + per-item contribution are exactly what reveal whether a scaling
rare is pulling its weight).

> **Note on the small pool.** With 4 draftable items / 1 enemy / 3 fights the
> strategies + report are somewhat degenerate — that's expected and fine: we build
> the machinery now, prove it runs, and it becomes meaningful as content scales.

## Discipline (unchanged)

Test-first; each step green headless before the next; commit each green step; no
self-attribution. The autotest stays deterministic by `--seed`. Update
[`autotest.md`](../testing/autotest.md) as the "deferred" notes become "built".

## Build order

### Step 1 — Draft strategies (the Driver)

Replace the stub `choose_draft` with seeded strategies, scored against the candidate
and the **current board** (so synergy/family strategies are real). Make `--strategy`
live in `run_full`.

- **Strategies:** `first-viable` (0, the default), `random` (seeded), `damage` /
  `block` / `poison` (prefer that effect family), `greedy-synergy` (prefer a candidate
  that connects to the board — its trigger keys off a status the board applies, or the
  board has a trigger keyed off a status it applies). `scaling` / `burn` are named but
  **alias to the nearest present family** until their content exists (documented).
- **Seam:** `AutoTestDriver.new(strategy, seed)` owns a seeded RNG;
  `choose_draft(candidates, board) -> int`. The Mode passes `run.player.board`.
- **Files:** `src/autotest/auto_test_driver.gd`; `auto_test_mode.gd` (pass the board +
  seed). New tests `tests/autotest/test_draft_strategy.gd`.
- **Tests:** each strategy is deterministic by seed; `damage` prefers a damage
  candidate; `greedy-synergy` prefers a synergistic candidate over a non-connecting
  one; `random` is reproducible; two strategies can diverge.

### Step 2 — Per-encounter + per-item report

Extend the logger + mode so the report carries what `tune` reads "after every run":

- **Per-encounter records:** type, fight duration (sim-seconds vs the ~10–15s window),
  player HP before → after, outcome. (The mode already drives each beat; capture the
  HP/step deltas around each fight.)
- **Per-item contribution:** a per-item tally (damage dealt + **fire count**), so a
  drafted item that **never fired** is flagged a **trap pick**, and non-damage items
  (block/heal) aren't false-flagged (fire count, not damage, is the "did it do
  anything" signal).
- **Report:** add an *Encounters* table (beat · type · duration · HP before→after ·
  outcome) and an *Item contribution* table (item · fires · damage · trap?).
- **Files:** `src/autotest/auto_test_logger.gd`, `auto_test_mode.gd`. Tests in
  `tests/autotest/test_auto_test_logger.gd`.
- **Tests:** a per-encounter record captures duration + HP attrition; a never-fired
  drafted item is flagged a trap; the contribution tally sums per item.

### Step 3 — Wire-up + a tune smoke + docs

Run the autotest across a couple of strategies; confirm the report renders the new
tables and `--strategy` changes the descent. Update `autotest.md` (strategies +
report are **built**; drop the "deferred" tags) and the decision-log build status.

- **Tests:** the existing run-mode tests stay green across strategies; a smoke that
  `run_full` with two strategies produces two (possibly different) clean verdicts.

## Interfaces to lock

```
AutoTestDriver:  _init(strategy:String, seed:int)
                 choose_draft(candidates:Array, board:Array) -> int
AutoTestLogger:  record_encounter({beat,type,duration,hp_before,hp_after,outcome})
                 record_item_fire(item) · record_item_damage(item, amount)
                 (summarize/report gain encounters[] + item_contributions{})
```

## Explicitly NOT in Phase 5 (this bite)

Scaling the item / enemy / encounter pools (the deferred content push — raw damage +
scaling); elite/boss tiers + signature mechanics; events-with-prose; multi-act maps;
characters; meta. Those follow once the machinery can evaluate them.
