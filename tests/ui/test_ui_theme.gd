extends GutTest
## The project theme: `dark_corridor.tres` is the default; its flat styles (Panel, PanelContainer,
## PanelFlat, PanelFramed, PanelSmall, PanelDetail, PanelPause, PanelSlot, and every Button state)
## have no border, corner radius or shadow and keep the content margins the textured styles they
## replaced used, wrapped in `WornStyleBox` so they still read as panels (docs/systems/ui_theme.md,
## docs/systems/panel_wear.md). No pack art is left in the theme (docs/systems/control_feedback.md).

const FLAT_PANEL_MARGINS: Dictionary = {
  'Panel': Vector4(8, 8, 8, 8),
  'PanelContainer': Vector4(8, 8, 8, 8),
  'PanelFlat': Vector4(8, 8, 8, 8),
  'PanelFramed': Vector4(10, 10, 10, 10),
  'PanelSmall': Vector4(8, 8, 8, 8),
  'PanelDetail': Vector4(12, 12, 12, 12),
  'PanelPause': Vector4(60, 50, 60, 50),
  'PanelSlot': Vector4(6, 6, 6, 6),
}
## Every Button state draws the same flat fill: hover, press and selection are drawn by the control
## highlight instead (docs/systems/control_feedback.md).
const BUTTON_STATES: Array[String] = ['normal', 'hover', 'pressed', 'focus', 'disabled']


func _theme() -> Theme:
  return load(Prefs.THEME_PATH) as Theme


func test_dark_corridor_theme_is_the_project_default() -> void:
  assert_eq(Prefs.THEME_PATH, 'res://assets/themes/dark_corridor.tres')
  assert_eq(ProjectSettings.get_setting('gui/theme/custom'), Prefs.THEME_PATH)
  assert_true(_theme() is Theme, 'the theme resource loads')


func test_the_theme_names_the_interface_font_as_its_default_font() -> void:
  var font: Font = _theme().default_font
  assert_not_null(font, 'the theme carries its own default font')
  assert_eq(font.resource_path, 'res://assets/fonts/rakkas.ttf', 'the default font is Rakkas')


func test_flat_panel_styles_have_no_border_and_keep_their_content_margins() -> void:
  for type: String in FLAT_PANEL_MARGINS:
    var worn: WornStyleBox = _theme().get_stylebox('panel', type) as WornStyleBox
    assert_not_null(worn, '%s panel is wrapped in a WornStyleBox' % type)
    var flat: StyleBoxFlat = worn.base as StyleBoxFlat
    assert_not_null(flat, '%s panel base is a flat style' % type)
    assert_eq(flat.border_width_left, 0, '%s has no border' % type)
    assert_eq(flat.border_width_top, 0, '%s has no border' % type)
    assert_eq(flat.corner_radius_top_left, 0, '%s has no corner radius' % type)
    assert_eq(flat.shadow_size, 0, '%s has no shadow' % type)
    var margins: Vector4 = FLAT_PANEL_MARGINS[type]
    assert_eq(worn.content_margin_left, margins.x, '%s content margin left unchanged' % type)
    assert_eq(worn.content_margin_top, margins.y, '%s content margin top unchanged' % type)
    assert_eq(worn.content_margin_right, margins.z, '%s content margin right unchanged' % type)
    assert_eq(worn.content_margin_bottom, margins.w, '%s content margin bottom unchanged' % type)


func test_every_button_state_draws_the_same_flat_fill() -> void:
  var normal: WornStyleBox = _theme().get_stylebox('normal', 'Button') as WornStyleBox
  assert_not_null(normal, 'the Button style is wrapped in a WornStyleBox')
  var flat: PaletteStyleBox = normal.base as PaletteStyleBox
  assert_not_null(flat, 'the Button style fills from a named colour')
  assert_eq(flat.colour_name, 'UI_BUTTON', 'the Button fill follows Colours.UI_BUTTON')
  for state: String in BUTTON_STATES:
    assert_eq(_theme().get_stylebox(state, 'Button'), normal, 'the %s state draws the same fill' % state)


func test_the_theme_draws_no_pack_art() -> void:
  for type: String in _theme().get_stylebox_type_list():
    for name: String in _theme().get_stylebox_list(type):
      var style: StyleBox = _theme().get_stylebox(name, type)
      var worn: WornStyleBox = style as WornStyleBox
      if worn != null:
        style = worn.base
      assert_false(style is StyleBoxTexture, '%s/%s is not pack art' % [type, name])
  assert_eq(_theme().get_icon_type_list().size(), 0, 'no pack art icons are left')
