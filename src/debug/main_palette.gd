class_name MainPalette
extends RefCounted
## The main palette's interface colours (docs/systems/interface_palette.md). Every `Colours` variable
## that the mechanic palette does not set is an interface colour, and takes one of the main palette's
## colours by its brightness: 0 is the palette's darkest colour, 1 its lightest. The project theme is
## then recoloured from them: every font colour is placed on the `UI_TEXT_*` colours and every flat
## panel colour on the `UI_PANEL_*` colours, by brightness. A dev tool, like the palette clamp.
##
## Most colours are copied when things are built. Cached keyword cards are recoloured here;
## `DebugPanels.apply_palettes` also recolours statuses in the current fight and tells scene colour
## rectangles through its `colours_changed` signal.

## What the darkest colour setting does with the picked colour.
enum Darkest { OFF, ADD, REPLACE }

## The interface colours by section, in the order the Colours tab shows them. Together with
## `MechanicPalette.NAMES` they are every colour in `colours.gd` (a test holds this).
const SECTIONS: Dictionary = {
  'Backgrounds': ['UI_BACKGROUND', 'UI_BACKGROUND_WEAR', 'UI_BACKGROUND_WEAR_LIGHT'],
  'Panels and tokens': ['UI_PANEL_SHADOW', 'UI_PANEL', 'UI_PANEL_EDGE', 'UI_PANEL_LIGHT', 'UI_PANEL_WEAR', 'UI_PANEL_WEAR_LIGHT', 'UI_TOKEN_CARD'],
  'Text': ['UI_TEXT_DISABLED', 'UI_TEXT_PRESSED', 'UI_TEXT_DIM', 'UI_TEXT_BUTTON', 'UI_TEXT'],
  'Buttons and highlight': ['UI_BUTTON', 'UI_BUTTON_LIGHT', 'UI_TEXT_BUTTON_DARK', 'UI_HIGHLIGHT'],
  'Health bars and item cells': ['HP_BAR_BG', 'HP_BAR_FILL', 'ENEMY_HP_BAR_BG', 'ENEMY_HP_BAR_FILL', 'HP_BAR_LINE', 'COOLDOWN_RING', 'COOLDOWN_FILL', 'ALLY_DOWNED', 'PORTRAIT_PLAYER', 'PORTRAIT_ENEMY'],
  'Statuses, items and relics': ['STATUS_WEAK', 'STATUS_VULNERABLE', 'STATUS_BLIND', 'STATUS_SILENCE', 'STATUS_SPORES', 'STATUS_DECAY', 'STATUS_EMPOWERED', 'ARCANE', 'RELIC_STONE_WARD', 'RELIC_VITAL_CHARM', 'RELIC_IRON_IDOL'],
  'Encounter types and map': ['BEAT_BOSS', 'BEAT_RELIC', 'BEAT_REST', 'BEAT_EVENT', 'BEAT_SHOP', 'BEAT_COMBAT', 'MAP_CURRENT_HALO'],
  'Tooltip': ['RARITY_COMMON', 'RARITY_UNCOMMON', 'RARITY_RARE', 'TOOLTIP_CHANGED'],
  'Paper burn': ['PAPER_BURN_EMBER', 'PAPER_BURN_CHAR', 'PAPER_BURN_SCORCH'],
}
## Theme colours are mapped onto these `Colours` variables, dark to light.
const PANEL_COLOURS: Array[String] = ['UI_PANEL_SHADOW', 'UI_PANEL', 'UI_PANEL_EDGE', 'UI_PANEL_LIGHT']
const TEXT_COLOURS: Array[String] = ['UI_TEXT_DISABLED', 'UI_TEXT_PRESSED', 'UI_TEXT_DIM', 'UI_TEXT_BUTTON', 'UI_TEXT']

static var _defaults: Dictionary = {}     # interface colour -> its colour in colours.gd
static var _brightness: Dictionary = {}   # interface colour -> brightness, when changed from its default
static var _applied: bool = false
static var _original_colours: Array[Array] = []    # [theme type, colour name, colour]
static var _original_icons: Array[Array] = []      # [theme type, icon name, texture]
static var _original_textures: Dictionary = {}     # StyleBoxTexture -> its texture
static var _original_flat_colours: Dictionary = {} # StyleBoxFlat -> [bg_color, border_color]
static var _original_palette_colours: Dictionary = {} # PaletteStyleBox -> its bg_color


