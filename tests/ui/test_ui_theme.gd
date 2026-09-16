extends GutTest
## The project theme: `dark_corridor.tres` is the default; its flat panel styles (Panel,
## PanelContainer, PanelFlat, PanelFramed, PanelSmall, PanelDetail, PanelPause, PanelSlot) have no border,
## corner radius or shadow and keep the content margins the textured styles they replaced used,
## wrapped in `WornStyleBox` so they still read as panels (docs/systems/ui_theme.md,
## docs/systems/panel_wear.md).

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


func test_tooltip_panel_keeps_the_pack_art() -> void:
  assert_true(_theme().get_stylebox('panel', 'TooltipPanel') is StyleBoxTexture, 'TooltipPanel stays textured')
