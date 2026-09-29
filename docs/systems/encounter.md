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
- **Its card** — what it shows when offered before a fight: its kind, its name and a hint at what it gives ([Telegraph](#telegraph-the-encounter-card)).
- **Its resolution** — spawn enemies → run the fight → win/loss; or present the event's choice → apply the outcome; or apply the rest heal.
- **Its reward hook** — on completion it reports its outcome + reward-kind up; the `Run manager` fulfills it.

What it **is not**:

- **Not the beat *selection*.** Which beat happens is the `Run manager`'s — the map fixes a fight or names the pool it is drawn from, and draws the encounters offered before each fight ([run_manager.md](run_manager.md#the-choice-of-encounters)). The Encounter is the *resolved unit*, not the selector. *(The within-encounter tier-2 choice — an event's binary pick — is the Encounter's own resolution.)*
- **Not the fight.** A fight `Encounter` creates the `Combat manager` and awaits its result; it never runs the combat tick (`Timekeeper` / `Combat manager`).
- **Not run-state.** The `Run manager` owns the run-state. The Encounter applies rest and event outcomes to the player `Actor` directly; the `Run manager` applies rewards and anything that touches the roster (an ally).
- **Not enemy/draft content** — it *uses* enemy definitions ([Enemy PRD](enemy.md)) and triggers the reward `Draft` (via the `Run manager`); it doesn't define them.

---

## Definition vs. instance

- **Encounter definition** (`EncounterDef`, #23) — content/data in the pool: type/tier, the **location frame** (one line, e.g. "A flooded antechamber" — stored as the `name_key`), the **content** (a fight's enemy composition + ordering; or an event's prose + binary options + each option's outcome; or a rest's heal), and the **reward** (by type). An encounter offered before a fight also has a **rarity** (`Rarity.COMMON` or `Rarity.RARE`), **`requires`** (conditions that must all hold, or it is never offered) and **`weights`** (rules that multiply how likely it is while their condition holds); `offer_weight(run)` combines them ([Offer rules](#offer-rules)). Player-facing strings (frame, event prose/options) are localizable (`tr()` — `CLAUDE.md`).
- **Encounter instance** — the live per-beat orchestrator the `Run manager` instantiates from a picked definition, handed its context (the player `Actor`, run-state accessors, the run RNG, position).

---

## Types & resolution

**Approach vs. resolution.** The `Run manager` creates the `Encounter` right after the previous reward, and the corridor advance animates it **approaching from depth** — its enemy `Actor`s are spawned at creation so they can be rendered scaling in. **Resolution** begins on **arrival** (full view); a fight `Encounter` creates its `Combat manager` then. The approach is presentation (the corridor renderer + UI); the Encounter's *logical* beat is the resolution.

The `Run manager` instantiates the picked Encounter; it resolves by type, then reports outcome + reward up:

- **Fight** (regular / elite / boss) — spawn the authored enemy `Actor`s from their definitions ([Enemy PRD](enemy.md)), set their **left-to-right ordering** (composition: tank in front, adds before boss — design), and create the `Combat manager` with the player + enemy `Actor`s (+ any run-scoped allies) + ordering. Await win/loss. **Loss** → report **died** (the `Run manager` signals run-ended up to `Game`). **Win** → report the reward.
- **Event** — present the prose + the **binary choice** (a UI intent — the player picks an option); apply the chosen option's **outcome** — one of `HEAL_FRACTION` / `MAX_HP_BONUS` / `DAMAGE` (applied directly on the player `Actor`) or `ADD_ALLY` (which the `Run manager` applies to the run roster). Events are lore + a tradeoff (design); outcomes are *direct*, not the combat path. A **lethal** damaging outcome resolves the beat **LOST** on the spot — the run ends there, never a dead player walking to the next fight.
- **Rest** (an in-act small rest, offered before a fight) — the `Encounter` heals the player `Actor` directly (`heal_fraction` of max-HP) in `begin()`. No draft / relic. *(The between-act **full** rest is **not** an Encounter — it's the `Run manager`'s automatic act-transition.)*

## Offer rules

**Location:** `EncounterDef.offer_weight`, the conditions in `src/run/conditions/`.

A **condition** is a `RunCondition` subclass with `holds(run) -> bool`. It only reads the run. Each kind is one file, so a new kind of rule is one new file.

| Condition | Holds when |
|---|---|
| `HasItems(ids, count = 1)` | The board holds at least `count` of each listed item id. Several ids make a combination. |
| `HasItemType(type, count = 1)` | The board holds at least `count` items with the type tag (`ItemType.WEAPON` and so on). |
| `HasRelic(id)` | The run holds the relic. |
| `HealthBelow(fraction)`, `HealthAbove(fraction)` | Health is below or above that fraction of maximum health. |
| `GoldAtLeast(amount)` | Gold is at least the amount. |
| `FightBetween(first, last)` | The next fight's number, counted from 1, is in the range. |
| `CanAddAlly()` | The player side has a free ally slot. |
| `Not(condition)`, `AnyOf([conditions])` | The inverse of one condition, or any of several. A plain list already means all of them. |

`offer_weight(run)` is 0 when any of `requires` fails. Otherwise it is the rarity's weight (`Balance.ENCOUNTER_WEIGHT_COMMON` / `ENCOUNTER_WEIGHT_RARE`) times the `multiplier` of every `weights` entry whose `'if'` condition holds; a multiplier of 0 also stops it being offered. The `Run manager` draws each card by these weights ([run_manager.md](run_manager.md#the-choice-of-encounters)), so an encounter the player cannot choose is never offered.

```gdscript
rarity = Rarity.RARE
requires = [HasItemType.new(ItemType.WEAPON, 3)]
weights = [{ 'if': HealthBelow.new(0.4), 'multiplier': 3.0 }]
```

## Composition & ordering (the fight case)

**A fight's enemies can be generated against a points target** instead of coming from the def. The `Run manager` draws from the act's enemy pool until the drawn set's points reach the beat's target (`RunMap.target_points` / `RunMap.draw_enemies`; [`../plans/encounter_points_budget.md`](../plans/encounter_points_budget.md)), and passes the ids to the `Encounter`, which uses them in place of `EncounterDef.enemy_ids`. The def still supplies the location frame, the type and the reward. The draw is random and ignores composition — positioning comes later. **The pools are empty until the owner authors them**, so every fight currently uses its authored `enemy_ids`. A boss is never generated against points: it takes its act's `EnemyPools.BOSS` list when that has entries, otherwise its authored `enemy_ids`.


A fight Encounter spawns **1–4 enemies** (most 1–2; group fights authored to give AOE a reason — design) and places them in a **left-to-right order** before handing the set to the `Combat manager` (which owns runtime ordering + the leftmost-targeting rule). Spatial composition is the puzzle — "tank in front of DPS," "adds before the boss." This resolves the composition/ordering authoring the [Enemy PRD](enemy.md) deferred here.

## Telegraph (the encounter card)

Before each fight the player is offered three encounters as `EncounterCard`s standing in the corridor ([run_screen.md](run_screen.md#the-choice-of-encounters)). A card shows the encounter's kind (Event, Rest, Relic), its location frame and a hint at what it gives, derived from the def's type (`EncounterDef` carries no telegraph field). First-run legible: the card telegraphs the kind, not the contents (design). An **elite** is a fixed map square (`RunMap.Square.ELITE`, the `fight_elite` encounter), not an offered encounter.

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
- **Relic** Encounter (`Type.RELIC`): no fight; resolves on begin with the `RELIC_CHOICE` reward, and the `Run manager` offers a choice of relics.
- Instantiated by the `Run manager` from a FIXED beat (an elite fight, the boss), a regular fight drawn from a pool, or the encounter the player picks before a fight; reports outcome (died / won / resolved) + reward up. The event overlay and the encounter cards are live (run_screen).

**Not** in scope: the real ~30-encounter pool + event prose (the owner's content), boss **signature mechanics**, relic/potion event outcomes (route through the `Run manager`'s run-state surface — added with real content), reward tuning.

---

## Open / deferred

- **Encounter-definition data format — resolved (#23):** typed GDScript `EncounterDef` + catalog. The **~30-encounter pool** (location frames, telegraphs, event prose) — content/impl + design.
- **Event-outcome catalog** (the direct effects an option can apply) — content.
- **Encounter card look** — the rarity colour and the card art come with the later stages of [`../plans/encounter_choice.md`](../plans/encounter_choice.md).
- **Conditions on run flags and on how often an encounter was picked** — stage 3 of the plan, with the state they read.
- **Reward specifics per tier** — design/tuning + the `Draft` PRD.
- **Resolved here:** composition/ordering authoring (Enemy PRD's deferral); the `Encounter` → `Combat manager` handoff (player + enemy `Actor`s + ordering); elite/boss reward routing (reported up, fulfilled by the `Run manager`).

## Dependencies

- **Above:** the `Run manager` — assembles the candidate set, instantiates the picked Encounter with context, reads its outcome, and fulfills its reward. Owns the lifetime.
- **Creates / owns (fight):** the `Combat manager` (player + enemy `Actor`s + ordering); awaits its win/loss.
- **Uses:** enemy definitions → spawns enemy `Actor`s ([Enemy PRD](enemy.md)); the player `Actor` (read for the fight; healed or damaged directly by a rest or event).
- **Does not:** own the map / run-state / game-state machine (`Run manager` / `Game manager`); run the combat tick (`Combat manager` / `Timekeeper`); define the `Draft` (triggered via the `Run manager`).
