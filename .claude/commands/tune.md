Combat & draft tuning — balance items, enemies, and encounters so every pick pulls its weight and fights resolve.

> **Status: scaffolding.** The autotest harness, the draft-strategy AI, and the tunable content (item / enemy / encounter JSON) don't exist yet — this is the workflow, ready for when they do. See [`docs/testing/autotest.md`](../../docs/testing/autotest.md). Model: `../a-machine/.claude/commands/tune.md`.

## Tuning philosophy

**Goals (priority order):**
1. **Fights resolve in window** — regular ~10–15s, elites/bosses longer. No fight that *can't* end (the design's "mutual engine never resolves" failure).
2. **Every draft pick pulls its weight** — no trap picks; each item meaningfully contributes in its era (the design's "trace an early pickup still feeding the cascade" test).
3. **The damage / block / scaling triad stays live** — damage matters early, block throughout, scaling later; no axis collapses.
4. **No family dominates or is irrelevant in its era** — poison / burn / block / heal etc.

**Two levers — keep them separate:**
- **Draft weight / rarity** controls *when / how often* an item appears (timing lever).
- **Item value** (and enemy HP / loadout) controls *how much* it contributes (balance lever).

Don't tune value to fix appearance-rate, or vice versa. (Rarity is complexity, not power — see `design.md`.)

## Before starting

Read: the autotest spec (`docs/testing/autotest.md`), the relevant system PRDs (`docs/project/item_prd.md`, `enemy_prd.md`, `combat_manager_prd.md`), the item / enemy / encounter content + its JSON (when it exists), the tuning log, and past run reports.

## Parameters

- Item **values** + **draft weights** — item JSON.
- Enemy **HP** + **loadouts** — enemy JSON.
- Encounter **composition** — encounter JSON.

## Workflow

### 1. Evaluate
Run the autotest with a strategy and read the report:
```bash
godot --headless --path . -- --autotest --nosave --notutorial --seed 42 --speed 20 --encounters <N> --strategy <S> --timeout <game_s> --wall-timeout <real_s> --report runs/NNN-<desc>.md
```
For each act / era, check:
- Do fights resolve in their window?
- Is every drafted item contributing meaningful damage/block/scaling?
- Is any family dominating or ignored in this window?
- Is the damage/block/scaling triad live?

### 2. Balance (one thing at a time)
Pick the worst offender; adjust **its value OR its draft-weight** — not both for the same symptom:
- Item never picked → draft-weight or value too low vs alternatives.
- Item dominates → value too high.
- Fight won't resolve → too little damage vs enemy HP, or block out-scales incoming → enemy HP / item value.
- Dead era (nothing worth drafting) → missing or over-costed content in that window.

### 3. Document
Update the tuning log; add to a learnings doc if there's a new insight.

## After every run

Print the report's key tables **in full** (every encounter — never summarize): per-encounter HP attrition, damage-by-family, item contribution / efficiency, fight durations vs window.

## Parallel experiments

Dispatch the [`tune-run`](../agents/tune-run.md) subagent to apply a parameter set, run the autotest, and report back — one agent per experiment.

ARGUMENTS: $ARGUMENTS
