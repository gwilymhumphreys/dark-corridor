# Look presets

A look preset is one file holding the whole look of the game: corridor look and its palette, interface
look with its palettes, print look and background wear. The default preset is what the game
starts with; the other presets are looks to compare, and the history keeps every past default.

**Location:** `src/data/look_presets.gd` (class `LookPresets`), the preset bar in `src/debug/preset_bar.*`
(class `PresetBar`), the "Take this part from" row in `src/debug/preset_part_row.*` (class
`PresetPartRow`). Presets in `assets/presets/`, past defaults in `assets/presets/history/`.

## Parts

A preset is a `ConfigFile` in four parts. Each part matches one tab of the
[debug panel](debug_panel.md), and each is written and read by the code that owns those settings, so a
part can be loaded on its own.

| Part | Sections | Written and read by |
|---|---|---|
| Corridor | `corridor_palette` (world palette, colour matching, dithering), `corridor_shader`, `corridor_light`, `corridor_environment` | `DebugPanels.write_corridor_palette` / `read_corridor_palette` ([palette_clamp.md](palette_clamp.md)), `DebugPanels.write_corridor_look` / `read_corridor_look` ([corridor_look.md](corridor_look.md)) |
| Interface | `interface_palette` (interface and portrait palettes, dithering switch), `interface_shader`, `interface_glow` | `DebugPanels.write_interface_palettes` / `read_interface_palettes` ([interface_palette.md](interface_palette.md)), `InterfaceLook.write_look` / `read_look` ([interface_look.md](interface_look.md)) |
| Print | `print_panel`, `print_frame`, `print_layout` | `PrintLook.write_print_look` / `read_print_look` ([print_frame.md](print_frame.md)) |
| Background | `print_background` | `PrintLook.write_background_look` / `read_background_look` ([background_wear.md](background_wear.md)) |

- Writing lists every setting, changed or not, so two presets can be compared key by key.
- Reading a part starts from that part's defaults (every effect off, the corridor scene's own light),
  so settings a file leaves out go back to their defaults. An empty file turns a part off.
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
| `LookPresets.Part`, `ALL_PARTS`, `PART_SECTIONS` | The four parts and their sections |
| `capture() -> ConfigFile`, `apply(file, parts)` | The current look as a file; set some parts from a file |
| `save_preset(path) -> Error`, `load_preset(path, parts) -> bool` | Save the whole look; load some or all parts |
| `load_default(folder) -> bool`, `make_default(source_name, folder, history_dir) -> String` | The default preset; `make_default` returns the history file's path, or `''` when there was no old default |
| `preset_path(name, folder)`, `preset_names(folder)`, `history_names(history_dir)` | File paths and the lists the panel shows |
| `delete_preset(path) -> Error` | Delete a preset or history file; `ERR_UNAUTHORIZED` for the default preset |
| `matches(path) -> bool` | Whether the current look matches a preset, numbers and colours within a small tolerance |

The folder arguments default to `PRESET_DIR` and `HISTORY_DIR`; tests pass `user://` folders.

Tests: `tests/debug/test_look_presets.gd`.
