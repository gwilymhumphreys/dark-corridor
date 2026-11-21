extends GutTest
## The main palette's interface colours: each takes a palette colour by its brightness, the darkest
## colour setting adds or swaps in a colour, and the theme follows (docs/systems/interface_palette.md).

const COLOURS_PATH: String = 'res://src/data/colours.gd'
const GREYS: PackedColorArray = [Color(0.0, 0.0, 0.0), Color(0.5, 0.5, 0.5), Color(1.0, 1.0, 1.0)]


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _theme() -> Theme:
  return load(Prefs.THEME_PATH) as Theme


func _colours_variables() -> Array[String]:
  var regex: RegEx = RegEx.create_from_string('(?m)^static var ([A-Z0-9_]+): Color')
  var names: Array[String] = []
  for result: RegExMatch in regex.search_all(FileAccess.get_file_as_string(COLOURS_PATH)):
    names.append(result.get_string(1))
  return names


func test_every_colour_belongs_to_one_palette() -> void:
  var interface_colours: Array[String] = MainPalette.names()
  for variable: String in _colours_variables():
    var in_main: bool = variable in interface_colours
    var in_mechanic: bool = variable in MechanicPalette.NAMES
    assert_true(in_main != in_mechanic, '%s is set by exactly one palette' % variable)
  for variable: String in interface_colours:
    assert_true((Colours as Script).get(variable) is Color, '%s is a Colours variable' % variable)


func test_brightness_picks_the_darkest_and_lightest_at_the_ends() -> void:
  assert_eq(MainPalette.colour_at(GREYS, 0.0), Color(0.0, 0.0, 0.0))
  assert_eq(MainPalette.colour_at(GREYS, 1.0), Color(1.0, 1.0, 1.0))


func test_brightness_prefers_the_least_tinted_colour_at_its_level() -> void:
  var colours: PackedColorArray = [Color.BLACK, Color(0.6, 0.6, 0.6), Color(0.9, 0.3, 0.3), Color.WHITE]
  assert_eq(MainPalette.colour_at(colours, 0.6), Color(0.6, 0.6, 0.6), 'the grey, not the red of a similar brightness')


func test_add_and_replace_change_the_palette_colours() -> void:
  var dark: Color = Color(0.02, 0.02, 0.02)
  var added: PackedColorArray = MainPalette.palette_colours(GREYS, MainPalette.Darkest.ADD, dark)
  assert_eq(added.size(), 4, 'one colour added')
  assert_true(added.has(dark))
  var replaced: PackedColorArray = MainPalette.palette_colours(GREYS, MainPalette.Darkest.REPLACE, dark)
  assert_eq(replaced.size(), 3, 'the same number of colours')
  assert_false(replaced.has(Color(0.0, 0.0, 0.0)), 'the darkest is gone')
  assert_true(replaced.has(dark))
  assert_eq(MainPalette.palette_colours(PackedColorArray(), MainPalette.Darkest.ADD, dark).size(), 0,
    'no palette stays empty')


func test_apply_sets_interface_colours_keeping_alpha_until_reset() -> void:
  var default_text: Color = Colours.UI_TEXT
  var default_attack: Color = Colours.ATTACK
  MainPalette.set_brightness('UI_TEXT', 0.5)
  MainPalette.apply(GREYS)
  assert_eq(Colours.UI_TEXT, Color(0.5, 0.5, 0.5), 'text takes the middle grey')
  assert_almost_eq(Colours.COOLDOWN_FILL.a, 0.28, 0.001, 'a translucent colour keeps its alpha')
  assert_eq(Colours.ATTACK, default_attack, 'mechanic colours are left alone')
  MainPalette.reset()
  assert_eq(Colours.UI_TEXT, default_text, 'reset restores the text colour')


func test_no_colours_keep_the_defaults() -> void:
  var default_background: Color = Colours.UI_BACKGROUND
  MainPalette.set_brightness('UI_BACKGROUND', 1.0)
  MainPalette.apply(PackedColorArray())
  assert_eq(Colours.UI_BACKGROUND, default_background)


func test_the_theme_follows_the_text_and_panel_colours_until_reset() -> void:
  var label_text: Color = _theme().get_color('font_color', 'Label')
  var flat: PaletteStyleBox = (_theme().get_stylebox('panel', 'PanelFlat') as WornStyleBox).base as PaletteStyleBox
  var flat_fill: Color = flat.bg_color
  MainPalette.set_brightness('UI_TEXT', 0.5)
  MainPalette.set_brightness('UI_BACKGROUND', 1.0)
  MainPalette.apply(GREYS)
  assert_eq(_theme().get_color('font_color', 'Label'), Color(0.5, 0.5, 0.5), 'white label text became the text colour')
  assert_eq(flat.bg_color, Colours.UI_BACKGROUND, 'a flat panel follows its named colour')
  MainPalette.reset()
  assert_eq(_theme().get_color('font_color', 'Label'), label_text, 'reset restores the label colour')
  assert_eq(flat.bg_color, flat_fill, 'reset restores the flat panel')


func test_named_colour_rect_follows_the_palettes() -> void:
  var rect: NamedColourRect = NamedColourRect.new()
  rect.colour_name = 'HP_BAR_FILL'
  add_child_autofree(rect)
  var default_colour: Color = rect.color
  DebugPanels.set_palette_setting('hp_bar_fill', 1.0)
  DebugPanels.set_main_palette('res://assets/palettes/shortlist/2bit-demichrome.gpl')
  assert_eq(rect.color, Color8(233, 239, 236), 'took the lightest demichrome colour')
  DebugPanels.set_main_palette('')
  assert_eq(rect.color, default_colour, 'back to the default with no palette')
