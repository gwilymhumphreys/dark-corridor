extends GutTest
## Interface palettes set `Colours` variables by name and recolour the project theme; reset puts
## everything back (docs/systems/interface_palette.md).

const TEST_DIR: String = 'user://test_interface_palette'
const DEFAULT_PALETTE: String = 'res://assets/palettes/new/ui/ui-default.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


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


func _theme() -> Theme:
  return load(Prefs.THEME_PATH) as Theme


func _panel_centre_pixel() -> Color:
  # TooltipPanel stays textured pack art (unlike the flat panel types), so it still exercises the
  # image brightness-ramp recolour.
  var stylebox: StyleBoxTexture = _theme().get_stylebox('panel', 'TooltipPanel') as StyleBoxTexture
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
  var path: String = _write_palette('named.gpl', ['255 0 0\tdamage', '0 0 255', '0 255 0 hp bar fill'])
  var named: Dictionary = PaletteLoader.load_named_colours(path)
  assert_eq(named.size(), 2, 'the unnamed colour is skipped')
  assert_eq(named['damage'], Color8(255, 0, 0))
  assert_eq(named['hp bar fill'], Color8(0, 255, 0))


func test_apply_sets_colours_and_reset_restores_them() -> void:
  var default_damage: Color = Colours.DAMAGE
  var path: String = _write_palette('apply.gpl', ['10 20 30 damage', '1 2 3 not a colour'])
  assert_eq(InterfacePalette.apply(path), 1, 'only the name that matches a Colours variable counts')
  assert_eq(Colours.DAMAGE, Color8(10, 20, 30))
  InterfacePalette.reset()
  assert_eq(Colours.DAMAGE, default_damage, 'reset restores the default')


func test_default_palette_names_every_match_a_colour() -> void:
  var named: Dictionary = PaletteLoader.load_named_colours(DEFAULT_PALETTE)
  for colour_name: String in named:
    assert_true((Colours as Script).get(InterfacePalette.variable_name(colour_name)) is Color,
      '%s matches a Colours variable' % colour_name)


func test_theme_is_unchanged_when_the_palette_sets_no_panel_or_text_colours() -> void:
  var pixel: Color = _panel_centre_pixel()
  var button_text: Color = _theme().get_color('font_color', 'Button')
  InterfacePalette.apply(_write_palette('effects_only.gpl', ['10 20 30 damage']))
  assert_true(_panel_centre_pixel().is_equal_approx(pixel), 'panel image unchanged')
  assert_true(_theme().get_color('font_color', 'Button').is_equal_approx(button_text), 'button text unchanged')


func test_panel_and_text_colours_recolour_the_theme_until_reset() -> void:
  var stylebox: StyleBoxTexture = _theme().get_stylebox('panel', 'TooltipPanel') as StyleBoxTexture
  var original_texture: Texture2D = stylebox.texture
  var label_text: Color = _theme().get_color('font_color', 'Label')
  InterfacePalette.apply(_write_palette('panel.gpl', ['200 0 0 ui panel', '0 200 0 ui text']))
  var pixel: Color = _panel_centre_pixel()
  assert_gt(pixel.r, pixel.g + 0.2, 'panel greys moved towards the panel colour')
  assert_eq(_theme().get_color('font_color', 'Label'), Color8(0, 200, 0), 'white label text became the text colour')
  InterfacePalette.reset()
  assert_eq(stylebox.texture, original_texture, 'reset restores the original image')
  assert_eq(_theme().get_color('font_color', 'Label'), label_text, 'reset restores the label colour')


func test_definitions_already_built_take_the_palette_until_reset() -> void:
  var weapon: ItemDef = ItemCatalog.get_def(ItemCatalog.WEAPON)
  var potion: ConsumableDef = ConsumableCatalog.get_def(ConsumableCatalog.HEALING_DRAUGHT)
  var relic: RelicDef = RelicCatalog.get_def(RelicCatalog.STONE_WARD)
  var default_damage: Color = weapon.effects[0].color
  InterfacePalette.apply(_write_palette('catalogs.gpl', [
    '10 20 30 damage',
    '40 50 60 heal',
    '70 80 90 relic stone ward',
  ]))
  assert_eq(ItemCatalog.get_def(ItemCatalog.WEAPON), weapon, 'the cached definition is kept')
  assert_eq(weapon.effects[0].color, Color8(10, 20, 30))
  assert_eq(weapon.panel_color, Color8(10, 20, 30))
  assert_eq(potion.effects[0].color, Color8(40, 50, 60))
  assert_eq(relic.panel_color, Color8(70, 80, 90))
  InterfacePalette.reset()
  assert_eq(weapon.effects[0].color, default_damage, 'reset restores the default')


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
    '10 20 30 damage',
    '10 20 30 heal',
    '200 0 0 ui panel',
  ]))
  var material: ShaderMaterial = InterfaceLook.material
  assert_eq(material.get_shader_parameter('colour_count'), 2, 'a colour named twice is one palette colour')
  var palette: Image = (material.get_shader_parameter('palette_rgb') as Texture2D).get_image()
  assert_true(palette.get_pixel(0, 0).is_equal_approx(Color8(10, 20, 30)), 'the first palette colour')
  DebugPanels.set_interface_palette('')
  assert_eq(material.get_shader_parameter('colour_count'), 0, 'no palette passes colours through')
