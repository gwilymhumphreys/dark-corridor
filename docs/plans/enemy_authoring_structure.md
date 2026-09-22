# Plan: structure for authoring enemies

Get the enemy and character definitions into the shape the owner needs before writing real enemies:
one shared definition base, an image per enemy, enemy lists per act, a boss per act, and tests that
do not change when those lists are filled.

Related: [`../systems/enemy.md`](../systems/enemy.md), [`encounter_points_budget.md`](encounter_points_budget.md)
(step 7 is the content this prepares for), [`../systems/testing.md`](../systems/testing.md).

## What is there now

- `CharacterDef` and `EnemyDef` each declare `id`, `name_key`, `portrait` and `hurt_sound`. Only
  `EnemyDef` has `max_hp`; the player always starts on `Balance.PLAYER_START_HP`.
- An `Actor` is built from a definition in six places, each copying the same fields by hand:
  `Encounter._spawn_enemy`, `CombatManager._spawn_token`, `RunManager._make_ally`,
  `RunManager._make_starting_player`, `RunManager.rehydrate` and `AutoTestMode._build_fight`.
- Allies and summons are already built from `EnemyDef`, so enemies and allies are one kind of
  definition. Nothing changes there.
- Every enemy in the corridor gets a random picture from `MonsterImages.random_texture()`
  (`combat_corridor.gd`, two call sites). An ally slot shows `portrait`, or nothing when it is empty.
- `RunMap.enemy_pool(act)` returns an empty list, so the fight generator never runs.
- `RunMap.boss_for(act)` returns `FIGHT_BOSS` for every act, and `RunManager._draw_enemies` returns
  nothing for a boss, so every boss fight is the same authored enemy.

## Changes

### 1. A shared definition base

New `ActorDef` (`src/content/actor_def.gd`) holds the fields both kinds share:

| Field | Meaning |
|---|---|
| `id` | String id (decision #23) |
| `name_key` | Source English name, shown through `tr()` |
| `max_hp` | Starting health. Defaults to `Balance.PLAYER_START_HP`, so characters need not set it. |
| `image` | New. The `res://` path of the cut-out monster image the corridor shows. Empty means a random one. |
| `portrait` | The small picture for an ally slot or the player frame. Empty falls back to `image`. |
| `hurt_sound` | Unchanged. |

`CharacterDef` and `EnemyDef` extend it and keep only their own fields: the pool, starting kit and
stride for a character, and `item_ids` and `points()` for an enemy.

`ActorDef.make_actor() -> Actor` builds the Actor with its health and presentation fields.
`EnemyDef` overrides it to add the board. The six call sites above use it. The player's Actor keeps
an empty `display_name`, because the combat summary reads an empty name as the player ("You").
`rehydrate` still sets health from the snapshot afterwards.

`Actor` gets an `image` presentation field next to `portrait`.

### 2. The image in the corridor and the ally slot

- `combat_corridor.gd`: a new enemy uses `load(actor.image)` when it is set, and
  `MonsterImages.random_texture()` otherwise. The placeholder sprite shown before the fight's enemies
  are known has a random image, so when an enemy takes it over, its texture is replaced with the
  enemy's image. The debug `--monster-image=` override still wins over both.
- `ally_slot.gd` and the player frame in `combat_view_framed.gd`: show `portrait`, or `image` when
  the portrait is empty. The cut-out images are not square, so the ally slot needs a screenshot check.
- `MonsterImages` and the `run_screen.md` section describe the random picture as the fallback rather
  than the rule.

Adding an image stays a manual step: copy the file into `assets/monsters/`, run
`tools/cut_out_monsters.gd`, then `tools/import.sh`. The def points at the copy in `cut_out/`.

### 3. Enemy lists per act and a boss per act

New `EnemyPools` (`src/content/enemies/enemy_pools.gd`), built lazily like the catalogs so that
`FixtureContent` can write to it directly without the game needing test-only code:

- `regular(act) -> Array[String]`: the enemy ids a generated fight in that act draws from. The
  generator already applies the elite multiplier to the same list.
- `boss(act) -> Array[String]`: the enemy ids of that act's boss fight, left to right.

Both start empty, which keeps today's behaviour. `RunMap.enemy_pool(act)` returns `EnemyPools.regular(act)`.
`RunManager._draw_enemies` returns `EnemyPools.boss(act)` for a boss beat instead of nothing, and the
boss encounter's own `enemy_ids` apply only while that list is empty. The drawn ids are already
saved in the snapshot, so a resumed boss fight is unchanged. `FIGHT_BOSS` stays one encounter
definition; its frame text and relic reward are shared across the acts.

An enemy in no list is written but never met, which matches how item pools work.

### 4. Tests

- `FixtureContent.install()` sets every act's `regular` and `boss` lists to empty, and `uninstall()`
  clears them so they rebuild from the authored lists. Whole-run tests therefore keep the fight
  compositions they have today, however the authored lists are filled.
  - Fixture lists that hold fixture enemies would make the whole-run tests use the generator. They
    are left empty because the fixture enemy is small enough that a late-run target would always
    draw four of them, changing every whole-run result. The generator stays covered by the draw
    tests in `tests/run/test_encounter_budget.gd`.
- `test_every_act_pool_id_resolves` moves from `tests/run/test_encounter_budget.gd` to
  `tests/content/test_pool_integrity.gd`, since it reads authored content, and also checks the boss
  lists.
- A new content check fails when an authored `image` or `portrait` path does not load, in the same
  way `test_icons.gd` checks item icons.
- New engine tests on fixtures: `make_actor` copies every field, the corridor uses an actor's
  image, an ally slot falls back to the image, and a boss beat uses the act's boss list when it has
  one.

### 5. Docs

`enemy.md` (definition fields, per-act lists, bosses), `authoring.md` (how an enemy goes live, the
image step), `run_screen.md` and `corridors/corridor_3d.md` (image choice), `testing.md` (the
fixture lists), `encounter_points_budget.md` step 7, and the decision log if the owner treats the
shared base as a decision.

## Checks

`tools/import.sh` twice (two new `class_name` scripts), `tools/gut.sh` with no change in results
beyond the new tests, one `tools/autotest.sh --seed 2` to confirm nothing changed in a real run, and
a screenshot of an ally slot using a monster image as its portrait.

## Out of scope

- Writing any enemy, boss, or item. That is the owner's.
- Per-character starting health values. The field exists after this change, but every character
  keeps the default.
- A separate elite list. Elites draw from the regular list with a larger target.
