# Dark Corridor — Enemy PRD

Content PRD. Sits under the [Architecture Map](architecture.md). **`Enemy` is not a new type** — it's an [`Actor`](actor_prd.md) built from an authored *enemy definition* and spawned by `Encounter` for a fight. This PRD covers only what's enemy-*specific*: the definition, the item pools, tier/authoring conventions, and boss signatures. Everything mechanical is `Actor` / `Item` / `StatusManager` / `Combat manager`.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

No hub entry — an Enemy exposes no interface of its own; it *is* an `Actor` (see the Actor hub contract).

---

## Purpose

Per the symmetry principle, player and enemy are the same `Actor`; the only difference is **board assembly** — the player drafts, an enemy's board is *authored*. So there is **no `Enemy` class**. An **enemy definition** (data) describes an Actor's starting HP, an authored board of Items, portrait/sprite, tier, and (for bosses) a signature; `Encounter` instantiates an `Actor` from it for the fight (fight-lifetime — see Actor PRD). There is **no enemy AI and no enemy-side targeting logic** — enemy boards auto-fire exactly like the player's, and the `Combat manager`'s relative target-shapes resolve "opponent" to the player.

What it **is not**: not a subclass of `Actor`; not a new combat mechanism; not the encounter/composition layer (`Encounter` places enemies + ordering).

---

## Enemy definition (data)

An enemy is authored as: **HP** (max), an **ordered board** of Item definitions, **portrait/sprite**, **tier** (regular / elite / boss), and an optional **signature** (boss). Data-defined; the format is content (deferred).

---

## Enemy items — a content category, not a mechanism

Mechanically these are **Items** (Item PRD). The enemy-specific part is *sourcing* (design):

- **Per-enemy attack item** — each enemy has its own attack Item (own value + icon), authored *with* the enemy; **not** drawn from a shared attack pool and **not** in the player draft pool.
- **Shared enemy utility pool** — on top, an enemy may carry a defensive/utility Item from a small shared enemy pool.
- Icons may visually overlap player items, but enemy items must **not be mechanically identical** to player items — keeps "their items" distinct from "mine."

These are authoring guidelines + separate pools, not new code — they're Items either way (so they fire, travel, and resolve through the same `Delivery` path).

---

## Tiers — authoring conventions (+ a selection tag)

Tier is mostly a convention for loadout size + synergy depth (design):

- **Regular:** 1–2 items (attack + buff is the default). Predictable, readable at a glance.
- **Elite:** 2–3 items, light synergy.
- **Boss:** 3–5 items with deliberate synergies + one signature.
- Late-act regulars trend toward small engines (escalation parallel to player power).

Tier is also a tag the `Encounter` / reward layer reads (elites grant relics, bosses end acts) — but those rewards are the Encounter / Run PRDs' concern, not here.

---

## Boss signatures — expressed through the loadout

Each boss has one signature mechanic (spike-armor, heal-over-time, summons-adds — design), expressed through items / enchants / statuses, **not bespoke combat code** wherever possible. Most are just a distinctive loadout (heal-over-time = a strong regen-applier; spike-armor = a thorns status).

- **Summons-adds needs a capability the spine doesn't have yet:** adding an `Actor` to the live fight **mid-combat** (register its item Tickers, subscribe its triggers, extend the ordering). The `Combat manager` currently assumes a **fixed roster** seeded at combat start. Deferred — see open, and the matching note in the Combat manager PRD.

---

## Composition (the Encounter's job, noted here)

1–4 enemies per fight (most 1–2); group fights are authored to give AOE a reason (design). Units have **no inherent position** — the `Encounter` spawns the set in a left-to-right **order** and hands it to the `Combat manager` (which owns ordering + targeting). "Tank in front of DPS," "adds before boss" are composition choices at the Encounter layer.

## Variety

Distinctness per encounter via the unit or the composition; most fights are 1–2 bodies, so the unit usually has to be interesting alone. "Make until the roster feels like enough" — no fixed count (design). All content; no mechanism here.

---

## Prototype scope

- One enemy definition (HP + a one-item authored board) instantiated as an `Actor` by a stand-in spawner, fighting the player in the `Combat manager`.
- Confirms the symmetry path end-to-end — an authored `Actor` auto-fires and is targeted like any actor.

**Not** in scope: tiers / elites / bosses, signatures, summoning, multi-body composition, the enemy pools' content.

---

## Open / deferred

- **Mid-fight roster changes (summoning)** — the `Combat manager` must eventually support adding / removing an `Actor` mid-combat (register/deregister its Tickers + triggers, re-order). Required by the boss "summons-adds" signature; deferred until bosses are built, so the fixed-roster assumption gets revisited then.
- **Enemy-definition data format**, the **enemy item pools'** content, **tier / signature** catalogues — content (the roster work).
- **Composition / ordering authoring — resolved (Encounter PRD):** a fight `Encounter` spawns the enemy set in left-to-right order and hands it to the `Combat manager`.
- **Elite / boss rewards** (relics) — the `Encounter` reports the reward; the `Run manager` fulfills it (Encounter / Run PRDs).

## Dependencies

- **Is an** `Actor` (built from an enemy definition); carries **Items** on its board.
- **Created by (above):** `Encounter` — instantiates the `Actor` from the definition, places it in the fight's ordering, hands it to the `Combat manager`.
- No interface of its own; no hub entry.