## Every interface colour, section by section.
static func names() -> Array[String]:
  var result: Array[String] = []
  for section: String in SECTIONS:
    for variable: String in SECTIONS[section]:
      result.append(variable)
  return result


## The colours a palette file gives once the darkest colour setting is applied: `colour` added, or
## swapped in for the darkest colour (lowest OKLab lightness). No colours stay none.
static func palette_colours(file_colours: PackedColorArray, darkest: Darkest, colour: Color) -> PackedColorArray:
  var result: PackedColorArray = file_colours.duplicate()
  if result.is_empty():
    return result
  colour.a = 1.0
  match darkest:
    Darkest.ADD:
      if not result.has(colour):
        result.append(colour)
    Darkest.REPLACE:
      var darkest_index: int = 0
      for i in result.size():
        if PaletteLoader.to_oklab(result[i]).x < PaletteLoader.to_oklab(result[darkest_index]).x:
          darkest_index = i
      result[darkest_index] = colour
  return result


## The colour of `colours` an interface colour at `level` takes: the one nearest, in OKLab, to a grey
## at that brightness between the darkest (0) and lightest (1) of them. Its alpha is 1.
static func colour_at(colours: PackedColorArray, level: float) -> Color:
  var labs: Array[Vector3] = []
  var lowest: float = INF
  var highest: float = -INF
  for colour: Color in colours:
    var lab: Vector3 = PaletteLoader.to_oklab(colour)
    labs.append(lab)
    lowest = minf(lowest, lab.x)
    highest = maxf(highest, lab.x)
  var target: Vector3 = Vector3(lerpf(lowest, highest, clampf(level, 0.0, 1.0)), 0.0, 0.0)
  var best: int = 0
  for i in labs.size():
    if labs[i].distance_squared_to(target) < labs[best].distance_squared_to(target):
      best = i
  return colours[best]


## An interface colour's brightness: changed by `set_brightness`, or else the OKLab lightness of its
## colour in colours.gd.
static func brightness(variable: String) -> float:
  if _brightness.has(variable):
    return _brightness[variable]
  return default_brightness(variable)


## The OKLab lightness of an interface colour's colour in colours.gd.
static func default_brightness(variable: String) -> float:
  _capture_defaults()
  return clampf(PaletteLoader.to_oklab(_defaults[variable]).x, 0.0, 1.0)


## Set an interface colour's brightness. Takes effect on the next `apply`.
static func set_brightness(variable: String, level: float) -> void:
  _brightness[variable] = clampf(level, 0.0, 1.0)


## Every brightness back to its default.
static func reset_brightness() -> void:
  _brightness.clear()


## Whether `variable` is an interface colour.
static func is_interface_colour(variable: String) -> bool:
  return variable in names()


## Set every interface colour from `colours` by its brightness, keeping its alpha, and recolour the
## theme. With no colours, every interface colour keeps its default.
static func apply(colours: PackedColorArray) -> void:
  reset()
  if colours.is_empty():
    return
  var colours_script: Script = Colours
  for variable: String in names():
    var colour: Color = colour_at(colours, brightness(variable))
    colour.a = (_defaults[variable] as Color).a
    colours_script.set(variable, colour)
  _applied = true
  _recolour_theme(load(Prefs.THEME_PATH) as Theme)
  KeywordCatalog.refresh_colours()


## Put back the default interface colours and the theme's original images and colours.
static func reset() -> void:
  _capture_defaults()
  var colours_script: Script = Colours
  for variable: String in _defaults:
    colours_script.set(variable, _defaults[variable])
  if not _applied:
    return
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
  _original_colours.clear()
  _original_icons.clear()
  _original_textures.clear()
  _original_flat_colours.clear()
  _original_palette_colours.clear()
  _applied = false
  KeywordCatalog.refresh_colours()


# The colours.gd values, read before anything changes them. Only this class sets these variables.
static func _capture_defaults() -> void:
  if not _defaults.is_empty():
    return
  var colours_script: Script = Colours
  for variable: String in names():
    _defaults[variable] = colours_script.get(variable)


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
        # ramp. Checked before the StyleBoxFlat case below (PaletteStyleBox extends it).
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
static func _ramp(ramp_names: Array[String]) -> Array[Array]:
  var colours_script: Script = Colours
  var ramp: Array[Array] = []
  for variable: String in ramp_names:
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
