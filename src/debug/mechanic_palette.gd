class_name MechanicPalette
extends RefCounted
## Applies a mechanic palette (docs/systems/interface_palette.md): a GIMP `.gpl` file naming the ten
## mechanic colours in `Colours` ('attack' sets `Colours.ATTACK`). Every other colour comes from the
## main palette (`MainPalette`). A dev tool, like the palette clamp.
##
## Mechanics read their colour on use, and statuses copy it when created;
## `DebugPanels.apply_palettes` recolours statuses in the current fight.

## The folder of mechanic palettes, listed by the Colours tab.
const FOLDER: String = 'res://assets/palettes/mechanics'
## The palette the debug panel writes chosen colours into.
const CUSTOM_PATH: String = FOLDER + '/mechanics-custom.gpl'
## The palette holding every mechanic at its `colours.gd` default.
const DEFAULT_PATH: String = FOLDER + '/mechanics-default.gpl'
## The `Colours` variables a mechanic palette sets, in the order the files list them.
const NAMES: Array[String] = ['ATTACK', 'SHIELD', 'HEAL', 'POISON', 'BURN', 'BLEED', 'REGEN', 'CRIT', 'CHARGE', 'DECHARGE']

static var _defaults: Dictionary = {}   # Colours variable name -> its colour before a palette


## The `Colours` variable a palette colour name refers to: 'hp bar fill' -> 'HP_BAR_FILL'.
static func variable_name(name_in_file: String) -> String:
  return name_in_file.strip_edges().to_upper().replace(' ', '_').replace('-', '_')


## The name a palette file uses for a `Colours` variable: 'HP_BAR_FILL' -> 'hp bar fill'.
static func colour_name(variable: String) -> String:
  return variable.to_lower().replace('_', ' ')


## Whether the file at `path` is a mechanic palette: a `.gpl` file naming at least one of `NAMES`.
static func is_mechanic_palette(path: String) -> bool:
  if path.get_extension().to_lower() != 'gpl':
    return false
  for name: String in PaletteLoader.load_named_colours(path):
    if variable_name(name) in NAMES:
      return true
  return false


## Apply the palette file at `path` (none for ''), starting from the default colours. Returns how many
## of the file's colours set a mechanic colour; other names are reported with a warning.
static func apply(path: String) -> int:
  reset()
  if path == '':
    return 0
  var colours_script: Script = Colours
  var matched: int = 0
  var named: Dictionary = PaletteLoader.load_named_colours(path)
  for name: String in named:
    var variable: String = variable_name(name)
    if not variable in NAMES:
      push_warning('[MechanicPalette] %s: %s is not a mechanic colour' % [path.get_file(), name])
      continue
    _defaults[variable] = colours_script.get(variable)
    colours_script.set(variable, named[name])
    matched += 1
  KeywordCatalog.refresh_colours()
  return matched


## Put back the default mechanic colours.
static func reset() -> void:
  var colours_script: Script = Colours
  for variable: String in _defaults:
    colours_script.set(variable, _defaults[variable])
  _defaults.clear()
  KeywordCatalog.refresh_colours()


## The live mechanic colours without repeats, for snapping the combat effects.
static func colours() -> PackedColorArray:
  var result: PackedColorArray = PackedColorArray()
  var colours_script: Script = Colours
  for variable: String in NAMES:
    var colour: Color = colours_script.get(variable)
    if not result.has(colour):
      result.append(colour)
  return result


## Set one mechanic colour in the custom palette and make that palette the active one, so what is on
## screen always matches the file. The file is written whole every time, from the live colours.
static func write_custom(variable: String, colour: Color) -> void:
  if not variable in NAMES:
    push_warning('[MechanicPalette] %s is not a mechanic colour' % variable)
    return
  var named: Dictionary = {}
  var colours_script: Script = Colours
  for name: String in NAMES:
    named[colour_name(name)] = colours_script.get(name)
  named[colour_name(variable)] = colour
  PaletteLoader.save_named_colours(CUSTOM_PATH, named)
  DebugPanels.set_mechanic_palette(CUSTOM_PATH)
