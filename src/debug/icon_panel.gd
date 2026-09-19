class_name IconPanel
extends LookPanel
## The icons tab of the debug panel (docs/plans/mechanic_icons.md), opened with F6 by
## `DebugPanels`: choose which icon each icon slot uses. A "Choose" section with two rows: the
## slot, and that slot's candidate icons. Choosing an icon saves it at once and updates what is on
## screen through `DebugPanels.set_slot_icon`. This tab is not a look preset part, so its scene has
## no "Take this part from" row; `LookPanel` allows that by treating `_part_row` as optional.

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
