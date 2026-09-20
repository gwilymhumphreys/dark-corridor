class_name KeywordChip
extends PanelContainer
## A small framed tag (icon + tinted name) standing in for a status / mechanic
## (docs/systems/tooltips.md). Used standalone elsewhere in the interface; the item tooltip's own
## effect lines draw a bare icon instead. Its icon is dressed by `KeywordIcon.dress`.
##
## A chip can optionally carry Godot's built-in per-keyword tooltip: hovering it pops the keyword's
## full card, positioned + clamped by the engine (_make_custom_tooltip). That is OFF by default;
## pass `hoverable = true` in the places that want the pop-up.

const KEYWORD_CARD: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_card.tscn')

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
  KeywordIcon.dress(icon_rect, icon_path, entry['color'])
  name_label.text = tr(entry['name_key'])
  name_label.add_theme_color_override('font_color', entry['color'])
  tooltip_text = id if hoverable else ''   # non-empty triggers the built-in tooltip; the id is the card key


## Godot calls this when the built-in tooltip is about to show, passing our tooltip_text (the id).
## Return the FRAMELESS keyword card — the engine wraps it in the theme's TooltipPanel and frees it
## on hide (hold no reference). Unknown id → null → no tooltip (never crash).
func _make_custom_tooltip(for_text: String) -> Object:
  if KeywordCatalog.get_entry(for_text).is_empty():
    return null
  var card: KeywordCard = KEYWORD_CARD.instantiate()
  card.setup(for_text)
  return card
