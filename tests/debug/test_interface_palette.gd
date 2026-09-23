extends GutTest
## Interface palettes set `Colours` variables by name and recolour the project theme; reset puts
## everything back (docs/systems/interface_palette.md).

const TEST_DIR: String = 'user://test_interface_palette'
const PALETTE_DIR: String = 'res://assets/palettes/new/ui'
const DEFAULT_PALETTE: String = PALETTE_DIR + '/ui-default.gpl'
const COLOURS_PATH: String = 'res://src/data/colours.gd'
# A .gpl carries no alpha (PaletteLoader forces it to 1), so a Colours variable that uses alpha is
# not settable from a palette and is left out of the files.
const NOT_SETTABLE: Array[String] = ['COOLDOWN_FILL']
# The theme itself holds no images any more (docs/systems/control_feedback.md), so the tests that
# cover the image brightness ramp add one of their own under this type and drop it afterwards.
const TEST_ART_TYPE: String = 'TestArt'


# `write_custom` writes `InterfacePalette.CUSTOM_PATH`, so the test that uses it puts the file back
# as it found it (or deletes the one it created) in after_each — per docs/systems/testing.md.
var _had_custom_file: bool = false
var _custom_file_text: String = ''


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _snapshot_custom_file()


func after_each() -> void:
  TestCleanup.reset_all_managers()
  _restore_custom_file()
  if _theme().has_stylebox('panel', TEST_ART_TYPE):
    _theme().clear_stylebox('panel', TEST_ART_TYPE)


func after_all() -> void:
  for file: String in DirAccess.get_files_at(TEST_DIR):
    DirAccess.remove_absolute(TEST_DIR.path_join(file))
  DirAccess.remove_absolute(TEST_DIR)


func _write_palette(file_name: String, lines: Array[String]) -> String:
  DirAccess.make_dir_recursive_absolute(TEST_DIR)
  var path: String = TEST_DIR.path_join(file_name)
  var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
  file.store_string('GIMP Palette\nName: test\n' + '\n'.join(lines) + '\n')
  file.close()
  return path


# `write_custom` writes `InterfacePalette.CUSTOM_PATH`, which is a real palette in the shipped
# folder, not a throwaway under TEST_DIR. Snapshot it before a test and put it back after.
func _snapshot_custom_file() -> void:
  _had_custom_file = FileAccess.file_exists(InterfacePalette.CUSTOM_PATH)
  if _had_custom_file:
    _custom_file_text = FileAccess.get_file_as_string(InterfacePalette.CUSTOM_PATH)


func _restore_custom_file() -> void:
  if _had_custom_file:
    var file: FileAccess = FileAccess.open(InterfacePalette.CUSTOM_PATH, FileAccess.WRITE)
    file.store_string(_custom_file_text)
    file.close()
  elif FileAccess.file_exists(InterfacePalette.CUSTOM_PATH):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(InterfacePalette.CUSTOM_PATH))


func _theme() -> Theme:
  return load(Prefs.THEME_PATH) as Theme


# A textured style in the theme, filled with the panel grey, so the image brightness-ramp recolour has
# something to work on. Dropped again in after_each.
func _add_test_art() -> StyleBoxTexture:
  var image: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
  image.fill(Colours.UI_PANEL)
  var stylebox: StyleBoxTexture = StyleBoxTexture.new()
  stylebox.texture = ImageTexture.create_from_image(image)
  _theme().set_stylebox('panel', TEST_ART_TYPE, stylebox)
  return stylebox


func _art_centre_pixel() -> Color:
  var stylebox: StyleBoxTexture = _theme().get_stylebox('panel', TEST_ART_TYPE) as StyleBoxTexture
  var image: Image = stylebox.texture.get_image()
  return image.get_pixel(floori(image.get_width() * 0.5), floori(image.get_height() * 0.5))


func _flat_panel_style() -> PaletteStyleBox:
  var worn: WornStyleBox = _theme().get_stylebox('panel', 'PanelFlat') as WornStyleBox
  return worn.base as PaletteStyleBox


func test_variable_name_turns_spaces_into_underscores() -> void:
  assert_eq(InterfacePalette.variable_name(' hp bar fill '), 'HP_BAR_FILL')
  assert_eq(InterfacePalette.variable_name('ui-panel'), 'UI_PANEL')


