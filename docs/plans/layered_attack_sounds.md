# Plan: layered attack sounds

At present a landing plays one sound, chosen at random from the folder the
mechanic names. This adds the two other layers a hit can carry — the weapon that
struck and the target that was struck — and a soft whoosh while a projectile is
in flight.

It also splits the weapon layer by whether the weapon is a blade or something
blunt.

Read with [sound_volume_per_folder.md](sound_volume_per_folder.md), which is
what lets these layers be balanced against each other. Build that one first.

## The three layers

| Layer | When it plays | Folder |
| --- | --- | --- |
| Travel | Once, when a projectile is launched, if it has travel time | `mechanics/<id>/travel` |
| Weapon | On landing, as now | `mechanics/attack/<weapon sound>` |
| Target | On landing, alongside the weapon layer | `combat/hurt`, or the actor's own folder |

`combat` is already one of `SfxManager`'s bus categories, so the target layer
needs no change there.

The weapon and target layers land at the same instant, so they are heard as one
event rather than two. The travel layer is a separate event earlier in time,
which is why it is quiet and why it only plays for a delivery that actually has
travel time.

## Weapon sound type

`ItemDef` gets a field naming the sound its attacks make:

```gdscript
var attack_sound: String = ''   # '' = the plain attack folder
```

This is separate from `types`, whose values are synergy labels that content may
key off later. `attack_sound` has no gameplay meaning and nothing reads it but
the sound layer. The starting values are `blade` and `blunt`, and the field
takes any folder name, so a third needs no code change.

The folders follow the existing scheme:

```
mechanics/attack/            plain, and the fallback for everything below
mechanics/attack/blade/
mechanics/attack/blade/shielded/
mechanics/attack/blunt/
mechanics/attack/blunt/shielded/
mechanics/attack/shielded/
```

`AttackMechanic.sound_key` builds the path from the firing item's
`attack_sound` and whether the target holds shield. A delivery with no firing
item, such as a thrown consumable, uses the plain path. The signature does not
change: `Delivery.source` is the firing `Item` and `Item.def` is its `ItemDef`,
so the field is already reachable.

## The fallback has to walk up

`play_sound` currently drops one folder level and then goes to the category
default. With another level in the path, an empty `attack/blade/shielded` would
skip `attack/blade` and `attack/attack`, landing on `mechanics/_default`. It has
to try each parent in turn before the category default, so a folder that has not
been filled in yet falls back to the nearest one that has.

## The target layer

`Actor` gets a presentation field alongside `portrait`, which it mirrors:

```gdscript
var hurt_sound: String = ''    # presentation: folder under assets/sound-effects/; '' = combat/hurt
```

`EnemyDef` and the character definitions gain the same field, and the places
that already copy `portrait` onto an actor copy this too. Combat ignores it, as
it ignores `portrait`.

An empty value plays `combat/hurt`, so the layer works before any enemy names
its own. Authoring per-enemy voices is content and is not part of this change.

The layer plays only for a delivery that damages an actor. A delivery targeting
an item has nothing to hurt, and a heal is not a hit. It is also skipped for an
evaded attack (`Delivery.evaded`) and for a visual-only delivery, which is how a
damage-over-time tick shows its number and is not a strike.

## The travel layer

`VfxDriver` already knows a delivery's travel duration and draws a projectile
for it. It gains a `_launched` set mirroring `_sounded`, so the travel sound
fires once per delivery, the first frame it is seen in flight, and is forgotten
when the manager drops the delivery.

Deliveries with no travel time play nothing. `SUMMON` and `CREATE_ITEM` are
skipped, as they are for drawing.

The travel layer is the one most likely to turn a cascade to mud, because it is
a second event per delivery rather than a second layer on the same instant. Its
folder volume is the control for that, and an empty folder silences it with no
code change.

## Changes

| File | Change |
| --- | --- |
| `src/content/items/item_def.gd` | `attack_sound`. |
| `src/content/mechanics/attack_mechanic.gd` | Build the path from the firing item and the shield check. |
| `src/content/enemies/enemy_def.gd` | `hurt_sound`. |
| `src/content/characters/character_def.gd` | `hurt_sound`. |
| `src/combat/actor.gd` | `hurt_sound`, beside `portrait`. |
| `src/run/encounter.gd`, `src/run/run_manager.gd`, `src/combat/combat_manager.gd` | Copy `hurt_sound` wherever they already copy `portrait`. |
| `src/autoloads/sfx_manager.gd` | Walk up the parents in the fallback. |
| `src/vfx/vfx_driver.gd` | The target layer on landing, the travel layer on launch, `_launched`. |
| `tests/ui/test_sfx_manager.gd` | The fallback walking up more than one level. |
| `tests/content/test_mechanic_registry.gd` | The attack path for blade, blunt, and each with shield. |
| `docs/systems/audio.md` | The three layers and the folder table. |
| `docs/systems/mechanics.md` | The Sound section. |
| `docs/systems/item.md` | `attack_sound` and how it differs from `types`. |

## Not in this change

- No per-enemy hurt sounds. The field exists; filling it is content.
- No whoosh for a delivery without travel time. There is nothing to cover.
- No layering on any mechanic but attack. Poison, burn and bleed tick rather
  than strike, and shield is applied rather than landed on someone.
