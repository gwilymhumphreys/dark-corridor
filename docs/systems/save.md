# Dark Corridor — Save PRD

Foundation PRD. Sits under the [Architecture Map](architecture.md). `Save` is the run-persistence **service**: it persists a snapshot on encounter entry so a run can be quit and resumed cleanly (design — important for short/mobile sessions). Per `CLAUDE.md`, **no migration** — we're in development.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.
**Naming:** `class_name SaveAutoload`, registered `Save` (autoload convention).

Boundaries live in the hub: [architecture.md → Interface contracts → `Save`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

`Save` serializes a **handed** snapshot and returns it on load. It holds no live state and never writes back into live systems.

**Resolves review #3 — push, not pull.** `Save` does *not* reach up to read run state. The `Run manager` gathers the snapshot and hands it to `Save` (write on encounter entry); on load `Save` returns the snapshot — the `Game manager` reads it and hands it to the `Run manager`, which rehydrates. So `Save` depends on nothing — honestly foundation.

What it **is not**: not the run-flow (the `Run manager` builds the snapshot, writes it per-encounter, and rehydrates; the `Game manager` owns load/clear *timing*); not combat state (never persisted); not meta-progression persistence (a separate dataset — deferred).

---

## When

**Auto-save on encounter entry** (design) — at the start of each encounter, before it resolves; that's the resume point. **One run slot**, overwritten each time, written **atomically** (temp file → remove → rename); a crash inside that commit window leaves only the temp file, which `read()` recovers as a fallback — so a quit mid-write can't corrupt or lose the slot. On **death or final-boss win**, the run save is **cleared** (death is final per run — design). No manual saves; no mid-combat save.

---

## What — the run snapshot

**Run-persistent state only:**

- **Player `Actor`** — current + max HP, and the board: item definitions + each item's enchant. (No statuses — all statuses are combat-scoped, never saved; decision #26.)
- **Relics & potions** — the player run-state (not Actor-owned).
- **Run position** — act + encounter index, floor-map progress, character.
- **RNG state** — the `Run manager`'s run RNG, captured as its **full state** (not just the seed), so resume is **deterministic**: reloading reproduces the same future draft offers and encounter beats *every time* — not re-rollable by quit-and-resume (no save-scum; consistent with "death is final").

**Explicitly not saved:** live combat state — the fight, the `Timekeeper`, `Delivery`s, combat-scoped statuses (block, in-fight poison). Combat is ephemeral and the save sits *between* fights, so there's nothing mid-fight to persist; resume re-enters at the saved encounter. Enemy actors aren't saved either — they're regenerated per encounter from their definitions (Enemy PRD). **Items created mid-fight** (the `CREATE_ITEM` seam — [`item_creation_and_decay.md`](item_creation_and_decay.md)) are combat-scoped too: the Combat manager strips them from the board at teardown, so the snapshot — taken between fights — only ever sees the *drafted* board.

*(Statuses are **never** saved — all are combat-scoped (decision #26). Durable effects are **Relics / Enchantments**, which the snapshot stores by id + value; a relic re-applies any combat-start status fresh each fight.)*

---

## Load / rehydrate

On launch the `Game manager` calls `Save.read()`; if a run save exists and is readable, it hands the snapshot to a new `Run manager`, which rehydrates the run (rebuilds the player `Actor` + board, relics, potions, position, RNG) and resumes at the saved encounter. `Save` itself writes into no live system.

---

## No migration (`CLAUDE.md`)

We do **not** migrate saves. An absent, unreadable, or format-incompatible save → start a **fresh run** (discard). `Save` discards corruption and wrong versions; a parsable save with a broken **shape** (missing keys) is refused by `RunManager.rehydrate`, and the `Game manager` then clears the slot and stays at Title. No version-upgrade logic, no compat shims; the format may change freely during development.

---

## Format / location

`user://` (Godot). The serialization format (a dict via JSON / `var_to_bytes` / a Resource) is impl/content — deferred. Write atomically (temp → rename).

---

## Meta-progression is a separate dataset (deferred)

Meta-progression (the skill tree / unlocks) persists *across* runs and survives death — a different dataset with a different lifecycle from the run save. It uses the same `Save` *service* but is the Meta PRD's content; not specified here. (Run save = cleared on death; meta save = persists.)

---

## Prototype scope

- Snapshot a minimal run-state (player HP + a board + run position) at encounter entry; write atomically to `user://`.
- On launch, load it and resume at the saved encounter (the `Game manager` reads it; the `Run manager` rehydrates).
- Clear on death.

**Not** in scope: relics/potions/RNG content, meta-progression, the final format.

---

## Open / deferred

- **Serialization format + exact snapshot schema** — impl/content.
- **Status lifetime — resolved (#26):** all statuses are combat-scoped; **none are saved**. Run persistence is Relics / Enchantments (stored by id + value).
- **RNG capture — resolved (#20):** the snapshot stores the `Run manager`'s **full** run-RNG state (not just the seed), so resume reproduces all future draws. The per-fight combat stream is *derived* (run seed + encounter index), not saved — combat state is ephemeral.
- **Resolved (review #3):** push model — systems hand `Save` a snapshot; it never reads up.

## Dependencies

- **Above:** nothing — `Save` serializes a handed snapshot and returns it on load. It calls into no live system (push in, return out).
- **Driven by (above):** the `Run manager` — builds the snapshot and calls `Save.write(snapshot)` on encounter entry; rehydrates run-state from a snapshot on resume. The `Game manager` — calls `Save.read()` on launch (resume-vs-fresh) and `Save.clear()` on death/win; owns the meta-save.
