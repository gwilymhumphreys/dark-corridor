class_name KeywordChip
extends PanelContainer
## An inline keyword chip in the main panel's body (docs/systems/tooltips.md): a small framed tag
## (icon + tinted name) standing in for a status / mechanic the item references. Discrete Control
## (not RichTextLabel markup) so it can carry Godot's built-in per-keyword tooltip — hovering it
## pops the keyword's full card, positioned + clamped by the engine (_make_custom_tooltip).

const KEYWORD_CARD: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_card.tscn')
## Icons under this folder are icon slot glyphs; see `_dress_icon`.
const GLYPH_DIR: String = 'res://assets/icons/mechanics/'

var _id: String = ''


func setup(id: String) -> void:
  _id = id
  var name_label: Label = $Margin/Row/Name
  var icon_rect: TextureRect = $Margin/Row/Icon
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  if entry.is_empty():
    name_label.text = id
    icon_rect.visible = false
    tooltip_text = ''   # no card to show → no built-in tooltip
    return
  var icon_path: String = entry['icon']
  icon_rect.texture = load(icon_path) as Texture2D if icon_path != '' else null
  icon_rect.visible = icon_rect.texture != null
  _dress_icon(icon_rect, icon_path, entry['color'])
  name_label.text = tr(entry['name_key'])
  name_label.add_theme_color_override('font_color', entry['color'])
  tooltip_text = id   # non-empty triggers the built-in tooltip; the id IS the card lookup key


## A chip's icon is one of two kinds, and they want opposite treatment. An icon slot's glyph
## (docs/systems/mechanics.md) is a white shape, so it is tinted with the keyword's colour and
## drawn through the element material, which keeps grade, colour ramp and posterize off so the
## pixel stays on its palette colour. Every other icon is painted pack art with its own colours,
## so it keeps white modulate and the picture material.
func _dress_icon(icon_rect: TextureRect, icon_path: String, colour: Color) -> void:
  if icon_path.begins_with(GLYPH_DIR):
    icon_rect.modulate = colour
    icon_rect.material = InterfaceLook.element_material
  else:
    icon_rect.modulate = Color.WHITE
    icon_rect.material = InterfaceLook.material


## Godot calls this when the built-in tooltip is about to show, passing our tooltip_text (the id).
## Return the FRAMELESS keyword card — the engine wraps it in the theme's TooltipPanel and frees it
## on hide (hold no reference). Unknown id → null → no tooltip (never crash).
func _make_custom_tooltip(for_text: String) -> Object:
  if KeywordCatalog.get_entry(for_text).is_empty():
    return null
  var card: KeywordCard = KEYWORD_CARD.instantiate()
  card.setup(for_text)
  return card
