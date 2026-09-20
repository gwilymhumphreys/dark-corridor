# Plan — how sound effects are organised

One call, `SfxManager.play_sound('mechanics/attack')`, where the path is a folder under
`assets/sound-effects/`. Adding a sound means making a folder and dropping files in it, with
no code change. The volume sliders split into interface and game.

## Why it is built this way

Every sound today needs four separate edits in `sfx_manager.gd`: a directory constant, a
stream field, a line in `_load_ui_bank`, and a `play_*` helper. That is why `play_impact()`
ended up pointing at a single hardcoded file (`COMBAT_IMPACT_PATH`) while hover, click and
footsteps each got a folder of variants. With one sound per mechanic and more categories
coming, the same drift would keep happening.

Folder names match ids that already exist in the code. `mechanics/attack/` is the
`AttackMechanic.ID` the registry already holds, and `statuses/poison/` is the status id. This
means there is no second list of sound names for anyone to keep in step with the first.

A mechanic already carries its icon and its colour (`src/content/mechanics/mechanic.gd`). Its
sound is the same shape of property, so it goes in the same place rather than being named at
the call site.

## The folder scheme

| Folder | Key is | Bus |
|---|---|---|
| `ui/` | the interface action (`hover`, `click`) | Interface |
| `run/` | the run or map event (`victory`, `draft_pick`) | Interface |
| `world/` | the corridor sound (`footsteps/steps`) | World |
| `mechanics/` | the mechanic id (`attack`, `bleed`) | World |
| `statuses/` | the status id (`weak`, `vulnerable`) | World |
| `combat/` | a combat event with no id of its own (`death`, `shield_break`) | World |

The first path segment picks the bus. Interface sounds are not in the room and stay dry;
everything else goes through World, which carries the corridor reverb.

Every folder holds one or more recordings of the same sound. Each play picks one at random
and applies the existing pitch jitter, exactly as the hover and click banks do now.

---

## Section 1 — bus split and volume sliders

`World` currently sends into `Effects`, so one slider covers interface and game sound
together. Splitting them needs one more level.

```
Master
├─ Music
├─ Interface
└─ Game
   └─ World  (reverb, sends to Game)
```

`Game` has nothing routed directly to it yet. It exists as the bus the slider sits on, so a
combat sound that should not have reverb has somewhere dry to go without another bus change.

### `default_bus_layout.tres`

Rename `Effects` to `Interface`, keeping its send to `Master`. Add `Game` sending to
`Master`. Move `World` after `Game` and change its send from `Effects` to `Game`, keeping its
`AudioEffectReverb` unchanged. Bus order must be Master, Music, Interface, Game, World,
because a send can only name a bus already defined.

### `src/autoloads/prefs.gd`

In `AUDIO_BUSES` and `AUDIO_DEFAULTS`, replace the `effects` key with `interface` and `game`,
both mapping to the bus of the same name and both defaulting to the value `effects` used.
Update the class comment, which lists the keys.

No migration. An unknown stored key already falls back to its default, so an existing
settings file reverts those two to their defaults once.

### `src/scenes/screens/settings_screen.gd` and `.tscn`

In the scene, rename `Panel/Rows/EffectsRow` to `InterfaceRow` with the label
`Interface volume`, and add a `GameRow` after it copying the same `HBoxContainer` with a
`Label` and a `Slider`, labelled `Game volume`. In the script's `SLIDERS` constant, replace
`'EffectsRow': 'effects'` with `'InterfaceRow': 'interface'` and `'GameRow': 'game'`. Update
the class comment, which lists the sliders.

The labels are static `.tscn` text, so they auto-translate. Run `tools/pot.sh` afterwards
(`docs/systems/localization.md`).

### Tests that name the old key or node

- `tests/ui/test_prefs.gd`: `test_set_volume_applies_to_the_bus` sets the `effects` key and
  asserts on the Effects bus. Change it to `interface`, and add the same assertion for
  `game`.
