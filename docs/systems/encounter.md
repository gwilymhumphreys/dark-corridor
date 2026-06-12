# Dark Corridor — Encounter PRD

Run-structure PRD. Sits under the [Architecture Map](architecture.md). An `Encounter` is the **per-beat orchestrator** — one resolved beat of the descent (a fight, a non-combat event, or an in-act rest). It is **instanced per beat** by the [Run manager](run_manager.md); a fight `Encounter` creates and owns the per-fight [Combat manager](combat_manager.md). It is the beat tier of **Game (session) → Run (descent) → Encounter (beat) → Combat (fight)**.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name Encounter`, **instanced** (not an autoload) — one per beat, created/torn down by the `Run manager`.

Boundaries live in the hub: [architecture.md → Interface contracts → `Encounter`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

An `Encounter` resolves one beat and reports its outcome up. The descent's beats — regular fights, elites, bosses, non-combat events, in-act rests — are unified as Encounters (one system, not separate fight/event/rest systems — [design](../design/game_design.md)). It owns:

- **Its type + content** — a fight (an enemy composition), an event (lore prose + a binary choice), or a rest (a partial heal). Data-defined (definition vs. instance, below).
- **Its telegraph** — what it advertised as a choice-layer option (the category + an elite's demand), first-run legible.
- **Its resolution** — spawn enemies → run the fight → win/loss; or present the event's choice → apply the outcome; or apply the rest heal.
- **Its reward hook** — on completion it reports its outcome + reward-kind up; the `Run manager` fulfills it.

What it **is not**:

- **Not the beat *selection*.** Which beat happens is the `Run manager`'s — it **auto-rolls** a ROLL beat's content (COMBAT vs EVENT on the run RNG, anti-repeat biased) or takes a fixed beat, then draws a def from the per-band pool. The Encounter is the *resolved unit*, not the selector. *(The within-encounter tier-2 choice — an event's binary pick — is the Encounter's own resolution.)*
- **Not the fight.** A fight `Encounter` creates the `Combat manager` and awaits its result; it never runs the combat tick (`Timekeeper` / `Combat manager`).
- **Not run-state.** Event/rest outcomes and rewards mutate the player run-state, which the `Run manager` owns — the Encounter reports them; the `Run manager` applies them.
- **Not enemy/draft content** — it *uses* enemy definitions ([Enemy PRD](enemy.md)) and triggers the reward `Draft` (via the `Run manager`); it doesn't define them.

---

## Definition vs. instance

- **Encounter definition** — content/data in the pool: type/tier, the **location frame** (one line, e.g. "A flooded antechamber"), the **telegraph** (advertised category + elite demand), the **content** (a fight's enemy composition + ordering; or an event's prose + binary options + each option's outcome; or a rest's heal), and the **reward** (by type). Format is content/impl (deferred, as with item/enemy definitions). Player-facing strings (frame, telegraph, event prose/options) are localizable (`tr()` — `CLAUDE.md`).
- **Encounter instance** — the live per-beat orchestrator the `Run manager` instantiates from a picked definition, handed its context (the player `Actor`, run-state accessors, the run RNG, position).

---

## Types & resolution

**Approach vs. resolution.** The `Run manager` creates the `Encounter` right after the previous reward, and the corridor advance animates it **approaching from depth** — its enemy `Actor`s are spawned at creation so they can be rendered scaling in. **Resolution** begins on **arrival** (full view); a fight `Encounter` creates its `Combat manager` then. The approach is presentation (the corridor renderer + UI); the Encounter's *logical* beat is the resolution.

The `Run manager` instantiates the picked Encounter; it resolves by type, then reports outcome + reward up:

- **Fight** (regular / elite / boss) — spawn the authored enemy `Actor`s from their definitions ([Enemy PRD](enemy.md)), set their **left-to-right ordering** (composition: tank in front, adds before boss — design), and create the `Combat manager` with the player + enemy `Actor`s + ordering. Await win/loss. **Loss** → report **died** (the `Run manager` signals run-ended up to `Game`). **Win** → report the reward.
- **Event** — present the prose + the **binary choice** (a UI intent — the player picks an option); apply the chosen option's **outcome** (direct effects — heal / damage / a relic / a potion / a status — applied to run-state via the `Run manager`). Events are lore + a tradeoff (design); outcomes are *direct*, not the combat path. A **lethal** damaging outcome resolves the beat **LOST** on the spot — the run ends there, never a dead player walking to the next fight.
- **Rest** (the in-act small rest — one guaranteed per act, design) — apply a **partial heal** to the player `Actor` (via the `Run manager`'s HP-economy surface). No draft / relic. *(The between-act **full** rest is **not** an Encounter — it's the `Run manager`'s automatic act-transition.)*

## Composition & ordering (the fight case)

A fight Encounter spawns **1–4 enemies** (most 1–2; group fights authored to give AOE a reason — design) and places them in a **left-to-right order** before handing the set to the `Combat manager` (which owns runtime ordering + the leftmost-targeting rule). Spatial composition is the puzzle — "tank in front of DPS," "adds before the boss." This resolves the composition/ordering authoring the [Enemy PRD](enemy.md) deferred here.

## Telegraph (the option's advertisement)

Each candidate advertises its **category** — combat-heavy/item-reward · safe/healing · risk/high-reward — and, for an **elite**, its **demand** (e.g. "high single-target burst," "applies poison — bring cleanse"). First-run legible (telegraph the category, not the contents — design). An **elite** is a fight candidate with a stronger telegraph + a bigger reward; **engaging** is picking it, **skipping** is picking another option — no separate skip mechanic.

## Reward

On completion the Encounter reports its **outcome + reward-kind** to the `Run manager`, which fulfills it (run-state is the `Run manager`'s):

- **Regular fight** → a reward `Draft` (1-of-3).
- **Elite** → a relic + a draft (richer — design).
- **Boss** → a relic (+ the `Run manager` ends the act).
- **Rest** → none (the heal is the reward).
- **Event** → the chosen option's outcome (may itself grant or cost).

The reward *content* (draft odds, relic tiers) is design/tuning; the `Draft` mechanism is its own PRD ([Draft PRD](draft.md)).

---

## Prototype scope — BUILT

- **Fight** Encounter (regular / elite / boss): spawns its enemy `Actor`s in order, creates the `Combat manager` on begin, awaits win/loss, reports the reward up (DRAFT / RELIC / ELITE = relic+draft).
- **Event** Encounter: `begin()` **awaits** the tier-2 binary choice; the pick (routed through `RunManager.pick_event_option(index)`) applies the chosen `EventOptionDef`'s direct outcome and resolves (reward NONE — the outcome is the reward). Player-Actor effects (heal / max-HP / damage) are applied by the Encounter; an **ADD_ALLY** outcome (the **recruit event** — the event-driven ally-acquisition path) touches the *roster*, so the `RunManager` applies it (`add_ally`, capped at `MAX_ALLIES` = the 4 ally slots) before delegating. Prose + options are localized.
- **Rest** Encounter: a partial heal on begin, resolves immediately.
- Instantiated by the `Run manager` from the act pool (a fixed beat) or a CHOICE candidate; reports outcome (died / won / resolved) + reward up. The two-tier choice **UI** (choice overlay + event overlay) is built (run_screen).

**Not** in scope: the real ~30-encounter pool + event prose (the owner's content), boss **signature mechanics**, relic/potion event outcomes (route through the `Run manager`'s run-state surface — added with real content), reward tuning.

---

## Open / deferred

- **Encounter-definition data format — resolved (#23):** typed GDScript `EncounterDef` + catalog. The **~30-encounter pool** (location frames, telegraphs, event prose) — content/impl + design.
- **Event-outcome catalog** (the direct effects an option can apply) — content.
- **Telegraph iconography** + the **two-tier choice UI** — a UI pass (the candidate *assembly* is the `Run manager`'s; presentation is UI).
- **Choice-point frequency + candidate-set rules** (category spread, no-repeat, elite budget) — design/tuning, applied by the `Run manager`'s draw.
- **Reward specifics per tier** — design/tuning + the `Draft` PRD.
- **Resolved here:** composition/ordering authoring (Enemy PRD's deferral); the `Encounter` → `Combat manager` handoff (player + enemy `Actor`s + ordering); elite/boss reward routing (reported up, fulfilled by the `Run manager`).

## Dependencies

- **Above:** the `Run manager` — assembles the candidate set, instantiates the picked Encounter with context, reads its outcome, and fulfills its reward. Owns the lifetime.
- **Creates / owns (fight):** the `Combat manager` (player + enemy `Actor`s + ordering); awaits its win/loss.
- **Uses:** enemy definitions → spawns enemy `Actor`s ([Enemy PRD](enemy.md)); the player `Actor` (read for the fight; heal/damage via the `Run manager`'s surface for rest/event).
- **Does not:** own the map / run-state / game-state machine (`Run manager` / `Game manager`); run the combat tick (`Combat manager` / `Timekeeper`); define the `Draft` (triggered via the `Run manager`).
