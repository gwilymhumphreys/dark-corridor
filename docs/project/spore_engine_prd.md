# Dark Corridor — Spore Engine Support PRD

> **This is engineering work, NOT content — a building agent should implement it.**
> It specs the *engine capabilities* the first status-identity character (the
> **Spore Druid** — [`../design/spore_druid.md`](../design/spore_druid.md))
> needs beyond the current apply / tick / resolve model. The spores, cards, numbers,
> and which-status-does-what stay the **owner's** content (decision #23). Throughout,
> **"spore" = a status** ([StatusManager](status_manager_prd.md)); the capabilities
> are general (any future status-build character reuses them), named here for the
> driver.

Content PRD's engine counterpart. Sits under the [Architecture Map](architecture.md). Extends the [`combat_prd`](combat_prd.md) resolution model + [StatusManager](status_manager_prd.md) / [Item](item_prd.md) / [Combat manager](combat_manager_prd.md); adds no new resolution model.

**Engine:** Godot 4.
**Date:** 2026-06-06. **Deferred capability — not yet built.** Build alongside the content that needs it (coordinate with the owner — see *Build order*).

Boundaries live in the hub: [architecture.md → Interface contracts](architecture.md#interface-contracts-boundary-hub). Hub entries get added **when each capability is built** (this is a forward spec, like the pre-prototype PRDs were).

---

## Purpose

The Spore Druid is a **status-identity character** (the Slay-the-Spire Silent analog — most of its board is status appliers). Its two pillars (Spores: Mass / Self; Summon) need three mechanical seams the spine doesn't have. This PRD enumerates that engine work so it can be picked up cleanly, and — equally important — marks the large surface that needs **nothing new**, so the work isn't over-built.

**What needs no engine work (author as content whenever):** the **applier commons** — a damage item with a status rider (Pocket Shrooms), poison (stacked / periodic), beneficial self-spores (regen = periodic, self-block = pool), burn (the timed counterpart DoT). These are the built apply-status item subtype + the existing status shapes (periodic / timed / pool / static-modifier — [StatusManager](status_manager_prd.md)). The engine is already built for this character; only the gaps below are open.

**Is:** three capabilities — (1) **status-stack consumption** (spend spores as fuel), (2) **evasion** (the "acts but misses" seam, for blinding), (3) the **player-side consumer** of the already-deferred mid-fight roster add (summon).

**Is not:** the spores / cards / numbers (content — owner's); a new resolution model (it reuses fire → resolve → Delivery → land/fizzle); the character / draft / draftable layer; the status *content* itself (those are GD `StatusEffect` classes the owner authors).

### Consistency with decision #23 — general seams, no baked spore

Every capability here is **plumbing the GDScript-authored content drives** (decision #23), not a hardcoded effect — the same shape as the stat-status seams already built (handoff backlog #6: seams wired, the statuses themselves are the owner's `StatusEffect` classes):

- `consume(target, id, amount)` is an **id-agnostic verb** on the stateless facade, beside `apply` — the *which status, how much, scaling* live on the `ItemDef` / the `StatusEffect` class (`is_fuel()`). The engine knows no "poison," no "Mass."
- **Evasion is a `StatusEffect` hook** (`causes_evasion()`), beside the built `absorb` / `modify_outgoing` behaviours — the engine checks "does the source carry a status whose `causes_evasion()` returns true," **never the name "blinding."** Any status that overrides it evades.
- The **roster add** is a general both-sides capability; *what* spawns (the token's authored actor definition + the spawn trigger on a relic/enchant) is content.
- **Lethal-execute** stays a verify-content-vs-hook call, not a pre-built mechanic.

The engine hardcodes **no spore** — it gains verbs, hooks, and one capability; the Spire-style spore effects are `StatusEffect` classes / `ItemDef`s the owner authors that *use* this plumbing. (Same discipline the memory bank records from the stat-status build: when a task is "make the engine able to express what content will choose," wire a seam, don't bake the content.)

---

## Capability 1 — Status-stack consumption (spend spores as fuel) — BUILT (2026-06-07)

> **Realized:** `StatusManager.consume(target, id, amount) → float` (stacks removed; a
> no-op returning 0 for non-fuel statuses — those whose `is_fuel()` is false). `ItemEffect` /
> `Payload` carry the consume declaration (`consume_id` / `consume_amount` / `consume_from_target` / `consume_scale`).
> **Self-fuel** resolves in `Item._resolve_effect` (spend the owner's stacks, scale the
> payload value at fire); **opponent-fuel (Mass)** in `CombatManager._fire_item`'s per-target
> spawn path (spend the resolved target's stacks, scale the Delivery). Sequential drain in the
> deterministic sweep order; AOE-Mass not built. The Mass/Self cards + numbers are the owner's.


**Driver:** Pillar 1 **Mass** — a card "consumes X of a printed (stacked) spore type for a scaling effect." Also the **Self** masochist payoff and a possible **Spread** consume-verb ("variety spent as ammo"). The design's constraint: **only stacked spores are Mass-eligible** — timed spores (duration-extend) have no count to spend.

**Current state:** *reading* state at resolve already works — "scales with item count" is a computed modifier read at resolve time ([Item PRD](item_prd.md)); the **read-only** "reward being spored" payoffs (Self/Spread *without* spending) need **nothing new**. What's missing is *spending*: StatusManager exposes `apply` / tick / `resolve_incoming_damage` / `on_expire` / `gate` — **nothing removes N stacks as a cost**.

**The work:**

- **`StatusManager.consume(target, type, amount) → int`** (stacks actually removed). Removes up to `amount` additive stacks from the target's instance of `type`, returns how many were available-and-removed (so the consuming effect scales by what was present — "consume up to X", capped by the stacks there). Meaningful only for **additive-stack (periodic/stacked)** statuses; a no-op (returns 0) for timed/pool/static — matches the design's stacked-only Mass rule, so a Mass effect that names a timed spore simply gets 0 and the author has authored it wrong (don't special-case; the rule is "name a stacked spore").
- **Where the consume + scale happens depends on whose spores are spent — this is the key implementation decision:**
  - **Self-fuel** (Self pillar / masochist — consume the *owner's* own spores): the owner is known at fire, so this resolves in the **Item fire pipeline** (step 3, beside the enchant/status value modifiers — [Item PRD](item_prd.md)). Simple.
  - **Opponent-fuel** (Mass — consume the spores *stacked on the target*, e.g. the poison you applied to the enemy): the target is **not known at fire** — the Item declares a relative target-shape and the **Combat manager** resolves shape → target at Delivery spawn ([Item PRD](item_prd.md), [combat_prd](combat_prd.md)). So the read-fuel-and-scale step must land in the **Combat manager's per-target spawn path** (it already resolves the target there): resolve target → `StatusManager.consume(target, type, X)` → scale the payload by the returned count → the Delivery carries the scaled payload. The Item stays downward-clean (declares "I consume `type` from my target"); the manager executes it.
- **Determinism:** consume reads/mutates a count mid-step, but within-step order is deterministic (decision #24 — fixed type-ordered passes), and the spawn path runs inside the item-cooldown pass, so the consume order is bit-reproducible. No new RNG.

**Open / to decide when built:**
- **Atomicity / ordering:** read-then-remove must be atomic per effect; if two Mass effects target the same stack pile in one step, they consume in the deterministic sweep order (first drains, second sees the remainder) — confirm that's the desired feel, or whether a step should snapshot fuel first.
- **AOE Mass:** Mass is single-target by design ("one type stacked on one target"); consume across `all-opponents` (each? summed?) is **out of scope** unless content asks — flag, don't build.
- **Numbers** (consume amounts, scaling curves) are content — `ItemDef` / `Balance`, never baked here.

---

## Capability 2 — Evasion (the "acts but misses" seam, for blinding) — BUILT (2026-06-07)

> **Realized:** a `StatusEffect.causes_evasion()` hook (beside `absorb` / the damage modifiers)
> + `StatusManager.has_evasion(actor)`. A blinded actor still fires (cooldown resets), but in
> `CombatManager._fire_item` its **DAMAGE** Deliveries are marked `Delivery.evaded` at fire;
> they travel, then **fizzle on land** (`_land`) with no damage. `evaded` is the fizzle reason
> (vs. target-died) the VFX wall reads for the whiff tell (the tell itself is presentation —
> not yet drawn). Damage-only, total-miss (a timed status); no probabilistic roll. A
> placeholder `BLIND` status carries the flag; the real blinding spore (which status, duration,
> enemy-only) is the owner's content.


**Driver:** the **blinding** spore — "enemy misses for 3s." The design explicitly wants the **whiff** (a swung-and-missed attack with a clear tell against the dark), **not** silence (the enemy standing inert).

**Current state:** silence/`gate` exists, but gate = "the item **doesn't fire**" ([Item PRD](item_prd.md) step 1) → reads as inert, not as a miss. Combat has **no hit/miss concept** — a Delivery only fizzles when its target dies mid-flight ([combat_prd](combat_prd.md)). So "doesn't fire" ≠ "swings and misses."

**The work:**

- A **blinded-source → outgoing attack Deliveries fizzle** rule. While a blinding-class status is active on an actor, that actor still **fires normally** (the item's cooldown resets, the fire-emote plays), but its outgoing **damage** Deliveries **fizzle** (no landing) — reusing the existing fizzle path, with a **new cause**. Lands in the **Combat manager** at Delivery spawn/landing: check the *source* actor for the blinding status; if present, mark the Delivery to fizzle.
- **Per-status hook, content-tuned**: a status overrides `causes_evasion()` to return true; the engine provides the "source has an evasion status → its damage Deliveries fizzle" seam. *Which* status blinds + the duration + whether it's enemy-only are content.
- **Fizzle carries a reason.** The fizzle must distinguish *evaded* from *target-died* so the VFX wall can play a distinct miss tell (projectile goes wide / swing whiffs) vs. nothing. Small addition to the Delivery/fizzle path; the tell itself is presentation (VFX/content).

**Open / to decide when built:**
- **Scope of the miss:** default to **damage** Deliveries only (a blinded attacker's *attacks* whiff). Whether a blinded actor's non-damage outgoing effects (its own buffs) are also suppressed is a design call — default no; flag.
- **Total vs probabilistic:** the design's blinding is **total-miss-for-duration** (a timed status). A probabilistic chance-to-miss variant would need a seeded roll at Delivery time (the per-fight combat RNG exists — [decision #20](decision-log.md)); **not built unless content asks** — flag.
- **Considered & rejected:** modeling blinding as `gate` (don't fire). Cheaper, but gives "inert," and the design wants the whiff — so the fizzle seam is the right one. (If a future status wants "inert," that's `gate`, already built.)

---

## Capability 3 — Mid-fight roster add (summon) — BUILT, both sides (2026-06-07)

> **Realized (combat-side core):** the Combat manager is now two **side-rosters** (player
> side = the run-state actor + run-scoped `allies` + combat-scoped `_player_tokens`; enemy
> side = `enemies`). `add_actor(actor, on_player_side, in_front)` registers a body mid-fight
> (its Tickers + triggers) and front-inserts it (body-block / adds-in-front). A
> `Delivery.Kind.SUMMON` (shape SELF → the summoner) spawns a token from an `EnemyDef` and
> adds it to the summoner's side. **Loss stays the player dying** (a token doesn't save the
> run); **win is the whole enemy side dead** — so player tokens body-block but don't change
> win/loss. Fixed a latent bug surfaced here: a **dead actor's items kept firing** (invisible
> in 1-enemy fights, live for the 2-grunt elite). Combat-scoped tokens dissolve at teardown;
> the run-scoped player side survives. Placeholder token `EnemyDef` (Spore Thrall).
>
> **Stage B — BUILT:** run-scoped (persistent) **allies** live in the `RunManager` (`allies`
> roster, saved in the snapshot + rehydrated, full-healed between acts, dissolved at run end);
> the `Encounter` seeds each fight's CombatManager with them, and they persist HP across fights.
> So an ally can be **either scope** — combat-scoped (a summon) or run-scoped (persistent) — the
> shared combat roster serves both. The **acquisition** (a draftable `ally` category / a
> character-start ally) + the token/ally content stay the owner's. (Original deferral note below.)


**Driver:** Pillar 2 (**Summon**) tokens; the **lethal** spore's "spawn a token on kill" rider (the design decouples that spawn onto a relic/enchant — [`../design/spore_druid.md`](../design/spore_druid.md)).

**Current state — already a documented deferred item; do not re-spec, point to it:** the Combat manager assumes a **fixed roster** seeded at fight start ([Enemy PRD → open](enemy_prd.md), [decision-log → open](decision-log.md)); adding an `Actor` mid-combat (register its Tickers, subscribe its triggers, extend the ordering) is deferred until the boss **"summons-adds"** signature is built. The player side being a **party** (not a hardwired single actor) is **decision #22** ("treat each side as a roster, roster of 1 today; don't hardwire one player `Actor`").

**What this PRD adds:**

- The spore work is a **second, player-side consumer** of that same capability. When the roster work is scheduled (currently "revisit when boss summons-adds is built"), it must serve **both sides** — add an `Actor` to the **player's** side (a token), not just enemy adds. This is additive on #22, not a new abstraction (no über-`Entity` base — #22's guardrail).
- Two sub-needs, both already named: (a) run-state + snapshot allow >1 actor on the player side (#22 — cheap, no save migration); (b) the Combat manager add/remove-actor-mid-fight (register/deregister Tickers + triggers, re-order).
- **Consequence to record:** targeting is **leftmost-living** ([combat_prd](combat_prd.md)). A player token ordered *ahead* of the player body-blocks incoming single-target (saproling chump-block) — on-theme and free, but it makes **token ordering** a real decision (where in the player roster a summon inserts). Surface this when built.

**Until built:** the **lethal** spore ships as a **pure execute** (kill when stacked count ≥ target HP — no spawn); the Summon pillar and the lethal-spawn rider are **blocked** on this capability. So this PRD's *buildable-now* surface is **Capabilities 1 + 2**; Capability 3 stays deferred with the boss-summon work, now with a named second consumer.

---

## Note — lethal-as-execute: content or a seam? (verify when authored)

The **lethal** spore ("kill when stacked count ≥ target current HP") is **likely content** — a `StatusEffect` class whose `on_step` reads the target's current HP and applies a lethal payload (`take_damage`, optionally `unblockable` — both built). Confirm the `StatusEffect` hook surface can express a **target-HP-conditional** in `on_step`; if the hooks can't (today's set is "small, additive — extend as effects need" — [StatusManager](status_manager_prd.md)), that's a **small hook addition** (engine), not a rewrite. Resolve this *when lethal is actually authored*, not speculatively — same discipline as the stat-statuses seam (don't pre-build variants content hasn't chosen).

---

## Build order (recommendation)

Build **with the owner**, when the content needs each — each test-first, its own green commit, headless autotest as the regression backstop (handoff rhythm):

1. **Capability 1 (consume)** — the unlock for the second way into Spores (Mass) + the Self spend-payoffs; contained, no RNG. Highest value.
2. **Capability 2 (evasion)** — small; enables the already-defined **blinding** spore to read as a whiff.
3. **Capability 3 (roster)** — stays **deferred** with the boss summons-adds work; build once, serve both sides.

The applier commons (above) need none of this — they can be authored against the current engine immediately.

---

## Open / deferred

- **Capability 1:** consume atomicity/ordering within a step; AOE-Mass consume (out of scope unless asked). Above.
- **Capability 2:** miss scope (damage-only default); total vs probabilistic (total by design; probabilistic flagged, unbuilt). Above.
- **Capability 3:** the whole mid-fight roster capability (shared with boss summons-adds — #22 + [Enemy PRD](enemy_prd.md)); token insertion ordering. Above.
- **Lethal-as-execute:** content-vs-hook call, resolved when authored. Above.
- **All numbers** (consume amounts, blind duration, lethal threshold, token stats) are content — the `StatusEffect` class / `ItemDef` / `Balance`, never this doc (docs describe systems, not numbers — `CLAUDE.md`).

## Dependencies

- **StatusManager** — gains `consume(target, id, amount)` (Cap 1); a `StatusEffect.causes_evasion()` hook (Cap 2). Stateless facade unchanged otherwise.
- **Item** — declares "I consume `id` from my target" on a def; self-fuel consume resolves in the fire pipeline (Cap 1).
- **Combat manager** — opponent-fuel consume + payload scale in the per-target spawn path (Cap 1); the blinded-source fizzle + fizzle-reason at Delivery resolution (Cap 2); the deferred mid-fight roster add/remove + both-sides support (Cap 3).
- **combat_prd / Delivery** — reuses the fire → resolve → Delivery → land/fizzle model; Cap 2 adds a fizzle cause.
- **Driven by content:** the owner's spore `StatusEffect` classes + Spore Druid `ItemDef`s ([`../design/`](../design/spore_druid.md)) are what exercise these seams; this PRD is the engine they run on.
- Hub interface-contract entries added when each capability is built.