- `tests/ui/test_cursor.gd`: its list of clickable controls holds the node path
  `Panel/Rows/EffectsRow/Slider`, which the rename breaks.

### `src/autoloads/sfx_manager.gd`

Replace `BUS_EFFECTS` with `BUS_INTERFACE: String = 'Interface'` and add
`BUS_GAME: String = 'Game'`. Update its two uses and the class comment, which says interface
sounds stay dry on the Effects bus.

### Docs

`docs/systems/audio.md`: the Buses section and the Prefs section both name the old three
keys and the `World` to `Effects` route.

### Verify

`tools/import.sh`, then `tools/gut.sh`. Launch and check the settings screen shows four
sliders and that each one changes what it says it changes.

---

## Section 2 — `play_sound` and the bank cache

Depends on Section 1 for the bus names.

### `src/autoloads/sfx_manager.gd`

Add:

```gdscript
const SOUND_ROOT: String = 'res://assets/sound-effects/'
## The first path segment picks the bus. An unrecognised one uses Interface and warns once.
const BUS_BY_CATEGORY: Dictionary = {
  'ui': BUS_INTERFACE,
  'run': BUS_INTERFACE,
  'world': BUS_WORLD,
  'mechanics': BUS_WORLD,
  'statuses': BUS_WORLD,
  'combat': BUS_WORLD,
}
## Played when a folder does not exist, so a newly authored mechanic or status is never
## silent. Looked for as the category plus this name.
const FALLBACK_FOLDER: String = '_default'
## Folders loaded at boot rather than on first play, because their sound answers an input
## and a load hitch would read as lag.
const PRELOAD_FOLDERS: Array[String] = ['ui/hover', 'ui/click', 'world/footsteps/steps']
```

Public API:

```gdscript
## Play one sound from the folder `path` under assets/sound-effects/, picked at random from
## the recordings in it. A negative pitch picks a random jitter. Returns the polyphonic
## stream id, or -1 if nothing played.
func play_sound(path: String, pitch: float = -1.0, volume_db: float = 0.0) -> int

## Same, dropped if the same `key` played within COOLDOWN_TIME.
func play_sound_guarded(key: String, path: String, pitch: float = -1.0,
    volume_db: float = 0.0) -> void

## The bus a folder path plays on. Public so it can be tested without an audio device.
func bus_for(path: String) -> String
```

Behaviour of `play_sound`:

1. A silent run returns -1 before touching the filesystem. Move the dummy-driver and
   `SILENT_ARGS` checks currently inside `_load_ui_bank` into a `_silent` bool set in
   `_ready`.
2. Load the folder on first use and cache the result in a `_banks` dictionary keyed by path.
   The existing `_load_folder` takes a full `res://` directory path ending in a slash, so the
   folder to load is `SOUND_ROOT + path + '/'`.
   Cache an empty result too, so a missing folder is not rescanned on every hit.
3. An empty bank falls back to the category's `FALLBACK_FOLDER`. If that is empty as well,
   return -1.
4. A missing folder and an unrecognised category each call `push_warning` once per path, in
   debug builds only, and the path is recorded so it does not warn again.

Replace the two hardcoded players with lazily created ones, keyed by bus name in `_players`
and `_playbacks` dictionaries, made by the existing `_make_poly_player`. A bus nothing plays
on gets no player, which also keeps the headless leak described in `_ensure_playing` from
coming back. `_exit_tree` iterates the dictionaries.

Keep `play`, `play_world`, `play_guarded` and `play_guarded_world` with their current
signatures, routed through the new per-bus players. `ui_juice.gd` calls `play_guarded` with
its own per-node stream and must keep working unchanged.

Rewrite the three existing helpers over the new call and delete what they used:

```gdscript
func play_ui_hover() -> void:
  play_sound_guarded('ui_hover', 'ui/hover')
```

