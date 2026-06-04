# Dark Corridor — Draft PRD

Run-structure PRD. Sits under the [Architecture Map](architecture.md). `Draft` is the **reward draw** — it produces a small offer of [Draftable](design.md)s (the 1-of-3 reward), pulled from the draft pool and weighted by depth. It is a **stateless service**: it draws an offer; the pending offer and the pick's application live in the [Run manager](run_manager_prd.md) (which owns run-state). Driven by the `Run manager` when an `Encounter` reward calls for it.

**Engine:** Godot 4.
**Date:** 2026-06-05. Pre-prototype.
**Naming:** `class_name DraftAutoload`, registered `Draft` (autoload convention — a stateless service, like `StatusManager` / `Save`; access via `Draft.*`).

Boundaries live in the hub: [architecture.md → Interface contracts → `Draft`](architecture.md#interface-contracts-boundary-hub). This PRD specifies the *internals*.

---

## Purpose

`Draft` answers one question: *given the pool and where the run is, what are the candidates to offer?* It is the **1-of-3 reward** mechanism (design): three slots, each usually an item, each with a low chance of an enchant or potion instead; the player picks one (no skip). It owns the **draw** — slot composition, depth-weighting, and the seeded pull from the pool — and nothing else.

What it **is not**:

- **Not the pool's *contents*.** `Meta-progression` owns what's unlocked into the pool; `Draft` pulls from it and never reaches into meta internals (architecture). It reads the pool, doesn't define it.
- **Not run-state.** It produces candidates; the **`Run manager` holds the pending offer and applies the pick** to run-state (board / potion slots / enchant target / relics). `Draft` writes nothing.
- **Not the relic/elite/boss grants.** Those relics are granted directly by the `Run manager` (Encounter reward) — see *open*; `Draft` is the 1-of-3 reward draw.
- **Not presentation.** The offer is presented + inspected by `UI` (tooltips on hover — the draft is a paused, between-fights decision, no combat clock).

---

## The draw

The `Run manager` calls `Draft` with the pool, the run-state, and the run RNG; `Draft` returns the offer (default **3** candidates):

- **Slot composition** — each slot is **usually an item**; each has a **low chance** of an **enchant** or a **potion** instead (a per-slot roll). The exact chances are tuning (design).
- **Depth-weighting** — rarity is a *complexity* tier (common / uncommon / rare — [Item PRD](item_prd.md)), and **drop odds shift with depth** (later drafts → better rarity odds — design). Weighting reads **depth/position only**.
- **Seeded** — the draw derives from the **run RNG** (the `Run manager`'s run stream), so a given run-state yields the **same offer** — not re-rollable by quit-and-resume (no save-scum — [Save PRD](save_prd.md)).

The offer is `Draftable`-generic — it draws item / enchant / potion definitions the same way; the subtype only matters at *application* (below).

## No skip, no hidden weighting (two design constraints)

- **No skip.** The player must take one of the three — no cap and no penalty for taking more, so taking one is always correct; the decision is *which*, judged on synergy (design). The draft always resolves to a pick.
- **No hidden weighting toward the build/archetype.** Weighting is **depth/rarity only** — never the player's current board or a character archetype. Hidden pool-reweighting toward "what you already have" is rejected (design: it collapses the synergy decision, hides mechanics, punishes experimentation). Guided drafting, if ever wanted, is a *visible* milestone choice — never an opaque reweight.

## The pick & its application

The player picks one candidate (a `draft pick` intent — architecture); the **`Run manager` applies it** by subtype (it owns run-state):

- **Item** → added to the board.
- **Potion** → added to a potion slot; if the slots are full, the player drops one to make room (a sub-choice — design).
- **Enchant** → applied immediately to a **chosen item** (one enchant per item — the player picks the target; a sub-choice).
- **Relic** → added to relics (only if a relic is ever offered via the draw — see *open*).

`Draft` neither holds the pending offer nor applies the pick — both are the `Run manager`'s (the input-intent model: `draft pick → Run manager / Draft adds the chosen Draftable`).

---

## Prototype scope

- A `draw` that returns **3 item candidates** from a small pool, **seeded** by the run RNG (so an offer is fixed per run-state).
- The **pick** routed through the `Run manager` → added to the board (no skip).
- Slot composition + depth-weighting stubbed minimally (mostly items; the enchant/potion roll + rarity odds are tuning).

**Not** in scope: the enchant/potion slot chances, full rarity-by-depth weighting, the enchant-target / potion-drop sub-choices, relic offers.

---

## Open / deferred

- **Slot chances** (item vs enchant vs potion per slot) + **rarity-by-depth odds** — tuning (design's pool work).
- **Relic offers** — whether relics are ever a draw (1-of-N relic offer) or only direct grants (midpoint / elite / boss). Design leans direct grants; confirm when relic acquisition is built.
- **Enchant-target / potion-drop sub-choices** — the UI interactions when a picked enchant needs a target or a potion needs a slot — a UI pass (the choices are intents the `Run manager` applies).
- **Pool data + the Draftable definition format** — content/impl (shared with the item / enchant / consumable formats).
- **RNG stream** — the draw uses the run stream; the run-vs-per-fight split settles with the Save / Encounter RNG ownership.
- **Autoload vs. plain helper** — `Draft` is stateless either way; autoloaded here for consistency with `StatusManager` / `Save`.

## Dependencies

- **Above:** the `Run manager` — calls `Draft.draw(pool, run_state, rng)` on a reward, holds the pending offer, applies the pick to run-state.
- **Reads:** the draft **pool** (its *contents* are `Meta-progression`'s — unlocks); the run-state's **depth** (for weighting) and the **run RNG** (handed in).
- **Does not:** own the pool contents (`Meta-progression`); hold the pending offer or apply the pick (`Run manager`); present / inspect (`UI`); grant relics (`Run manager` / `Encounter`).
