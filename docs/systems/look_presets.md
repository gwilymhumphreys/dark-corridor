# Look presets

A look preset is one file holding the whole look of the game: everything the debug panel's tabs set,
except the icon slots. The default preset is what the game starts with; the other presets are looks to compare, and the history keeps every past default.

**Location:** `src/data/look_presets.gd` (class `LookPresets`), the preset bar in `src/debug/preset_bar.*`
(class `PresetBar`), the "Take this part from" row in `src/debug/preset_part_row.*` (class
`PresetPartRow`). Presets in `assets/presets/`, past defaults in `assets/presets/history/`.

## Parts

A preset is a `ConfigFile` whose sections are written and read by the code that owns those settings.
A **part** is the set of settings one tab of the [debug panel](debug_panel.md) shows, so the seven
parts match the tabs except Icons. A part can cut across sections, so `LookPresets.PART_RULES` names
the part of each key by its section and the start of its name; the first matching rule wins.

| Part | Settings |
|---|---|
| Colours | `palette` and `interface_colours` ([interface_palette.md](interface_palette.md)); the `dither_` keys of `corridor_shader` and `interface_shader` |
| Corridor | `corridor_shader` and `corridor_environment` ([corridor_look.md](corridor_look.md)); `corridor_light` except the hit lights |
| Pictures | `interface_shader` except its `dither_`, `picture_` and `effects_` keys ([interface_look.md](interface_look.md)); `interface_glow` |
| Wear | `print_background`, `print_panel`, `print_frame`; the `picture_` keys of `interface_shader` |
| Layout | `print_layout` except the keys below |
| Effects | The `effects_` keys of `interface_shader`, the `hit_light` keys of `corridor_light`, the `paper_burn_` keys of `print_layout`, and `effects_trials` ([vfx_driver.md](vfx_driver.md)) |
| Motion | `control_highlight` and `control_settings` ([control_feedback.md](control_feedback.md)); the `card_`, `deck_peek`, `photo_`, `page_turn_` and `reward_spin` keys of `print_layout` |

| Section | Written and read by |
|---|---|
| `palette`, `interface_colours` | `DebugPanels.write_palettes` / `read_palettes` |
| `corridor_shader`, `corridor_light`, `corridor_environment` | `DebugPanels.write_corridor_look` / `read_corridor_look` |
| `interface_shader`, `interface_glow` | `InterfaceLook.write_look` / `read_look` |
| `print_panel`, `print_frame`, `print_layout` | `PrintLook.write_print_look` / `read_print_look` |
| `print_background` | `PrintLook.write_background_look` / `read_background_look` |
| `control_highlight`, `control_settings` | `ControlFeedback.write_look` / `read_look` |
| `effects_trials` | `VfxDriver.write_trials` / `read_trials` |

- Writing lists every setting, changed or not, so two presets can be compared key by key.
- Loading some parts starts from the current look (`capture()`), removes every key of those parts,
  copies in the file's values for them, and reads the result with every owner's reader. So a part's
  settings the file leaves out go back to their defaults (every effect off, the corridor scene's own
  light), an empty file turns a part off, and the other parts keep their settings.
- The `preset` section is not a setting. In the default preset, `source` names the preset it was
  made from, which names its history file later.

## Default and history

- `assets/presets/default.cfg` loads when `DebugPanels` starts, in every run including tests and
  `--shot` runs, before the start-up arguments. `TestCleanup` then resets every part to its defaults
  between tests.
- Make default first copies the old default to `assets/presets/history/<date>_<time>_<source>.cfg`,
  then writes the current look as the new default. Past defaults are never overwritten.
- The history is only listed by the debug panel; nothing else loads it.

## The preset bar

| Control | Does |
|---|---|
| Name field and dropdown | The dropdown lists the presets (default first, then by name), then the history, newest first. Picking one loads the whole look and puts its name in the field |
| Changed note | "changed" when the look differs from the preset last loaded or saved, "not saved" when none was. Checked every `CHECK_INTERVAL` while showing |
| Save | Saves the whole look under the typed name, replacing a preset of that name. Saving as `default` does what Make default does |
| Make default | Makes the look the default, keeping the old one in the history |
| Back to default | Loads the default preset |
| Delete | Deletes the preset named in the field, or the history file loaded under that name, on a second press ("Really delete?"). Refuses the default preset |
| Swap side | Moves the panel to the other side of the screen |

Each tab's "Take this part from" row loads only that tab's part from a preset or history file, or
turns the part off with "Everything off".

## Public API

| Member | Use |
|---|---|
| `LookPresets.Part`, `ALL_PARTS`, `PART_RULES`, `part_of(section, key)` | The seven parts and the part of each saved setting |
| `capture() -> ConfigFile`, `apply(file, parts)` | The current look as a file; set some parts from a file |
| `save_preset(path) -> Error`, `load_preset(path, parts) -> bool` | Save the whole look; load some or all parts |
| `load_default(folder) -> bool`, `make_default(source_name, folder, history_dir) -> String` | The default preset; `make_default` returns the history file's path, or `''` when there was no old default |
| `preset_path(name, folder)`, `preset_names(folder)`, `history_names(history_dir)` | File paths and the lists the panel shows |
| `delete_preset(path) -> Error` | Delete a preset or history file; `ERR_UNAUTHORIZED` for the default preset |
| `matches(path) -> bool` | Whether the current look matches a preset, numbers and colours within a small tolerance |

The folder arguments default to `PRESET_DIR` and `HISTORY_DIR`; tests pass `user://` folders.

Tests: `tests/debug/test_look_presets.gd`.
