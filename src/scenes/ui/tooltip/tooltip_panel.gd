class_name TooltipPanel
extends PanelContainer
## The main item panel of the tooltip cluster (docs/systems/tooltips.md): the item's name (rarity-
## tinted), its generated effect lines (live values + inline keyword chips), an optional authored
## flavor line, and a stat block (cooldown). Opaque — the framed stylebox is the only surface (no
## alpha). Fed a TooltipContent.build() Dictionary; rebuilds its line rows each time.

const KEYWORD_CHIP: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_chip.tscn')

const PANEL_WIDTH: float = 360.0
const BODY_MARGIN: float = 20.0

# The rarity tint and the changed-value accent are Colours.RARITY_* and Colours.TOOLTIP_CHANGED
# (placeholders, the owner's call). The accent is a single colour plus a direction glyph (the B&W
# theme makes literal green/red clash, so direction reads off the ▲/▼, not the colour).


func set_content(content: Dictionary) -> void:
  custom_minimum_size.x = PANEL_WIDTH
  var title: Label = $Margin/Body/Title
  title.text = content['title']
  title.add_theme_color_override('font_color', _rarity_tint(content['rarity']))
  _build_lines(content['lines'])
  _set_flavor(content['flavor'])
  _set_stats(content['stat_lines'])


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


## One effect line: a flow of text / value / chip / icon segments. HFlowContainer (not HBox) so a long
## line wraps WITHIN the fixed panel width instead of stretching the panel past PANEL_WIDTH.
func _build_line(line: Array) -> HFlowContainer:
  var row := HFlowContainer.new()
  row.add_theme_constant_override('h_separation', 6)
  row.add_theme_constant_override('v_separation', 4)
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE   # empty row space passes through; chips still pick
  for seg: Dictionary in line:
    match seg['t']:
      'text':
        row.add_child(_text_label(seg['s']))
      'value':
        row.add_child(_value_label(seg))
      'chip':
        var chip: KeywordChip = KEYWORD_CHIP.instantiate()
        row.add_child(chip)
        chip.setup(seg['id'])
      'icon':
        row.add_child(_icon_rect(seg['id']))
  return row


func _text_label(text: String) -> Label:
  var label := Label.new()
  label.text = text
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


func _value_label(seg: Dictionary) -> Label:
  var label := Label.new()
  var text: String = seg['s']
  if seg['changed']:
    text += ' ▲' if seg['dir'] > 0 else ' ▼'
    label.add_theme_color_override('font_color', Colours.TOOLTIP_CHANGED)
  label.text = text
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


## A mechanic glyph inline in an effect line (e.g. the attack / heal lines): the slot's icon, tinted
## with the mechanic's colour and drawn through the element material so a pixel stays on its palette
## colour. Sized square to the row's font height, so the glyph matches the text beside it. An unknown
## slot has no texture and no mechanic — the rect is returned empty rather than erroring.
func _icon_rect(slot_id: String) -> TextureRect:
  var rect := TextureRect.new()
  var path: String = IconSlots.icon_for(slot_id)
  if path != '':
    rect.texture = load(path) as Texture2D
  if MechanicRegistry.has(slot_id):
    rect.modulate = MechanicRegistry.get_mechanic(slot_id).color()
  rect.material = InterfaceLook.element_material
  var size: int = get_theme_default_font().get_height(get_theme_default_font_size())
  rect.custom_minimum_size = Vector2(size, size)
  rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
  return rect


func _set_flavor(flavor: String) -> void:
  var label: RichTextLabel = $Margin/Body/Flavor
  label.custom_minimum_size.x = PANEL_WIDTH - BODY_MARGIN * 2.0   # fit_content height at the real width
  label.text = flavor
  label.visible = flavor != ''


func _set_stats(stat_lines: Array) -> void:
  var label: Label = $Margin/Body/StatBlock
  label.text = '\n'.join(stat_lines)
  label.visible = not stat_lines.is_empty()
