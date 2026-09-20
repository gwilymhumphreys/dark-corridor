class_name TooltipPanel
extends PanelContainer
## The main item panel of the tooltip cluster (docs/systems/tooltips.md), in four parts: the item's
## name (rarity-tinted), its type line (the item's type tags), its charge time beside the charge-time
## glyph, and its generated effect lines (live values + inline keyword icons), plus an optional
## authored flavor line at the bottom. Opaque — the framed stylebox is the only surface (no alpha).
## Fed a TooltipContent.build() Dictionary; rebuilds its line rows each time.

const PANEL_WIDTH: float = 360.0
const BODY_MARGIN: float = 20.0

## Inline icon size, as a multiple of the row's font height. One, so an icon is exactly as tall as
## the line it sits in: the body text size is chosen to match the icons (docs/systems/ui_theme.md),
## and both move together when the player changes the text size.
const ICON_SCALE: float = 1.0

# The rarity tint and the changed-value accent are Colours.RARITY_* and Colours.TOOLTIP_CHANGED
# (placeholders, the owner's call). The accent is the colour alone: the direction glyph it used to
# carry was dropped once the mechanic's icon sat beside the number.


func set_content(content: Dictionary) -> void:
  custom_minimum_size.x = PANEL_WIDTH
  var title: Label = $Margin/Body/Title
  title.text = content['title']
  title.add_theme_color_override('font_color', _rarity_tint(content['rarity']))
  _set_type_line(content['type_line'])
  _set_charge(content['charge_line'])
  _build_lines(content['lines'])
  _set_flavor(content['flavor'])


func _rarity_tint(rarity: int) -> Color:
  match rarity:
    ItemDef.Rarity.UNCOMMON:
      return Colours.RARITY_UNCOMMON
    ItemDef.Rarity.RARE:
      return Colours.RARITY_RARE
  return Colours.RARITY_COMMON


func _build_lines(lines: Array) -> void:
  var box: VBoxContainer = $Margin/Body/Lines
  for child in box.get_children():
    box.remove_child(child)
    child.queue_free()
  for line: Array in lines:
    box.add_child(_build_line(line))


## One line: a flow of text / value / icon segments. HFlowContainer (not HBox) so a long line wraps
## WITHIN the fixed panel width instead of stretching the panel past PANEL_WIDTH.
func _build_line(line: Array) -> HFlowContainer:
  var row := HFlowContainer.new()
  row.add_theme_constant_override('h_separation', 6)
  row.add_theme_constant_override('v_separation', 4)
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  for seg: Dictionary in line:
    match seg['t']:
      'text':
        row.add_child(_text_label(seg['s']))
      'value':
        row.add_child(_value_label(seg))
      'icon':
        row.add_child(KeywordIcon.make(seg['id'], _icon_size()))
  return row


## The pixel size of an inline icon: the body font's height, read from the theme, so icons follow
## the player's text size setting.
func _icon_size() -> int:
  var font: Font = get_theme_default_font()
  return roundi(font.get_height(get_theme_default_font_size()) * ICON_SCALE)


func _text_label(text: String) -> Label:
  var label := Label.new()
  label.text = text
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


func _value_label(seg: Dictionary) -> Label:
  var label := Label.new()
  if seg['changed']:
    label.add_theme_color_override('font_color', Colours.TOOLTIP_CHANGED)
  label.text = seg['s']
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


func _set_flavor(flavor: String) -> void:
  var label: RichTextLabel = $Margin/Body/Flavor
  label.custom_minimum_size.x = PANEL_WIDTH - BODY_MARGIN * 2.0   # fit_content height at the real width
  label.text = flavor
  label.visible = flavor != ''


## The type line: the item's type tags as a plain label under the title. Hidden when the string is
## empty, so an untagged item shows no gap between the title and the effect lines.
func _set_type_line(type_line: String) -> void:
  var label: Label = $Margin/Body/TypeLine
  label.text = type_line
  label.visible = type_line != ''


## The charge-time row: the item's cooldown beside the charge-time glyph, under the type line.
func _set_charge(charge_line: Array) -> void:
  var holder: Control = $Margin/Body/Charge
  for child in holder.get_children():
    holder.remove_child(child)
    child.queue_free()
  holder.add_child(_build_line(charge_line))
