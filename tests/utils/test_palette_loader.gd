extends GutTest
## PaletteLoader reads Lospec PNG strips and GIMP .gpl files into colours
## (docs/systems/palette_clamp.md).

const PNG_PATH: String = 'user://test_palette_strip.png'
const GPL_PATH: String = 'user://test_palette.gpl'


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for path: String in [PNG_PATH, GPL_PATH]:
    if FileAccess.file_exists(path):
      DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
  TestCleanup.reset_all_managers()


func test_reads_a_png_strip() -> void:
  # Three 4px swatches in one row. Each swatch's edge pixel differs from its centre, so the test
  # also checks the centre pixel is the one read.
  var expected: Array[Color] = [Color8(255, 0, 0), Color8(0, 128, 0), Color8(10, 20, 30)]
  var image: Image = Image.create_empty(12, 4, false, Image.FORMAT_RGBA8)
  image.fill(Color.WHITE)
  for i in expected.size():
    image.fill_rect(Rect2i(i * 4 + 1, 1, 3, 3), expected[i])
  image.save_png(PNG_PATH)
  var colours: PackedColorArray = PaletteLoader.load_palette(PNG_PATH)
  assert_eq(colours.size(), 3, 'one colour per swatch (width / height)')
  for i in expected.size():
    assert_true(colours[i].is_equal_approx(expected[i]), 'swatch %d is its centre pixel' % i)


func test_reads_a_gpl_file() -> void:
  var file: FileAccess = FileAccess.open(GPL_PATH, FileAccess.WRITE)
  file.store_string('GIMP Palette\n#Palette Name: Test\n#Colors: 2\nName: Test\nColumns: 4\n'
    + '8\t22\t17\t081611\n255 255 255 White\n')
  file.close()
  var colours: PackedColorArray = PaletteLoader.load_palette(GPL_PATH)
  assert_eq(colours.size(), 2, 'header and comment lines are skipped')
  assert_true(colours[0].is_equal_approx(Color8(8, 22, 17)), 'tab-separated colour line')
  assert_true(colours[1].is_equal_approx(Color8(255, 255, 255)), 'space-separated colour line')


func test_oklab_of_white_and_black() -> void:
  var white: Vector3 = PaletteLoader.to_oklab(Color.WHITE)
  var black: Vector3 = PaletteLoader.to_oklab(Color.BLACK)
  assert_almost_eq(white.x, 1.0, 0.001, 'white has lightness 1')
  assert_almost_eq(black.x, 0.0, 0.001, 'black has lightness 0')


func test_finds_the_bundled_palettes() -> void:
  var groups: Dictionary = PaletteLoader.find_palettes('res://assets/palettes')
  assert_true(groups.has(''), 'top-level files are grouped under an empty folder name')
  assert_true(groups.has('good'), 'subfolders are their own groups')
  assert_true(groups.has('new/world'), 'nested subfolders are found, named by their path')
  for folder: String in groups:
    for path: String in groups[folder]:
      assert_gt(PaletteLoader.load_palette(path).size(), 0, 'every bundled palette loads: ' + path)
