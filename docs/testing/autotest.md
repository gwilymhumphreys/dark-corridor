# AutoTest Mode — design & scaffolding

> **Status: Phase 3 built (2026-06-05) — drives a full run.** The Mode/Driver/Logger trio in `src/autotest/` now drives a whole headless descent (`Game → Run → Encounter → Combat`): start a seeded run, resolve each beat, take draft picks via the Driver, advance, with quit/resume — `run_full()` is the default; `--single-fight` keeps the Phase-2 one-fight path. The Driver is still a no-op-ish stub (it picks the first draft candidate); real draft *strategies* and the `tune` skill are deferred. Modeled on `../a-machine`'s AutoTest (`a-machine/docs/testing/autotest.md`) + its `tune` workflow, adapted to this game.

AI-controlled E2E testing that plays the game **headlessly** (draft → fight → advance) for deterministic regression + balance testing.

---

## Why it (mostly) already fits the architecture

The harness falls out of decisions already made — "design it in" is cheap here:

- **The driver is just another input-intent source.** The [input/output split](../project/architecture.md) has the `UI` emit *intents* (draft-pick, potion-throw, choice-point pick, event-option pick, timescale); the autotest driver emits the **same** intents headlessly. Combat is already automatic, so the driver only makes the few human decisions — it never "plays" a fight.
- **Headless = skip the output layer.** Renderer / VFX / audio are a pure function of handed state; a headless run just doesn't instantiate them. The logic (the Combat manager's fixed-step tick + the Timekeeper clock) runs unchanged.
- **Speed is the dial.** The [Timekeeper](../project/timekeeper_prd.md)'s `timescale` already has a fast-test value (×5+); `--speed N` sets it. Game-time behaviour is identical (everything scales off the one clock).
- **Determinism is seeded RNG.** The `Run manager` owns the run RNG, whose **full state** [`Save`](../project/save_prd.md) snapshots (#20); the harness seeds it (`--seed`) at run start. The tick's determinism constraint makes runs reproducible.
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

- **`AutoTestMode`** (`auto_test_mode.gd`, root of `autotest.tscn`) — entry: parse flags, force a fresh-user run (nosave / notutorial), seed, set the Timekeeper dial from `--speed`. **`run_full()`** (default) starts a seeded run via `Game.start_run`, then walks the descent — for each beat it begins the Encounter, steps a fight's `CombatManager.sim_step()` to a verdict (per-step damage observation + a per-fight stuck/timeout guard), takes the Driver's draft pick, and advances. **`run_once()`** (`--single-fight`) is the Phase-2 one-fight path. It enforces a per-fight game-time `--timeout`, a shared `--wall-timeout` hang watchdog, and stuck detection; sets the exit code and quits. Both `run_*` are tree-free + I/O-free, so GUT drives them in-process.
- **`AutoTestDriver`** (`auto_test_driver.gd`) — the decision seam. `choose_draft()` is exercised (picks the first candidate); choice/event/potion methods are stubs until those beats exist. Real seeded *strategies* are deferred.
- **`AutoTestStuckDetector`** (`stuck_detector.gd`) — trips when combined actor HP is flat for a step threshold (the "fight that never resolves" guard), per fight.
- **`AutoTestLogger`** (`auto_test_logger.gd`) — structured events (run / encounter / draft / fight start+end) + a damage-by-family tally + a summary + a markdown report. Reads handed state, writes no game state. Damage-by-family is built per step from net HP loss + the Deliveries that landed that step (direct hits → the source item's family; the unexplained remainder → the DoT/poison channel, which lands no Delivery yet); it accumulates across all of a run's fights.

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
| `--strategy S` | draft strategy (a-machine's `--build`; e.g. `poison`, `block`, `random`, `greedy-synergy`). **Deferred** — stub picks the first candidate |
| `--timeout N` | max game-seconds before fail |
| `--wall-timeout N` | max real-seconds (hang watchdog) |
| `--character C` | starting character |
| `--log PATH` / `--report PATH` | raw events / markdown analysis |
| `--nosave --notutorial` | always (fresh-user run) |
| `--headless` | Godot flag (before `--`) |

**Live now:** `--autotest --seed --speed --timeout --wall-timeout --encounters --single-fight --strategy --log --report` (+ forced nosave / notutorial). `--seed` is live in run mode (seeds the run RNG); `--speed` stays inert (the direct `sim_step` loop ignores the dial); `--strategy` is stored on the Driver but unused until it has real choices. `--acts / --character` arrive with multi-act maps + characters (later).

## What it tests (real design risks)

- **Fights resolve** — stuck detection catches a combat that never ends (the design's "mutual engine never resolves" worry).
- **Build viability** — does a draft strategy reach act N / beat a boss? (the cascade actually works).
- **Balance** — per-encounter HP attrition, damage-by-family, item contribution → feeds tuning.
- **Regression / perf** — after changes to combat / items / statuses; headless throughput.
- Exit `0` (pass) / `1` (fail) for CI.

## Stuck detection

A run is stuck if no progress within `STUCK_THRESHOLD` game-seconds: no damage dealt, no HP change, no draft / encounter advance. Directly guards the "fight that can't resolve" failure mode.

## Tuning — the `tune` workflow (later)

Modeled on a-machine's `tune` command + `tune-run` subagent: run the harness, read the report, adjust balance numbers (item / enemy / encounter JSON), repeat — **one milestone at a time**, with **cost (when) and value (how much) kept as separate levers**, documented in a tuning log. **Deferred** until there's tunable content and a working harness; the logger / report is designed now to feed it. (Model: `../a-machine/.claude/commands/tune.md`.)

## Prototype scope

**Built (Phase 2 → 3):** `AutoTestMode` (`run_once` + `run_full`) + `AutoTestDriver` (picks the first draft) + `AutoTestStuckDetector` + `AutoTestLogger` (run/encounter/draft events + duration + HP + damage-by-family + a markdown report) + `--seed --speed --timeout --wall-timeout --encounters --single-fight` (nosave / notutorial forced) + stuck detection + exit code. It runs "draft → fight → advance × N" over the run loop headless, deterministically by seed, with quit/resume, and asserts the descent resolves. **Still deferred:** real draft *strategies*, multi-act maps (`--acts`), characters, and the `tune` skill.

## Open / deferred

- **The decision AI** — draft strategies, potion / choice policies. Stub now.
- **The `tune` skill** — the command + experiment-runner subagent. Design the logger/report to feed it; build later.
- **Report contents** — which metrics / charts — settle as combat metrics exist.

## Hooks (already in the architecture — nothing new needed)

- **Input-intent layer** (Combat manager / Run manager inbound) — the driver emits the same intents the UI does.
- **Timekeeper dial** → `--speed`. **Seedable run RNG** (`Run` owns it; `Save` snapshots its full state) → `--seed`.
- **Game manager** starts / ends the run (the harness drives it); the **Run manager** drives the encounter sequence the harness steps through and exposes run state for logging.
- **Output layer** is skipped headless — logic runs without renderer / VFX / audio.
