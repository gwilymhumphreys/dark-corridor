# AutoTest Mode — design & scaffolding

> **Status: Phase 5 — the tune machinery is built (2026-06-06).** The Mode/Driver/Logger trio in `src/autotest/` drives a whole headless descent (`Game → Run → Encounter → Combat`): start a seeded run, resolve each beat, take draft picks via the Driver, advance — `run_full()` is the default; `--single-fight` keeps the Phase-2 one-fight path. (The harness doesn't quit/resume mid-run itself; the deterministic-resume invariant is covered by GUT.) **The Driver now has real, seeded draft *strategies*** (`--strategy` is live), and **the report carries per-encounter + per-item breakdowns** — the two things the `tune` workflow needs. Still deferred: the content pool to tune (the raw-damage/scaling push), and the potion/choice decision AI. Modeled on `../a-machine`'s AutoTest (`a-machine/docs/systems/autotest.md`) + its `tune` workflow, adapted to this game.

AI-controlled E2E testing that plays the game **headlessly** (draft → fight → advance) for deterministic regression + balance testing.

---

## Why it (mostly) already fits the architecture

The harness falls out of decisions already made — "design it in" is cheap here:

- **The driver is just another input-intent source.** The [input/output split](architecture.md) has the `UI` emit *intents* (draft-pick, potion-throw, choice-point pick, event-option pick, timescale); the autotest driver emits the **same** intents headlessly. Combat is already automatic, so the driver only makes the few human decisions — it never "plays" a fight.
- **Headless = skip the output layer.** Renderer / VFX / audio are a pure function of handed state; a headless run just doesn't instantiate them. The logic (the Combat manager's fixed-step tick + the Timekeeper clock) runs unchanged.
- **Speed is the dial.** The [Timekeeper](timekeeper.md)'s `timescale` already has a fast-test value (×5+); `--speed N` sets it. Game-time behaviour is identical (everything scales off the one clock).
- **Determinism is seeded RNG.** The `Run manager` owns the run RNG, whose **full state** [`Save`](save.md) snapshots (#20); the harness seeds it (`--seed`) at run start. The tick's determinism constraint makes runs reproducible.
- **The logger reads handed state** — the same "wall" the VFX driver reads — as a structured-event + summary sink. It writes no game state.

## What the driver decides

Combat is automatic — the driver does **not** play fights. It makes the opt-in human choices:

- **Draft pick** — 1-of-3 each draft (the main lever; a-machine's "build archetypes" → here, **draft strategies**).
- **Choice-layer pick** — which encounter path (fight / elite / event / rest).
- **Event-option pick** — the binary choice inside a non-combat event.
- **Potion throw** — whether / when / which.

(Walk/advance is automatic.) Initially the driver is a **stub** (e.g. "pick the first viable draft, never throw potions"); real strategies come later.

## What's built (the structure)

The Mode/Driver/Logger trio in `src/autotest/`:

- **`AutoTestMode`** (`auto_test_mode.gd`, root of `autotest.tscn`) — entry: parse flags, force a fresh-user run (nosave / notutorial), seed, set the Timekeeper dial from `--speed`. **`run_full()`** (default) starts a seeded run via `Game.start_run`, then walks the descent — for each beat it begins the Encounter, steps a fight's `CombatManager.sim_step()` to a verdict (a CombatLog attached for the tallies + a per-fight stuck/timeout guard), takes the Driver's draft pick, and advances. **`run_once()`** (`--single-fight`) is the Phase-2 one-fight path. It enforces a per-fight game-time `--timeout`, a shared `--wall-timeout` hang watchdog, and stuck detection; sets the exit code and quits. Both `run_*` are tree-free + I/O-free, so GUT drives them in-process.
- **`AutoTestDriver`** (`auto_test_driver.gd`) — the decision seam. `choose_draft(candidates, board)` runs a **seeded strategy** scored against the current board: `first-viable` (index 0), `random` (seeded), family strategies (`damage` / `block` / `poison` — prefer that effect family), and `greedy-synergy` (prefer a candidate that connects to the board — a trigger on one half keyed off a status the other half applies; opponent-side-listening triggers score no own-board connection). The family list includes `heal`; `scaling` / `burn` alias to the nearest present family until their content exists. The event/potion methods are live but simple (seeded picks / a single early throw) — richer policies come with the content.
- **`AutoTestStuckDetector`** (`stuck_detector.gd`) — trips when combined actor HP is flat for a step threshold (the "fight that never resolves" guard), per fight.
- **`AutoTestLogger`** (`auto_test_logger.gd`) — structured events (run / encounter / draft / fight start+end) + per-item damage / fire / block / healing tallies + **per-encounter records** (duration vs the ~10–15s window, HP before→after, outcome) + **per-item contribution** (player board: fires + damage, with a never-fired item flagged a **trap pick** — fire-count, not damage, is the "did it do anything" signal so block/heal items aren't false-flagged; **block applied + healing done** are tallied per item, so defensive items are rankable) + a summary + a markdown report stamped with its **seed + strategy** (incl. an *Encounters* table and an *Item contribution* table — what `tune` reads after every run). Reads handed state, writes no game state. **The damage / fire / block / healing numbers are the [CombatLog](combat_log.md)'s — the single source of truth.** The logger ingests each fight's **player-side** CombatLog (`ingest_combat_log`) at fight end; there is no HP-diff reconstruction. Each item is its own channel (a DoT applier like Venom Fang shows ITS damage, not a generic lump), because the CombatManager logs each DoT tick to its own status's source at the mutation site — **exact** per-applier attribution, not a proportional weight-split. The old `attribute_damage` / `_split_remainder` helper + the per-step HP snapshots / `_observe_damage` / `_observe_support` are deleted (Design B).

### How to run

```
# a full headless run (default)
<godot> --headless --path . res://src/autotest/autotest.tscn -- \
        --autotest --seed 1 --speed 5 --timeout 120 --wall-timeout 30

# just one fight (the Phase-2 path)
<godot> --headless --path . res://src/autotest/autotest.tscn -- --autotest --single-fight
```

Each run writes a raw log + a markdown report to **`autotest_results/`** (project-local, git-ignored) — `--log <path>` / `--report <path>` override. A **dedicated scene** (not an autoload), so nothing presentational mounts and the corridor testbed stays the normal `main_scene`. **`--seed` is now live** in run mode (it seeds the run RNG → deterministic drafts/descent). **`--speed`** stays plumbed-but-inert (the direct `sim_step` loop advances one STEP per call regardless of the dial). Exit `0` = the run **ended cleanly** (won or died) or hit the `--encounters` cap; exit `1` = a fight **failed to resolve** (stuck / game-timeout / wall-timeout). The harness asserts the sim runs to a clean conclusion, not who wins (that becomes `tune`'s job).

## Flags (adapted from a-machine)

| Flag | Meaning |
|------|---------|
| `--autotest` | enable the mode |
| `--seed N` | RNG seed (determinism) |
| `--speed N` | sets the Timekeeper dial (fast-test); game-time identical |
| `--encounters N` | cap the run at N beats (0 / omitted = play the whole map) |
| `--single-fight` | run one fight instead of a full run (the Phase-2 path) |
| `--strategy S` | draft strategy: `first-viable` (default) · `random` · `damage` / `block` / `poison` (family) · `greedy-synergy` (+ `scaling`/`burn` aliases). **Live** (seeded). |
| `--timeout N` | max game-seconds before fail |
| `--wall-timeout N` | max real-seconds (hang watchdog) |
| `--character C` | starting character |
| `--log PATH` / `--report PATH` | raw events / markdown analysis |
| `--nosave --notutorial` | always (fresh-user run); `nosave` disables `Save.write` so a headless run never clobbers the real run slot |
| `--headless` | Godot flag (before `--`) |

**Live now:** `--autotest --seed --speed --timeout --wall-timeout --encounters --single-fight --strategy --log --report` (+ forced nosave / notutorial). `--seed` is live in run mode (seeds the run RNG + the Driver's strategy RNG); `--strategy` is live (real seeded draft strategies); `--speed` stays inert (the direct `sim_step` loop ignores the dial). `--acts / --character` arrive with multi-act maps + characters (later).

## What it tests (real design risks)

- **Fights resolve** — stuck detection catches a combat that never ends (the design's "mutual engine never resolves" worry).
- **Build viability** — does a draft strategy reach act N / beat a boss? (the cascade actually works).
- **Balance** — two lenses: *offense* (per-item damage dealt + the player-board contribution table) and *incoming pressure* (**Damage taken by enemy source** + per-encounter HP attrition) → feeds tuning. Both come from the per-fight `CombatLog` ([combat_log.md](combat_log.md)).
- **Regression / perf** — after changes to combat / items / statuses; headless throughput.
- Exit `0` (pass) / `1` (fail) for CI.

## Stuck detection

A fight is stuck when the combined HP of every live body — both sides, allies and summon tokens included — stays flat for `stuck_threshold_seconds` of game-time (no CLI flag; the per-fight `--timeout` catches oscillating stalls). HP-flatness is the whole check: a fight making any HP progress never trips it. On a trip, the stall's length is logged (`flat_steps`). Directly guards the "fight that can't resolve" failure mode.

## Tuning — the `tune` workflow (later)

Modeled on a-machine's `tune` command + `tune-run` subagent: run the harness with a `--strategy`, read the report, adjust balance numbers (item values / draft weights / enemy HP + loadouts, in the GDScript catalogs), repeat — **one milestone at a time**, with **cost (when) and value (how much) kept as separate levers**, documented in a tuning log. **The machinery is built** (the seeded strategies + the per-encounter / per-item report feed it); what remains before a real tune pass is **bite-worth of tunable content** (more items / enemies / a longer map — the deferred raw-damage/scaling push). (Model: `../a-machine/.claude/commands/tune.md`.)

## Prototype scope

**Built:** the full Mode/Driver/Logger trio + the live flags (see *What's built* and *Flags* above). It runs "draft → fight → advance × N" over the multi-act map headless, deterministically by seed, and asserts the descent resolves. (The harness never quits/resumes itself; the resume invariant is GUT-covered.) **Still deferred:** the potion/event decision AI beyond the seeded stubs, and the `tune` skill itself.

## Open / deferred

- **The decision AI** — draft strategies are **built** (seeded, board-aware); the event/potion policies are live but simple (a seeded option pick / one early throw) — richer policies come with the content.
- **Family classifier gaps (`AutoTestDriver._family_of`)** — the draft-strategy family classifier covers `damage` / `block` / `poison` / `heal` / `status`; **`SUMMON` and `CREATE_ITEM` fall to `'other'`**, so no family strategy prefers a summon-primary or create-primary item (a damage item with a summon / create *rider* is fine — its primary effect classifies). Add families when such content is authored ([`item_creation_and_decay.md`](item_creation_and_decay.md)). Left unchanged for now — no such content exists (owner, 2026-06-19).
- **The `tune` skill** — the command + experiment-runner subagent. The machinery (strategies + report) feeds it now; a real pass waits on tunable content.
- **Report contents** — which metrics / charts — settle as combat metrics exist.
