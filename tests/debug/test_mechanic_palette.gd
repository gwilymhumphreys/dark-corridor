extends GutTest
## Mechanic palettes set the ten mechanic colours in `Colours` by name; reset puts them back
## (docs/systems/interface_palette.md).

const TEST_DIR: String = 'user://test_mechanic_palette'


# `write_custom` writes `MechanicPalette.CUSTOM_PATH`, a real palette in the shipped folder, so the test
# that uses it puts the file back as it found it (docs/systems/testing.md).
var _custom_file_text: String = ''


func before_each() -> void:
  TestCleanup.reset_all_managers()
  _custom_file_text = FileAccess.get_file_as_string(MechanicPalette.CUSTOM_PATH)


func after_each() -> void:
  TestCleanup.reset_all_managers()
  var file: FileAccess = FileAccess.open(MechanicPalette.CUSTOM_PATH, FileAccess.WRITE)
  file.store_string(_custom_file_text)
  file.close()


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


func _variables_named_by(path: String) -> Array[String]:
  var names: Array[String] = []
  for colour_name: String in PaletteLoader.load_named_colours(path):
    names.append(MechanicPalette.variable_name(colour_name))
  names.sort()
  return names


func test_variable_name_turns_spaces_into_underscores() -> void:
  assert_eq(MechanicPalette.variable_name(' hp bar fill '), 'HP_BAR_FILL')
  assert_eq(MechanicPalette.colour_name('HP_BAR_FILL'), 'hp bar fill')


func test_only_gpl_files_naming_a_mechanic_are_mechanic_palettes() -> void:
  assert_true(MechanicPalette.is_mechanic_palette(MechanicPalette.DEFAULT_PATH), 'the default mechanic palette')
  assert_false(MechanicPalette.is_mechanic_palette(_write_palette('ui.gpl', ['10 20 30 ui text'])),
    'a palette naming only interface colours')
  assert_false(MechanicPalette.is_mechanic_palette('res://assets/palettes/good/waldgeist-32x.png'), 'a PNG strip')


func test_named_colours_are_read_from_a_gpl_file() -> void:
  var path: String = _write_palette('named.gpl', ['255 0 0\tattack', '0 0 255', '0 255 0 heal'])
  var named: Dictionary = PaletteLoader.load_named_colours(path)
  assert_eq(named.size(), 2, 'the unnamed colour is skipped')
  assert_eq(named['attack'], Color8(255, 0, 0))


func test_apply_sets_mechanic_colours_only_and_reset_restores_them() -> void:
  var default_attack: Color = Colours.ATTACK
  var default_text: Color = Colours.UI_TEXT
  var path: String = _write_palette('apply.gpl', ['10 20 30 attack', '1 2 3 ui text'])
  assert_eq(MechanicPalette.apply(path), 1, 'only the mechanic colour counts')
  assert_eq(Colours.ATTACK, Color8(10, 20, 30))
  assert_eq(Colours.UI_TEXT, default_text, 'an interface colour in the file is ignored')
  MechanicPalette.reset()
  assert_eq(Colours.ATTACK, default_attack, 'reset restores the default')


func test_the_default_palette_names_every_mechanic_at_its_default() -> void:
  var named: Dictionary = PaletteLoader.load_named_colours(MechanicPalette.DEFAULT_PATH)
  for variable: String in MechanicPalette.NAMES:
    var expected: Color = Colours.named(variable)
    var colour: Color = named[MechanicPalette.colour_name(variable)]
    assert_eq(colour, Color8(expected.r8, expected.g8, expected.b8), '%s is at its colours.gd default' % variable)


func test_every_mechanic_palette_names_every_mechanic() -> void:
  # A palette may leave a colour out and keep its default, but a shipped one should not: a mechanic
  # added later would show its default colour inside someone else's scheme.
  var expected: Array[String] = MechanicPalette.NAMES.duplicate()
  expected.sort()
  for file_name: String in DirAccess.get_files_at(MechanicPalette.FOLDER):
    if file_name.get_extension() != 'gpl':
      continue
    assert_eq(_variables_named_by(MechanicPalette.FOLDER.path_join(file_name)), expected,
      '%s names every mechanic colour' % file_name)


func test_write_custom_writes_every_mechanic_with_the_new_colour() -> void:
  MechanicPalette.write_custom('ATTACK', Color8(10, 20, 30))
  var expected: Array[String] = MechanicPalette.NAMES.duplicate()
  expected.sort()
  assert_eq(_variables_named_by(MechanicPalette.CUSTOM_PATH), expected, 'the file names every mechanic')
  assert_eq(PaletteLoader.load_named_colours(MechanicPalette.CUSTOM_PATH)['attack'], Color8(10, 20, 30))
  assert_eq(Colours.ATTACK, Color8(10, 20, 30), 'the live value takes the new colour')
  assert_eq(DebugPanels.mechanic_palette, MechanicPalette.CUSTOM_PATH, 'the custom palette is the active one')


func test_definitions_already_built_take_the_palette_until_reset() -> void:
  var weapon: ItemDef = ItemCatalog.get_def('cleaver')
  var potion: ConsumableDef = ConsumableCatalog.get_def('healing_draught')
  var default_attack: Color = MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color()
  MechanicPalette.apply(_write_palette('catalogs.gpl', ['10 20 30 attack', '40 50 60 heal']))
  assert_eq(MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color(), Color8(10, 20, 30))
  assert_eq(weapon.panel_color, Color8(10, 20, 30))
  assert_eq(MechanicRegistry.get_mechanic(potion.effects[0].mechanic).color(), Color8(40, 50, 60))
  MechanicPalette.reset()
  assert_eq(MechanicRegistry.get_mechanic(weapon.effects[0].mechanic).color(), default_attack, 'reset restores the default')
