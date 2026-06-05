# AutoTest Mode — design & scaffolding

> **Status: design / scaffolding (pre-prototype).** The harness isn't built yet — the systems it drives are still PRDs. This doc specs it so it's *designed in*, not bolted on. Modeled on `../a-machine`'s AutoTest (`a-machine/docs/testing/autotest.md`) + its `tune` workflow, adapted to this game. **The decision-making AI and the `tune` skill come later — scaffolding first.**

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

## Scaffolding to build (the structure, not the AI)

Mirrors a-machine's `src/autotest/` trio:

- **`AutoTestMode`** — entry: parse flags, seed RNG, set the dial, force `--nosave --notutorial`, **drive the `Game manager`'s run lifecycle** (start a run, watch for run-ended) + own the game-time / wall-time timeouts + exit code.
- **`AutoTestDriver`** — the decision source: on each draft / choice / potion opportunity, emit the matching input-intent. **Stub now**; pluggable strategies later.
- **`AutoTestLogger`** — structured events (encounter start/end, draft offered/picked, fight win/loss + duration + HP + damage-by-family, run end) + a summary + a markdown report. Reads handed state; writes none.

Lives in `src/autotest/` when built.

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

## Prototype scope (build when the combat loop exists)

`AutoTestMode` + a **stub** `AutoTestDriver` (first-viable draft, no potions) + `AutoTestLogger` (win/loss + duration + HP) + `--seed --speed --encounters --timeout --wall-timeout --nosave --notutorial` + stuck detection + exit code. Enough to run "draft → fight → advance × N" headless, deterministically, and assert it completes.

## Open / deferred

- **The decision AI** — draft strategies, potion / choice policies. Stub now.
- **The `tune` skill** — the command + experiment-runner subagent. Design the logger/report to feed it; build later.
- **Report contents** — which metrics / charts — settle as combat metrics exist.

## Hooks (already in the architecture — nothing new needed)

- **Input-intent layer** (Combat manager / Run manager inbound) — the driver emits the same intents the UI does.
- **Timekeeper dial** → `--speed`. **Seedable run RNG** (`Run` owns it; `Save` snapshots its full state) → `--seed`.
- **Game manager** starts / ends the run (the harness drives it); the **Run manager** drives the encounter sequence the harness steps through and exposes run state for logging.
- **Output layer** is skipped headless — logic runs without renderer / VFX / audio.