func test_only_gpl_files_naming_a_colours_variable_are_interface_palettes() -> void:
  assert_true(InterfacePalette.is_interface_palette(DEFAULT_PALETTE), 'the default interface palette')
  assert_false(InterfacePalette.is_interface_palette(_write_palette('hex.gpl', ['34 35 35\t222323'])),
    'colour names that match no Colours variable')
  assert_false(InterfacePalette.is_interface_palette('res://assets/palettes/good/waldgeist-32x.png'), 'a PNG strip')


func test_named_colours_are_read_from_a_gpl_file() -> void:
  var path: String = _write_palette('named.gpl', ['255 0 0\tattack', '0 0 255', '0 255 0 hp bar fill'])
  var named: Dictionary = PaletteLoader.load_named_colours(path)
  assert_eq(named.size(), 2, 'the unnamed colour is skipped')
  assert_eq(named['attack'], Color8(255, 0, 0))
  assert_eq(named['hp bar fill'], Color8(0, 255, 0))


func test_apply_sets_colours_and_reset_restores_them() -> void:
  var default_attack: Color = Colours.ATTACK
  var path: String = _write_palette('apply.gpl', ['10 20 30 attack', '1 2 3 not a colour'])
  assert_eq(InterfacePalette.apply(path), 1, 'only the name that matches a Colours variable counts')
  assert_eq(Colours.ATTACK, Color8(10, 20, 30))
  InterfacePalette.reset()
  assert_eq(Colours.ATTACK, default_attack, 'reset restores the default')


func test_default_palette_names_every_match_a_colour() -> void:
  var named: Dictionary = PaletteLoader.load_named_colours(DEFAULT_PALETTE)
  for colour_name: String in named:
    assert_true((Colours as Script).get(InterfacePalette.variable_name(colour_name)) is Color,
      '%s matches a Colours variable' % colour_name)


func _colours_variables() -> Array[String]:
  var regex: RegEx = RegEx.create_from_string('(?m)^static var ([A-Z0-9_]+): Color')
  var names: Array[String] = []
  for result: RegExMatch in regex.search_all(FileAccess.get_file_as_string(COLOURS_PATH)):
    names.append(result.get_string(1))
  return names


func _variables_named_by(path: String) -> Array[String]:
  var names: Array[String] = []
  for colour_name: String in PaletteLoader.load_named_colours(path):
    names.append(InterfacePalette.variable_name(colour_name))
  names.sort()
  return names


func test_default_palette_lists_every_settable_colour() -> void:
  var listed: Array[String] = _variables_named_by(DEFAULT_PALETTE)
  for variable: String in _colours_variables():
    if variable in NOT_SETTABLE:
      continue
    assert_true(variable in listed, '%s is listed in ui-default.gpl' % variable)


func test_every_interface_palette_sets_the_same_colours_as_the_default() -> void:
  # A palette may leave a colour out and keep its default, but a shipped one should not: a mechanic
  # or status added later would show its default colour inside someone else's scheme.
  var expected: Array[String] = _variables_named_by(DEFAULT_PALETTE)
  for file_name: String in DirAccess.get_files_at(PALETTE_DIR):
    if file_name.get_extension() != 'gpl' or file_name == DEFAULT_PALETTE.get_file():
      continue
    assert_eq(_variables_named_by(PALETTE_DIR.path_join(file_name)), expected,
      '%s names the same colours as ui-default.gpl' % file_name)


func test_write_custom_writes_a_full_palette_with_the_new_colour() -> void:
  InterfacePalette.write_custom('ATTACK', Color8(10, 20, 30))
  assert_true(FileAccess.file_exists(InterfacePalette.CUSTOM_PATH), 'the custom palette file is created')
  assert_eq(_variables_named_by(InterfacePalette.CUSTOM_PATH), _variables_named_by(DEFAULT_PALETTE),
    'the written file names the same variables as ui-default.gpl')
  var named: Dictionary = PaletteLoader.load_named_colours(InterfacePalette.CUSTOM_PATH)
  assert_eq(named['attack'], Color8(10, 20, 30), 'the written colour for that variable')
  assert_eq(Colours.ATTACK, Color8(10, 20, 30), 'the live value takes the new colour')


func test_theme_is_unchanged_when_the_palette_sets_no_panel_or_text_colours() -> void:
  _add_test_art()
  var pixel: Color = _art_centre_pixel()
  var button_text: Color = _theme().get_color('font_color', 'Button')
  InterfacePalette.apply(_write_palette('effects_only.gpl', ['10 20 30 attack']))
  assert_true(_art_centre_pixel().is_equal_approx(pixel), 'panel image unchanged')
  assert_true(_theme().get_color('font_color', 'Button').is_equal_approx(button_text), 'button text unchanged')


