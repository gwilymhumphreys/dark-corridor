class_name InterfacePalette
extends RefCounted
## Applies an interface palette (docs/systems/interface_palette.md): a GIMP `.gpl` file whose colour
## names match `Colours` variables. Each named colour replaces that variable, and the project theme is
## recoloured: every grey in its images and panel colours is mapped onto the UI_PANEL_* colours, and
## every font colour onto the UI_TEXT_* colours, by brightness. A dev tool, like the palette clamp.
##
## Most colours are copied when things are built. Cached keyword cards are recoloured here (item,
## relic and potion definitions read theirs on use);
## `DebugPanels.set_interface_palette` also recolours statuses in the current fight and tells scene
## colour rectangles through its `interface_palette_changed` signal.

## The palette the debug panel writes chosen colours into.
const CUSTOM_PATH: String = 'res://assets/palettes/new/ui/ui-custom.gpl'
## The default palette, in the same folder as `CUSTOM_PATH`: the set of names a custom palette names.
const DEFAULT_PATH: String = 'res://assets/palettes/new/ui/ui-default.gpl'
## Theme colours are mapped onto these `Colours` variables, dark to light.
const PANEL_COLOURS: Array[String] = ['UI_PANEL_SHADOW', 'UI_PANEL', 'UI_PANEL_EDGE', 'UI_PANEL_LIGHT']
const TEXT_COLOURS: Array[String] = ['UI_TEXT_DISABLED', 'UI_TEXT_PRESSED', 'UI_TEXT_DIM', 'UI_TEXT_BUTTON', 'UI_TEXT']

static var _applied: bool = false
static var _defaults: Dictionary = {}              # Colours variable name -> its colour before the palette
static var _original_colours: Array[Array] = []    # [theme type, colour name, colour]
static var _original_icons: Array[Array] = []      # [theme type, icon name, texture]
static var _original_textures: Dictionary = {}     # StyleBoxTexture -> its texture
static var _original_flat_colours: Dictionary = {} # StyleBoxFlat -> [bg_color, border_color]
static var _original_palette_colours: Dictionary = {} # PaletteStyleBox -> its bg_color


## The `Colours` variable a palette colour name refers to: 'hp bar fill' -> 'HP_BAR_FILL'.
static func variable_name(colour_name: String) -> String:
  return colour_name.strip_edges().to_upper().replace(' ', '_').replace('-', '_')


## Set one `Colours` variable in the custom palette and make that palette the active one, so what is
## on screen always matches the file. The file is written whole every time.
static func write_custom(variable: String, colour: Color) -> void:
  # `apply` resets the default colours first, so read the live values before anything is applied.
  var named: Dictionary = {}
  var colours_script: Script = Colours
  for name: String in PaletteLoader.load_named_colours(DEFAULT_PATH):
    var value: Variant = colours_script.get(variable_name(name))
    if value is Color:
      named[name] = value
  if not (colours_script.get(variable) is Color):
    push_warning('[InterfacePalette] no colour named %s in Colours' % variable)
    return
  named[_name_for(variable)] = colour
  PaletteLoader.save_named_colours(CUSTOM_PATH, named)
  DebugPanels.set_interface_palette(CUSTOM_PATH)


# The `ui-default.gpl` name whose variable is `variable`, so the written file keeps the default
# spellings: 'ATTACK' -> 'attack', 'HP_BAR_FILL' -> 'hp bar fill'.
static func _name_for(variable: String) -> String:
  for name: String in PaletteLoader.load_named_colours(DEFAULT_PATH):
    if variable_name(name) == variable:
      return name
  return variable.to_lower().replace('_', ' ')


## Whether the palette file at `path` can recolour the interface: a `.gpl` file with at least one colour
## named after a `Colours` variable.
static func is_interface_palette(path: String) -> bool:
  if path.get_extension().to_lower() != 'gpl':
    return false
  var colours_script: Script = Colours
  for colour_name: String in PaletteLoader.load_named_colours(path):
    if colours_script.get(variable_name(colour_name)) is Color:
      return true
  return false


## Apply the palette file at `path`, starting from the default colours. Returns how many of its
## colours matched a `Colours` variable; names that match none are reported with a warning.
static func apply(path: String) -> int:
  reset()
  var named: Dictionary = PaletteLoader.load_named_colours(path)
  var colours_script: Script = Colours
  for ramp_name: String in PANEL_COLOURS + TEXT_COLOURS:
    _defaults[ramp_name] = colours_script.get(ramp_name)
  var matched: int = 0
  for colour_name: String in named:
    var variable: String = variable_name(colour_name)
    var current: Variant = colours_script.get(variable)
    if not current is Color:
      push_warning('[InterfacePalette] %s: no colour named %s in Colours' % [path.get_file(), variable])
      continue
    if not _defaults.has(variable):
      _defaults[variable] = current
    colours_script.set(variable, named[colour_name])
    matched += 1
  _applied = true
  _recolour_theme(load(Prefs.THEME_PATH) as Theme)
  _refresh_catalogs()
  return matched