`play_ui_click` and `play_footstep` follow the same shape. Delete `UI_HOVER_DIR`,
`UI_CLICK_DIR`, `WORLD_FOOTSTEP_DIR`, `_ui_hover_streams`, `_ui_click_streams`,
`_footstep_streams` and `_load_ui_bank`; `_ready` loads each of `PRELOAD_FOLDERS` into the
bank cache instead.

### Tests

`tests/` gains cases for `bus_for`: each category maps to its bus, a nested path uses its
first segment, and an unrecognised category returns the Interface bus. These are pure string
work, so they pass under the headless dummy driver where nothing plays.

### Docs

`docs/systems/audio.md`: rewrite the SfxManager API list and replace the Variant folders
section with the folder table from this plan.

### Verify

`tools/import.sh`, then `tools/gut.sh`. Launch and check hover, click and footsteps still
sound.

---

## Section 3 — mechanics name their own sound

Depends on Section 2.

### `src/content/mechanics/mechanic.gd`

Add a method beside `color()`, which has the same shape and the same reason for being a
function rather than a field:

```gdscript
## The folder played when a delivery of this mechanic lands. A mechanic with no folder of
## its own falls back to the mechanics fallback folder.
func sound_key() -> String:
  return 'mechanics/' + id
```

No subclass overrides it. A new mechanic gets its sound by existing.

### `src/vfx/vfx_driver.gd`

In `_sound_new_impacts`, replace `SfxManager.play_impact()` with `play_sound` on the key the
delivery implies:

```gdscript
func _sound_key_of(d: Delivery) -> String:
  if d.kind == Delivery.Kind.MECHANIC and MechanicRegistry.has(d.mechanic):
    return MechanicRegistry.get_mechanic(d.mechanic).sound_key()
  if d.kind == Delivery.Kind.APPLY_STATUS and d.status_id != '':
    return 'statuses/' + d.status_id
  return ''
```

`play_sound('')` returns -1 and warns. That last branch is only reached by a delivery naming
a mechanic the registry does not have; summons and created items are already skipped earlier
in `_sound_new_impacts` because they have no impact drawn.

Unguarded, unlike the old `play_impact`. A cascade of thirty hits should be heard as thirty
hits; the cooldown guard would drop most of them. Combat plays on the World bus and the
interface on Interface, so each has its own polyphony and a burst cannot cut off a click.

### `src/autoloads/sfx_manager.gd`

Delete `COMBAT_IMPACT_PATH`, `_impact_stream` and `play_impact()`. Nothing else calls them.

### Docs

- `docs/systems/mechanics.md`: mechanics carry a sound folder named after their id.
- `docs/systems/vfx_driver.md`: the impact sound is chosen from the delivery, unguarded.
- `docs/systems/audio.md`: `play_impact` is gone from the API list.

### Verify

`tools/import.sh`, then `tools/gut.sh`. Run a fight and confirm hits are audible once the
Section 4 files exist, and that nothing errors before they do.

---

## Section 4 — the attack sounds (not delegated)

Chosen through the `sfx` skill, so this stays here.

- Four to six variants into `assets/sound-effects/mechanics/attack/`, kept as both `.wav`
  and `.mp3`, from one recordist so they sit together.
- Trim the lead-in (`sfx.py lead-in`), since the sound answers an item firing.
- Reimport, then add each to `docs/design/asset_credits.md`.
- `docs/design/art_audio.md` says combat has no sound yet; update it.

## Left to hear rather than decide now

- How loud one attack should be. Thirty landing together sum in amplitude and will be much
  louder than one. `play_sound` takes `volume_db`, so this is a number to tune.
- Whether the corridor reverb smears a cascade. The fix if it does is less wet on the World
  bus, or routing mechanic sounds dry to Game.
- Whether `run/` belongs on Interface or Game. It is one line in `BUS_BY_CATEGORY`.
