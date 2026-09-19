class_name IconPanel
extends LookPanel
## The icons tab of the debug panel (docs/plans/mechanic_icons.md), opened with F6 by
## `DebugPanels`: choose which icon each icon slot uses. A "Choose" section with two rows: the
## slot, and that slot's candidate icons. Choosing an icon saves it at once and updates what is on
## screen through `DebugPanels.set_slot_icon`. A "Samples" section below shows the chosen icon at
## a few sizes, as a keyword chip and inline with text, so a choice can be judged without leaving
## the panel. This tab is not a look preset part, so its scene has no "Take this part from" row;
## `LookPanel` allows that by treating `_part_row` as optional.

const KEYWORD_CHIP: PackedScene = preload('res://src/scenes/ui/tooltip/keyword_chip.tscn')

var _slot_index: int = 0
var _icon_index: int = 0


func rebuild() -> void:
  _built = true
  _clear_sections()
  var section: LookSection = _add_section('Choose')
  section.set_open(true)   # the only section on this tab, so it is no use closed
  var slot_names: Array = []
  for slot: String in IconSlots.SLOTS:
    slot_names.append(IconSlots.display_name(slot))
  section.add_row(_make_row('Slot', _slot_index, slot_names, _on_slot_changed))
  var slot: String = IconSlots.SLOTS[_slot_index]
  var candidates: Array[String] = IconSlots.candidates(slot)
  _icon_index = candidates.find(IconSlots.icon_for(slot))
  if _icon_index < 0:
    _icon_index = 0
  var icon_names: Array = []
  for path: String in candidates:
    icon_names.append(path.get_file().get_basename())
  section.add_row(_make_row('Icon', _icon_index, icon_names, _on_icon_changed))
  # The chosen icon shown where it appears: a few sizes, as a keyword chip, and inline with text.
  # `charge_time` and `card` have no keyword chip, so the samples skip it for them.
  var samples: LookSection = _add_section('Samples')
  samples.set_open(true)
  samples.add_node(_build_samples(slot))


func _build_samples(slot: String) -> VBoxContainer:
  var box := VBoxContainer.new()
  box.add_theme_constant_override('separation', 8)
  box.add_child(_build_sizes_sample(slot))
  if MechanicRegistry.has(slot):
    box.add_child(_build_chip_row(slot))
  box.add_child(_build_text_sample(slot))
  return box


## The chosen glyph at 16, 24 and 40 pixels side by side, so the small end is readable.
func _build_sizes_sample(slot: String) -> HBoxContainer:
  var row := _build_sample_row('Sizes')
  var box := HBoxContainer.new()
  box.add_theme_constant_override('separation', 16)
  row.add_child(box)
  var texture: Texture2D = _load_texture(IconSlots.icon_for(slot))
  for pixels: int in [16, 24, 40]:   # not `size`, which shadows Control.size
    var rect := TextureRect.new()
    rect.texture = texture
    rect.modulate = _slot_colour(slot)
    rect.material = InterfaceLook.element_material
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.custom_minimum_size = Vector2(pixels, pixels)
    box.add_child(rect)
  return row


## The slot as a keyword chip, shown only for slots that are mechanics — `charge_time` and `card`
## have no keyword, so the chip would show nothing useful. `setup` is deferred to `ready`, so it
## runs once the chip is in the tree (its scene is added to the samples box after that).
func _build_chip_row(slot: String) -> HBoxContainer:
  var row := _build_sample_row('Chip')
  var chip: KeywordChip = KEYWORD_CHIP.instantiate()
  chip.ready.connect(func() -> void: chip.setup(slot))
  row.add_child(chip)
  return row


## An effect line in the shape the tooltip prints: a number, the glyph at the label's font height,
## then a phrase — so the glyph can be judged against text at its real size.
func _build_text_sample(slot: String) -> HBoxContainer:
  var row := _build_sample_row('In text')
  row.add_child(_build_text_label('10'))
  var rect := TextureRect.new()
  rect.texture = _load_texture(IconSlots.icon_for(slot))
  rect.modulate = _slot_colour(slot)
  rect.material = InterfaceLook.element_material
  rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  rect.custom_minimum_size = Vector2(_font_height(), _font_height())
  rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
  row.add_child(rect)
  row.add_child(_build_text_label('to the enemy'))
  return row


# A row of the samples section: a label naming the sample, then its content added by the caller.
func _build_sample_row(label_text: String) -> HBoxContainer:
  var row := HBoxContainer.new()
  row.add_theme_constant_override('separation', 16)
  row.add_child(_build_label_row(label_text))
  return row


func _build_label_row(text: String) -> Label:
  var label := Label.new()
  label.text = text
  label.custom_minimum_size.x = 60.0
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


func _build_text_label(text: String) -> Label:
  var label := Label.new()
  label.text = text
  label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  return label


func _load_texture(path: String) -> Texture2D:
  if path == '':
    return null
  return load(path) as Texture2D


# The default font's height at the panel's font size, matching the size the tooltip's inline glyph
# uses (`TooltipPanel._icon_rect`).
func _font_height() -> int:
  return roundi(get_theme_default_font().get_height(get_theme_default_font_size()))


# The slot's colour: a mechanic's colour, or plain white for a slot that is not a mechanic.
func _slot_colour(slot: String) -> Color:
  if MechanicRegistry.has(slot):
    return MechanicRegistry.get_mechanic(slot).color()
  return Colours.UI_TEXT


func _on_slot_changed(new_index: int) -> void:
  _slot_index = new_index
  rebuild()   # rebuild picks the new slot's candidates and starts the Icon row on the one in use


func _on_icon_changed(new_index: int) -> void:
  var slot: String = IconSlots.SLOTS[_slot_index]
  var candidates: Array[String] = IconSlots.candidates(slot)
  if new_index < 0 or new_index >= candidates.size():
    return
  _icon_index = new_index
  DebugPanels.set_slot_icon(slot, candidates[new_index])
