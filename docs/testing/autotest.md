# AutoTest Mode — design & scaffolding

> **Status: Phase 2 built (2026-06-05) — a single headless fight.** The Mode/Driver/Logger trio lives in `src/autotest/` and drives one deterministic fight to a verdict (see *What's built* + *How to run* below). The decision AI (draft strategies) and the `tune` skill are still deferred; the Driver is a no-op stub until the run loop (Phase 3) gives it choices to make. Modeled on `../a-machine`'s AutoTest (`a-machine/docs/testing/autotest.md`) + its `tune` workflow, adapted to this game.

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

## What's built (Phase 2 — the structure)

The Mode/Driver/Logger trio in `src/autotest/`, scoped to one fight (no run loop yet):

- **`AutoTestMode`** (`auto_test_mode.gd`, root of `autotest.tscn`) — entry: parse flags, force a fresh-user run (nosave / notutorial), seed the RNG, set the Timekeeper dial from `--speed`, build a player-vs-grunt fight from the catalogs, and drive `CombatManager.sim_step()` directly (no `_physics_process`, no real time → bit-reproducible). Enforces the game-time `--timeout`, the `--wall-timeout` hang watchdog, and stuck detection; sets the exit code and quits. Its `run_once()` is tree-free + I/O-free, so a GUT test drives a full headless fight in-process.
- **`AutoTestDriver`** (`auto_test_driver.gd`) — the decision seam, a **no-op stub**: a single fight has no draft / choice / event / potion decisions. Real seeded strategies arrive with the run loop (Phase 3).
- **`AutoTestStuckDetector`** (`stuck_detector.gd`) — trips when combined actor HP is flat for a step threshold (the "fight that never resolves" guard).
- **`AutoTestLogger`** (`auto_test_logger.gd`) — structured events + a damage-by-family tally + a summary + a markdown report. Reads handed state, writes no game state. Damage-by-family is built per step from net HP loss + the Deliveries that landed that step (direct hits → the source item's family; the unexplained remainder → the DoT/poison channel, which lands no Delivery yet).

### How to run

```
<godot> --headless --path . res://src/autotest/autotest.tscn -- \
        --autotest --seed 1 --speed 5 --timeout 120 --wall-timeout 30 \
        --report user://autotest_report.md
```

A **dedicated scene** (not an autoload), so nothing presentational mounts and the corridor testbed stays the normal `main_scene`. Exit `0` = the fight **resolved** (win or loss); exit `1` = it didn't (stuck / game-timeout / wall-timeout) — the harness asserts the sim runs to a clean conclusion, not who wins (that becomes `tune`'s job). `--seed` and `--speed` are **plumbed-but-inert** in Phase 2: a single Phase 1 fight draws no RNG, and the direct `sim_step` loop advances one STEP per call regardless of the dial — both go live with the run RNG + real-time paths in Phase 3.

## Flags (adapted from a-machine)

| Flag | Meaning |
|------|---------|
| `--autotest` | enable the mode |
| `--seed N` | RNG seed (determinism) |
| `--speed N` | sets the Timekeeper dial (fast-test); game-time identical |
| `--encounters N` / `--acts N` | how far to play (a-machine's `--bands`) |
| `--strategy S` | draft strategy (a-machine's `--build`; e.g. `poison`, `block`, `random`, `greedy-synergy`). **Deferred** — stub picks first viable |
| `--timeout N` | max game-seconds before fail |
| `--wall-timeout N` | max real-seconds (hang watchdog) |
| `--character C` | starting character |
| `--log PATH` / `--report PATH` | raw events / markdown analysis |
| `--nosave --notutorial` | always (fresh-user run) |
| `--headless` | Godot flag (before `--`) |

**Live in Phase 2:** `--autotest --seed --speed --timeout --wall-timeout --strategy --log --report` (+ forced nosave / notutorial). `--seed` / `--speed` are accepted but inert (see above); `--strategy` is stored on the stub Driver but unused until it has decisions. `--encounters / --acts / --character` arrive with the run loop (Phase 3).

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

**Phase 2 delivered the single-fight subset:** `AutoTestMode` + stub `AutoTestDriver` + `AutoTestStuckDetector` + `AutoTestLogger` (win/loss + duration + HP + damage-by-family) + `--seed --speed --timeout --wall-timeout` (nosave / notutorial forced) + stuck detection + exit code — enough to run one fight headless, deterministically, and assert it resolves. **Phase 3 extends it** to "draft → fight → advance × N" over the run loop: `--encounters / --acts`, the seeded run RNG that makes `--seed` live, and real draft strategies in the Driver.

## Open / deferred

- **The decision AI** — draft strategies, potion / choice policies. Stub now.
- **The `tune` skill** — the command + experiment-runner subagent. Design the logger/report to feed it; build later.
- **Report contents** — which metrics / charts — settle as combat metrics exist.

## Hooks (already in the architecture — nothing new needed)

- **Input-intent layer** (Combat manager / Run manager inbound) — the driver emits the same intents the UI does.
- **Timekeeper dial** → `--speed`. **Seedable run RNG** (`Run` owns it; `Save` snapshots its full state) → `--seed`.
- **Game manager** starts / ends the run (the harness drives it); the **Run manager** drives the encounter sequence the harness steps through and exposes run state for logging.
- **Output layer** is skipped headless — logic runs without renderer / VFX / audio.
