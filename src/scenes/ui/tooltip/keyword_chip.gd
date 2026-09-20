class_name KeywordChip
extends PanelContainer
## A small framed tag (icon + tinted name) standing in for a status / mechanic
## (docs/systems/tooltips.md). Used inline in the item tooltip's effect lines, and standalone
## elsewhere in the interface.
##
## A chip can optionally carry Godot's built-in per-keyword tooltip: hovering it pops the keyword's
## full card, positioned + clamped by the engine (_make_custom_tooltip). That is OFF by default and
## off inside the item tooltip, whose keyword column already shows every card at once. Pass
## `hoverable = true` in the places that want the pop-up instead.

const KEYWORD_CARD: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_card.tscn')
## Icons under this folder are icon slot glyphs; see `_dress_icon`.
const GLYPH_DIR: String = 'res://assets/icons/mechanics/'

var _id: String = ''


## `hoverable` turns on the built-in per-keyword tooltip; the chip is inert to the mouse otherwise.
func setup(id: String, hoverable: bool = false) -> void:
  _id = id
  mouse_filter = Control.MOUSE_FILTER_STOP if hoverable else Control.MOUSE_FILTER_IGNORE
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
  tooltip_text = id if hoverable else ''   # non-empty triggers the built-in tooltip; the id is the card key


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
