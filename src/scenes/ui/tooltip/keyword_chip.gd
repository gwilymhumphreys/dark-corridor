class_name KeywordChip
extends PanelContainer
## An inline keyword chip in the main panel's body (docs/systems/tooltips.md): a small framed tag
## (icon + tinted name) standing in for a status / mechanic the item references. Discrete Control
## (not RichTextLabel markup) so it can carry Godot's built-in per-keyword tooltip — hovering it
## pops the keyword's full card, positioned + clamped by the engine (_make_custom_tooltip).

const KEYWORD_CARD: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_card.tscn')

var _id: String = ''


func setup(id: String) -> void:
  _id = id
  var name_label: Label = $Margin/Name
  var entry: Dictionary = KeywordCatalog.get_entry(id)
  if entry.is_empty():
    name_label.text = id
    tooltip_text = ''   # no card to show → no built-in tooltip
    return
  name_label.text = tr(entry['name_key'])
  name_label.add_theme_color_override('font_color', entry['color'])
  tooltip_text = id   # non-empty triggers the built-in tooltip; the id IS the card lookup key


## Godot calls this when the built-in tooltip is about to show, passing our tooltip_text (the id).
## Return the FRAMELESS keyword card — the engine wraps it in the theme's TooltipPanel and frees it
## on hide (hold no reference). Unknown id → null → no tooltip (never crash).
func _make_custom_tooltip(for_text: String) -> Object:
  if KeywordCatalog.get_entry(for_text).is_empty():
    return null
  var card: KeywordCard = KEYWORD_CARD.instantiate()
  card.setup(for_text)
  return card
