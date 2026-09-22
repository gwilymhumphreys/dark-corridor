# Dark Corridor — Enemy PRD

Content PRD. Sits under the [Architecture Map](architecture.md). **`Enemy` is not a new type** — it's an [`Actor`](actor.md) built from an authored *enemy definition* and spawned by `Encounter` for a fight. This PRD covers only what's enemy-*specific*: the definition, the item pools, tier/authoring conventions, and boss signatures. Everything mechanical is `Actor` / `Item` / `StatusManager` / `Combat manager`.

**Engine:** Godot 4.
**Date:** 2026-06-04. Pre-prototype.

No hub entry — an Enemy exposes no interface of its own; it *is* an `Actor` (see the Actor hub contract).

---

## Purpose

Per the symmetry principle, player and enemy are the same `Actor`; the only difference is **board assembly** — the player drafts, an enemy's board is *authored*. So there is **no `Enemy` class**. An **enemy definition** (data) describes an Actor's starting HP, an authored board of Items, portrait/sprite, tier, and (for bosses) a signature; `Encounter` instantiates an `Actor` from it for the fight (fight-lifetime — see Actor PRD). There is **no enemy AI and no enemy-side targeting logic** — enemy boards auto-fire exactly like the player's, and the `Combat manager`'s relative target-shapes resolve "opponent" to the player.

What it **is not**: not a subclass of `Actor`; not a new combat mechanism; not the encounter/composition layer (`Encounter` places enemies + ordering).

---

## Enemy definition (data)

An enemy, an ally and a summon are all authored as an `EnemyDef` (#23). It extends `ActorDef` (`src/content/actor_def.gd`), the base it shares with `CharacterDef`, and adds an **ordered board** of Item ids (`item_ids`). `EnemyDef.points()` prices it for encounter assembly — its health plus what its items spend, in the units of [`item_heuristics.md`](../design/item_heuristics.md).

| `ActorDef` field | Meaning |
|---|---|
| `id`, `name_key` | String id and source English name |
| `max_hp` | Starting health. Defaults to `Balance.PLAYER_START_HP`; `EnemyDef` defaults to `Balance.ENEMY_PLACEHOLDER_HP`. |
| `image` | The cut-out monster image the corridor shows (`assets/monsters/cut_out/`). Empty = a random one. |
| `portrait` | The picture an ally slot or the player frame shows. Empty = the image. |
| `hurt_sound` | The folder of recordings played when this actor is struck; empty uses the shared folder ([audio.md](audio.md#the-three-layers-of-an-attack)). |

`make_actor()` builds the `Actor` from these, and `EnemyDef` adds its board; every place that spawns an enemy, ally, summon or the player calls it. The presentation fields are copied onto the Actor and combat ignores them. A character's Actor keeps an empty `display_name`, because the combat summary reads an empty name as the player. **Tier / signature** are authoring conventions, not yet `EnemyDef` fields.

To give an enemy an image, copy the painting into `assets/monsters/`, run `tools/cut_out_monsters.gd` (usage in its header), run `tools/import.sh`, and set `image` to the copy in `cut_out/`.

## Which enemies each act uses

`EnemyPools` (`src/content/enemies/enemy_pools.gd`) holds two lists per act. An enemy in neither list is authored but never met.

- `REGULAR`: the enemies a generated fight in that act draws from, regular and elite alike (an elite has a larger points target). While an act's list is empty, its fights keep their encounter's authored enemies.
- `BOSS`: the enemies of the boss fight that ends the act, left to right. While it is empty, the boss fight keeps its encounter's authored enemies. The one boss encounter supplies the location text and the relic reward in every act.

---

## Enemy items — a content category, not a mechanism

Enemy items are ordinary **Items** (Item PRD) and work exactly like the player's (decision #43). An enemy can carry an item written for it or any other item, including one from a player pool. Enemy items are listed in `ItemCatalog` with every other item; an item written only for enemies is simply in no player pool.

An enemy's health and the damage of its items both grow through the run, roughly in step with the player's damage, healing and shields (#43). The size of an enemy in each act comes from the points ranges in [`encounter_points_budget.md`](../plans/encounter_points_budget.md).

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

- **Summons-adds — the capability is built** (the spore-engine's mid-fight roster add, Cap 3): the `Combat manager`'s two-roster model adds an `Actor` to the live fight (registers its item Tickers, subscribes its triggers, extends the ordering) via the `SUMMON` Delivery kind. The *boss content* that uses it is still the owner's. See [spore_engine.md](spore_engine.md) + [combat_manager.md](combat_manager.md).

---

## Composition (the Encounter's job, noted here)

1–4 enemies per fight (most 1–2); group fights are authored to give AOE a reason (design). Units have **no inherent position** — the `Encounter` spawns the set in a left-to-right **order** and hands it to the `Combat manager` (which owns ordering + targeting). "Tank in front of DPS," "adds before boss" are composition choices at the Encounter layer.

## Variety

Distinctness per encounter via the unit or the composition; most fights are 1–2 bodies, so the unit usually has to be interesting alone. "Make until the roster feels like enough" — no fixed count (design). All content; no mechanism here.

---

## Prototype scope

- One enemy definition (HP + a one-item authored board) instantiated as an `Actor` by a stand-in spawner, fighting the player in the `Combat manager`.
- Confirms the symmetry path end-to-end — an authored `Actor` auto-fires and is targeted like any actor.

**Not** in scope *then*: tiers / elites / bosses, signatures, summoning, multi-body composition, the enemy pools' content. *(Since built as mechanism with placeholder content: **summoning** + **mid-fight roster add**, **multi-body fights**, and several placeholder enemies. The real pools / tiers / boss signatures stay the owner's.)*

---

## Open / deferred

- **Mid-fight roster changes (summoning) — built** (spore-engine Cap 3): the `Combat manager` adds an `Actor` mid-combat (register its Tickers + triggers, re-order) via `add_actor` (combat-scoped token) / `register_ally` (run-scoped) + the `SUMMON` Delivery kind. The boss "summons-adds" *content* is the owner's. See [combat_manager.md](combat_manager.md) / [spore_engine.md](spore_engine.md).
- **Enemy-definition data format — resolved (#23):** typed GDScript `EnemyDef` + catalog. The **enemy item pools'** content + **tier / signature** catalogues — content (the roster work).
- **Composition / ordering authoring — resolved (Encounter PRD):** a fight `Encounter` spawns the enemy set in left-to-right order and hands it to the `Combat manager`.
- **Elite / boss rewards** (relics) — the `Encounter` reports the reward; the `Run manager` fulfills it (Encounter / Run PRDs).

## Dependencies

- **Is an** `Actor` (built from an enemy definition); carries **Items** on its board.
- **Created by (above):** `Encounter` — instantiates the `Actor` from the definition, places it in the fight's ordering, hands it to the `Combat manager`.
- No interface of its own; no hub entry.