## Put back the default colours and the theme's original images and colours.
static func reset() -> void:
  if not _applied:
    return
  var colours_script: Script = Colours
  for variable: String in _defaults:
    colours_script.set(variable, _defaults[variable])
  var theme: Theme = load(Prefs.THEME_PATH) as Theme
  for entry: Array in _original_colours:
    theme.set_color(entry[1], entry[0], entry[2])
  for entry: Array in _original_icons:
    theme.set_icon(entry[1], entry[0], entry[2])
  for stylebox: StyleBoxTexture in _original_textures:
    stylebox.texture = _original_textures[stylebox]
  for stylebox: StyleBoxFlat in _original_flat_colours:
    stylebox.bg_color = _original_flat_colours[stylebox][0]
    stylebox.border_color = _original_flat_colours[stylebox][1]
  for stylebox: PaletteStyleBox in _original_palette_colours:
    stylebox.bg_color = _original_palette_colours[stylebox]
  _defaults.clear()
  _original_colours.clear()
  _original_icons.clear()
  _original_textures.clear()
  _original_flat_colours.clear()
  _original_palette_colours.clear()
  _applied = false
  _refresh_catalogs()


# Keyword cards copy `Colours` when built; recolour the cached ones. Item, relic and potion
# definitions read their colours on use, so they need nothing here.
static func _refresh_catalogs() -> void:
  KeywordCatalog.refresh_colours()


static func _recolour_theme(theme: Theme) -> void:
  var panel_ramp: Array[Array] = _ramp(PANEL_COLOURS)
  var text_ramp: Array[Array] = _ramp(TEXT_COLOURS)
  var recoloured: Dictionary = {}   # original texture -> recoloured copy, for images used more than once
  for type: String in theme.get_color_type_list():
    for colour_name: String in theme.get_color_list(type):
      var colour: Color = theme.get_color(colour_name, type)
      _original_colours.append([type, colour_name, colour])
      theme.set_color(colour_name, type, _mapped(colour, text_ramp))
  for type: String in theme.get_icon_type_list():
    for icon_name: String in theme.get_icon_list(type):
      var icon: Texture2D = theme.get_icon(icon_name, type)
      _original_icons.append([type, icon_name, icon])
      theme.set_icon(icon_name, type, _recoloured_texture(icon, panel_ramp, recoloured))
  # One stylebox can be listed under several types (every Button state shares one), so each is
  # recoloured once.
  for type: String in theme.get_stylebox_type_list():
    for stylebox_name: String in theme.get_stylebox_list(type):
      var stylebox: StyleBox = theme.get_stylebox(stylebox_name, type)
      # A WornStyleBox draws its wrapped `base`, not itself, so recolour that instead.
      var target: StyleBox = (stylebox as WornStyleBox).base if stylebox is WornStyleBox else stylebox
      if target is PaletteStyleBox:
        # A PaletteStyleBox follows its named Colours variable directly, not the panel brightness
        # ramp used for the remaining pack art (docs/systems/interface_palette.md). Checked before
        # the StyleBoxFlat case below (PaletteStyleBox extends it) so a style already classified
        # here on an earlier type never falls through to the generic flat recolour on a repeat.
        var palette_box: PaletteStyleBox = target as PaletteStyleBox
        if not _original_palette_colours.has(palette_box):
          _original_palette_colours[palette_box] = palette_box.bg_color
          var colours_script: Script = Colours
          var named_colour: Variant = colours_script.get(palette_box.colour_name)
          if named_colour is Color:
            palette_box.bg_color = named_colour
      elif target is StyleBoxTexture and not _original_textures.has(target):
        var texture_box: StyleBoxTexture = target as StyleBoxTexture
        _original_textures[texture_box] = texture_box.texture
        texture_box.texture = _recoloured_texture(texture_box.texture, panel_ramp, recoloured)
      elif target is StyleBoxFlat and not _original_flat_colours.has(target):
        var flat_box: StyleBoxFlat = target as StyleBoxFlat
        _original_flat_colours[flat_box] = [flat_box.bg_color, flat_box.border_color]
        flat_box.bg_color = _mapped(flat_box.bg_color, panel_ramp)
        flat_box.border_color = _mapped(flat_box.border_color, panel_ramp)


# [brightness of the default colour, current colour] for each variable in `names`, dark to light.
static func _ramp(names: Array[String]) -> Array[Array]:
  var colours_script: Script = Colours
  var ramp: Array[Array] = []
  for variable: String in names:
    ramp.append([(_defaults[variable] as Color).get_luminance(), colours_script.get(variable)])
  return ramp


# `colour` placed on `ramp` by its brightness, blending between the two nearest steps. Alpha is kept.
# With the default colours every step maps to itself, so the theme is unchanged.
static func _mapped(colour: Color, ramp: Array[Array]) -> Color:
  var level: float = colour.get_luminance()
  var result: Color = ramp[ramp.size() - 1][1]
  if level <= ramp[0][0]:
    result = ramp[0][1]
  else:
    for i in range(1, ramp.size()):
      if level <= ramp[i][0]:
        var weight: float = inverse_lerp(ramp[i - 1][0], ramp[i][0], level)
        result = (ramp[i - 1][1] as Color).lerp(ramp[i][1], weight)
        break
  result.a = colour.a
  return result


static func _recoloured_texture(texture: Texture2D, ramp: Array[Array], cache: Dictionary) -> Texture2D:
  if texture == null:
    return null
  if cache.has(texture):
    return cache[texture]
  var image: Image = texture.get_image()
  if image == null:
    return texture
  if image.is_compressed():
    image.decompress()
  image.convert(Image.FORMAT_RGBA8)
  for y in image.get_height():
    for x in image.get_width():
      image.set_pixel(x, y, _mapped(image.get_pixel(x, y), ramp))
  var result: ImageTexture = ImageTexture.create_from_image(image)
  cache[texture] = result
  return result