func test_panel_and_text_colours_recolour_the_theme_until_reset() -> void:
  var stylebox: StyleBoxTexture = _add_test_art()
  var original_texture: Texture2D = stylebox.texture
  var label_text: Color = _theme().get_color('font_color', 'Label')
  InterfacePalette.apply(_write_palette('panel.gpl', ['200 0 0 ui panel', '0 200 0 ui text']))
  var pixel: Color = _art_centre_pixel()
  assert_gt(pixel.r, pixel.g + 0.2, 'panel greys moved towards the panel colour')
  assert_eq(_theme().get_color('font_color', 'Label'), Color8(0, 200, 0), 'white label text became the text colour')
  InterfacePalette.reset()
  assert_eq(stylebox.texture, original_texture, 'reset restores the original image')
  assert_eq(_theme().get_color('font_color', 'Label'), label_text, 'reset restores the label colour')


func test_definitions_already_built_take_the_palette_until_reset() -> void:
  var weapon: ItemDef = ItemCatalog.get_def('cleaver')
  var potion: ConsumableDef = ConsumableCatalog.get_def('healing_draught')
  var relic: RelicDef = RelicCatalog.get_def('stone_ward')
  # The weapon / potion effects are mechanics, so their colour is the mechanic's (Colours.ATTACK /
  # HEAL), not an effect colour — read it through the registry, which tracks the palette.
  var default_attack: Color = MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color()
  InterfacePalette.apply(_write_palette('catalogs.gpl', [
    '10 20 30 attack',
    '40 50 60 heal',
    '70 80 90 relic stone ward',
  ]))
  assert_eq(ItemCatalog.get_def('cleaver'), weapon, 'the cached definition is kept')
  assert_eq(MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color(), Color8(10, 20, 30))
  assert_eq(weapon.panel_color, Color8(10, 20, 30))
  assert_eq(MechanicRegistry.get_mechanic(potion.effects[0].mechanic).color(), Color8(40, 50, 60))
  assert_eq(relic.panel_color, Color8(70, 80, 90))
  InterfacePalette.reset()
  assert_eq(MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color(), default_attack, 'reset restores the default')


func test_named_colour_rect_takes_its_colour_when_added() -> void:
  InterfacePalette.apply(_write_palette('rect.gpl', ['0 0 200 hp_bar_fill']))
  var rect: NamedColourRect = NamedColourRect.new()
  rect.colour_name = 'HP_BAR_FILL'
  add_child_autofree(rect)
  assert_eq(rect.color, Color8(0, 0, 200))


func test_named_colour_rect_follows_a_palette_applied_after_it_was_added() -> void:
  var rect: NamedColourRect = NamedColourRect.new()
  rect.colour_name = 'HP_BAR_FILL'
  add_child_autofree(rect)
  var default_colour: Color = rect.color
  DebugPanels.set_interface_palette(_write_palette('live.gpl', ['0 0 200 hp_bar_fill']))
  assert_eq(rect.color, Color8(0, 0, 200), 'took the new colour straight away')
  DebugPanels.set_interface_palette('')
  assert_eq(rect.color, default_colour, 'back to the default on reset')


func test_palette_style_box_follows_an_applied_palette_and_returns_to_default_on_reset() -> void:
  var style: PaletteStyleBox = _flat_panel_style()
  var default_colour: Color = style.bg_color
  InterfacePalette.apply(_write_palette('flat_panel.gpl', ['10 20 30 ui background']))
  assert_eq(style.bg_color, Color8(10, 20, 30), 'the flat panel fill follows its named Colours variable')
  InterfacePalette.reset()
  assert_eq(style.bg_color, default_colour, 'reset restores the fill')


func test_interface_images_are_clamped_to_the_palette_colours_until_reset() -> void:
  DebugPanels.set_interface_palette(_write_palette('clamp.gpl', [
    '10 20 30 attack',
    '10 20 30 heal',
    '200 0 0 ui panel',
  ]))
  var material: ShaderMaterial = InterfaceLook.material
  assert_eq(material.get_shader_parameter('colour_count'), 2, 'a colour named twice is one palette colour')
  var palette: Image = (material.get_shader_parameter('palette_rgb') as Texture2D).get_image()
  assert_true(palette.get_pixel(0, 0).is_equal_approx(Color8(10, 20, 30)), 'the first palette colour')
  DebugPanels.set_interface_palette('')
  assert_eq(material.get_shader_parameter('colour_count'), 0, 'no palette passes colours through')
