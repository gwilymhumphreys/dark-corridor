# Dark Corridor — Decision Log & Handoff

> **For the next agent (or future-me).** Read [`docs/index.md`](../index.md) first (the catalog), then this. This records *what was decided, why, the approach, what's open, and what's next* — so you don't re-litigate settled calls or contradict the model. Dates: 2026-06-04; updated 2026-06-05 (DoT bypasses block; enemy-item targeting; prototype redefined as a playable itch.io build).

## Where the project is

Pre-prototype. The **only code** is the corridor renderer (`src/scenes/corridors/` + the `corridor_testbed` host) — that's "experimenting," and the real game will reuse the corridor as a *background*. **Everything else is paper** (design + PRDs in `docs/project/`). This session reviewed the high-level design and wrote the **foundation + combat-adjacent PRDs** (the agreed scope), plus autotest + `tune` scaffolding, and worked the combat **time model** to a fixed timestep.

## The approach (keep doing this)

- **One file per system.** `docs/project/<system>_prd.md`. Cross-system edges live **once** in `architecture.md` → *Interface contracts (boundary hub)*; PRDs link there, never duplicate edges.
- **Incremental.** Foundation + combat-adjacent are PRD'd. **Run-structure (`Run manager` / `Encounter` / `Draft`) is now prototype-scope** — the prototype target is a **playable itch.io build** (see Next steps), so it needs the run controller, encounters/events, fights, and localization. **Meta / characters / audio stay deferred** until that build exists (per architecture's "don't write all PRDs up front"). The separate files are *so* we can add layers one at a time.
- **PRD template:** Purpose (is / is-not) → Boundaries (link to hub) → Model & rules → Prototype scope → Open/deferred → Dependencies. Numbers point to source files, never baked into prose. Open questions are **flagged, not invented**.
- **Think-first, then review.** Before writing a PRD, reason through ambiguities, surface *genuine* forks to the user (not conventional defaults), resolve, then write. After writing, consistency-review against the other docs.
- **House style:** sister projects `../battledraft`, `../dogmage` (shared systems, the `Manager` naming). `../a-machine` (= AMTKAG, the dev's shipping game) is the model for the autotest + `tune` patterns.

## The docs (current set)

`design.md` (whole-game snapshot) · `architecture.md` (system map + boundary hub + combat spine) · `combat_prd.md` (resolution model) · `timekeeper_prd.md` (the combat clock) · `actor_prd.md` · `status_manager_prd.md` · `item_prd.md` · `combat_manager_prd.md` (per-fight orchestrator) · `enemy_prd.md` · `save_prd.md` · `art_audio.md` (art/audio vibes) · `../testing/autotest.md` (harness scaffolding) · `.claude/commands/tune.md` + `.claude/agents/tune-run.md` (tune scaffolding).

## Key decisions + why

*(Naming evolved — don't resurrect old terms: `Core`/`Main` → `Timekeeper`; `…controller` → `…manager`; `StatusEngine` → `StatusManager`; `effect`/`pending effect` → `Delivery` + `payload`.)*

1. **`Timekeeper` (was Core/Main).** The combat time system is **combat-scoped** (resets each fight, no meaning outside) — "Core" wrongly implied global/persistent.
2. **`Manager` naming** (house style). Instanced → `class_name FooManager`; autoload → `class_name FooManagerAutoload` registered `Foo`. (`StatusEngine`→`StatusManager`; the two "controllers" → `Run manager` / `Combat manager`.)
3. **Testbed renamed** `main` → `corridor_testbed` (it's a renderer testbed, not the game; frees `main`).
4. **`Combat manager` introduced** — the per-fight orchestrator that nothing owned: the live fight (actor pair + left-to-right ordering), win/loss, runtime targeting authority, the trigger event bus, the component registry, **and the `Timekeeper`'s lifecycle**. The `Run manager` does **not** touch the Timekeeper (the user was explicit) — it hands a fight to the Combat manager and waits for the result.
5. **`StatusManager` = stateless-rules autoload.** Status *instances* live on their **targets** (Actor / Item), not in the manager — this is what lets persistent item-buffs outlive a fight, and it keeps an autoload from holding per-fight state. **Block** = an actor-targeted **absorb-status**; `Actor.take_damage` runs incoming damage through the target's modifier-statuses via the StatusManager (block absorbs before HP; precise amplifier/absorber order is open — StatusManager PRD). Block absorbs **direct** damage and **persists until consumed** (no decay); **DoT (poison/burn) bypasses block** via the `unblockable` flag (set by default on DoT — Spire/Bazaar-style, so poison stays a *strategy*, not just a finisher).
6. **Relics & potions = run-level** (player run-state `{ actor, relics, potions, … }`), **not** Actor-owned — keeps the Actor a pure, symmetric combatant (HP + board + statuses).
7. **Symmetric `Actor`; `Enemy` is not a class** — an Actor built from an authored *enemy definition*. Enemy items are a **content category** (per-enemy attack item + small shared utility pool), mechanically just `Item`s.
8. **`Delivery` + `payload`.** What an item fires = a **Delivery** (the in-flight carrier: `payload` + resolved target + travel-Ticker); its content = a **payload** `(kind, value)`. Retired "effect" as the combat-resolution word (overloaded). The item declares a **relative target-shape** (self / opponent-leftmost / all-opponents, + enemy-item shapes — see #14); the **Combat manager resolves shape→target and spawns the Delivery** — so the Item never depends *up* on the Combat manager.
9. **Fixed timestep (the big one).** Combat runs in fixed `STEP`s. The **`Timekeeper` is slimmed to the combat clock**: `sim_time` (stepped, for logic), `render_time()` (continuous, for the smooth VFX wall), the one speed `dial`, and `steps_due()` (real time × dial → whole steps, `MAX_STEPS` cap + backlog-drop) + `advance()`. The **`Combat manager` owns the component registry, advances every component each `sim_step()`, and runs the `_physics_process` loop**. The **dial = how many fixed steps run per real second** (not a per-step delta). This gives determinism + **bit-reproducible autotest** (run K steps); `render_time` keeps motion smooth between steps; Godot's physics loop handles the fixed-`delta` cadence + catch-up cap; **autotest drives `sim_step()` directly** (no real time).
10. **Item types:** every item is **active** (ticks); a "trigger" is an **additional event-push on the same accumulator** (the item still ticks — not a separate type); **no passive item type** (passive/always-on effects are **statuses**).
11. **`Save` = push, not pull.** The run-flow layer hands `Save` a snapshot; `Save` persists it and *returns* it on load (the `Run manager` rehydrates) — `Save` reads no live state. Auto-save on encounter entry, single run slot, **no migration** (`CLAUDE.md`). Snapshot = run-persistent state only (HP, board+enchants, relics, potions, position, **RNG** so resume is deterministic / not save-scummable); combat state is ephemeral, never saved.
12. **Triggers = accrual-only** (combat_prd's Bazaar lesson — loop-proof). The **event bus lives in the Combat manager**; a push fires on the *next* step → **one link per step** (no in-step recursion).
13. **Autotest scaffolding.** The AI driver is just **another input-intent source** (combat is auto, so it only makes draft / choice / potion decisions); `--speed` = the Timekeeper dial; headless skips the output layer; determinism = seeded RNG. **The decision AI and the `tune` skill internals are deferred.**
14. **Item-targeting (enemy items) = random by default.** Effects that hit an opponent's *items* (silence, item-debuffs) get two shapes — `opponent-item-random` (one) and `all-opponent-items` (all); single-item selection is **random via the seeded combat RNG** (fights stay bit-reproducible). A deliberate exception to the actor rule ("leftmost, never random," for player predictability) — provisional, may become a rule after testing. *(Board-wide own-item pushes — a trigger-all potion — are a separate event-bus push, not this shape; still open.)*

## Open / deferred (each has a home)

- Timescale override **replace-vs-multiply** → combat_prd / when hover-slow-mo is built.
- **Within-step component order** (deterministic) → Combat manager, when real boards exist.
- **Stat-statuses** (strength/weak/vulnerable) → design defers to prototype; constraint: a flat modifier must not make fast items strictly dominant.
- **Per-effect stack/decrement** + block tuning → content.
- **Mid-fight roster changes (summoning)** → the Combat manager assumes a fixed roster; revisit when boss "summons-adds" is built.
- **Simultaneous-death tiebreak** (→ loss, provisional); **AOE-at-arrival** specifics → when multi-enemy fights are built.
- **Game-state-machine ownership** (review #4) → the `Run manager` PRD.
- **`STEP` / `MAX_STEPS` values** → tuning. **Data formats** (item/enemy/status/save) → content/impl.
- **Localization — in scope from the prototype** (the playable itch.io build ships translatable). Item / status / enemy names + tooltips + encounter prose must be `tr()`-able / POT-extractable (`CLAUDE.md`); bake the constraint into each data-format decision from the start, never retrofitted.
- **The decision AI**, the **`tune` internals**, and the **autotest code** (`src/autotest/*.gd`) → build when the prototype combat loop exists.

## Next steps

1. **Prototype-scope PRDs (write next — the playable itch.io build needs them):** `Run manager` (+ game-state machine), `Encounter` (incl. non-combat events), `Draft` (plus the minimal `UI/Layout` + `VFX driver` to render a playable screen, and localization wired from the start). **Still deferred (post-prototype):** `Meta-progression`, `Characters`, `Audio`.
2. **Build order for the prototype loop:** `Timekeeper` + `Actor` + `Item` + `StatusManager` + `Combat manager` → one player + one authored enemy, fixed-step `sim_step` (advance → fire → land → events → win/loss) → then the autotest scaffolding (`AutoTestMode` / stub `AutoTestDriver` / `AutoTestLogger`) → then scale content + `tune`. *(Prototype = a **playable itch.io build** (resolved 2026-06-05): the combat spine **plus** the `Run manager`, `Encounter`/events, `Draft`, and **localization** from the start — not just one fight. Build the spine first, then layer the run loop on top and ship the loop, not a combat test-harness.)*
3. The design's own next step: "build the prototype loop (one corridor segment, 3 placeholder items, one enemy, draft, repeat ~10×); watch whether the cascade is satisfying."

## Conventions (from `CLAUDE.md`)

Static typing always; single quotes; 2-space indent; `snake_case` filenames; `PascalCase` `class_name`; autoloads `<Name>ManagerAutoload` registered `<Name>`. Full names, not abbreviations. Docs describe **systems/intent, not numbers** (point to source). **No save migration.** Player-facing text is localizable (dev panels stay English). Run Godot 4.6; headless reimport after adding assets. The **boundary hub** in `architecture.md` is the canonical cross-system reference.
