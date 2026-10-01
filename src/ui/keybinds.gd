class_name Keybinds
extends RefCounted
## The actions the player can rebind, and how their stored keys reach Godot's input map
## (docs/systems/keybindings.md). Default keys live in project.godot; `Prefs` stores only the
## actions the player changed, so a new action or a changed default reaches everyone else.
##
## Each action has two slots, a main key (0) and a spare key (1); either can be empty. A stored slot
## is a small dictionary — `{'kind': 'key', 'physical_keycode': 91}`, or `{}` when empty — rather
## than an InputEvent, so the prefs file stays readable. Keys are bound by position
## (`physical_keycode`), and shown by the character printed on the player's keyboard.

## Every action the Controls tab shows, in its order. A group is a set of actions active at the same
## time; two actions in one group cannot share a key. Shown names are in `KeybindRow`, since the
## text extractor only finds literals inside `tr()`.
const ACTIONS: Array[Dictionary] = [
  {'action': 'battle_speed_down', 'group': 'run'},
  {'action': 'battle_speed_up', 'group': 'run'},
  {'action': 'toggle_pause', 'group': 'run'},
]

const SLOT_COUNT: int = 2
const KIND_KEY: String = 'key'


## Whether `action` is one the player can rebind.
static func is_listed(action: String) -> bool:
  return not _entry(action).is_empty()


## The action's two slots: the player's change if there is one, otherwise the project default.
## Read slots from here, not from InputMap, which does not keep track of which slot an event is in.
static func slots(action: String) -> Array[Dictionary]:
  var stored: Variant = Prefs.keybind_slots(action)
  if stored is Array:
    return _cleaned(stored)
  return default_slots(action)


## The action's slots as project.godot sets them.
static func default_slots(action: String) -> Array[Dictionary]:
  var result: Array[Dictionary] = []
  var setting: Variant = ProjectSettings.get_setting('input/' + action)
  if setting is Dictionary:
    for event in setting.get('events', []):
      var key: InputEventKey = event as InputEventKey
      if key != null and key.physical_keycode != KEY_NONE:
        result.append(key_slot(key.physical_keycode))
  return _cleaned(result)


## A stored slot holding the key at `physical_keycode`.
static func key_slot(physical_keycode: int) -> Dictionary:
  return {'kind': KIND_KEY, 'physical_keycode': physical_keycode}


## Put the action's slots into InputMap, one key event per filled slot.
static func apply(action: String) -> void:
  if not InputMap.has_action(action):
    InputMap.add_action(action)
  InputMap.action_erase_events(action)
  for slot in slots(action):
    var event: InputEventKey = _event_of(slot)
    if event != null:
      InputMap.action_add_event(action, event)


## Apply every listed action. Prefs calls this at start-up, after loading.
static func apply_all() -> void:
  for entry in ACTIONS:
    apply(entry['action'])


## Put the key in the action's slot. Another action in the same group holding that key loses it.
## Returns the action that lost the key, or '' if none. A reserved key is refused with no change.
static func bind(action: String, slot: int, physical_keycode: int) -> String:
  if not is_listed(action) or slot < 0 or slot >= SLOT_COUNT or is_reserved(physical_keycode):
    return ''
  var taken_from: String = ''
  var group: String = _entry(action)['group']
  for entry in ACTIONS:
    var other: String = entry['action']
    if entry['group'] != group:
      continue
    var other_slots: Array[Dictionary] = slots(other)
    for i in SLOT_COUNT:
      if other == action and i == slot:
        continue
      if _keycode_of(other_slots[i]) == physical_keycode:
        other_slots[i] = {}
        _store(other, other_slots)
        if other != action:
          taken_from = other
  var own: Array[Dictionary] = slots(action)
  own[slot] = key_slot(physical_keycode)
  _store(action, own)
  return taken_from


## Empty the action's slot.
static func clear(action: String, slot: int) -> void:
  if not is_listed(action) or slot < 0 or slot >= SLOT_COUNT:
    return
  var own: Array[Dictionary] = slots(action)
  own[slot] = {}
  _store(action, own)


## Drop every change the player made and apply the project defaults.
static func reset_all() -> void:
  Prefs.clear_keybinds()
  apply_all()


## Keys the game keeps for itself: Escape goes back in menus and pauses a run, and the F keys open
## the debug panels in dev builds.
static func is_reserved(physical_keycode: int) -> bool:
  return physical_keycode == KEY_ESCAPE or (physical_keycode >= KEY_F1 and physical_keycode <= KEY_F12)


## The key in the slot as printed on the player's keyboard, or '' when the slot is empty.
static func slot_label(slot: Dictionary) -> String:
  var physical: int = _keycode_of(slot)
  if physical == KEY_NONE:
    return ''
  var label: int = DisplayServer.keyboard_get_label_from_physical(physical as Key)
  if label == KEY_NONE:
    label = physical   # no keyboard layout to ask (headless)
  # A printable key's code is its character, so `[` shows as `[` rather than "BracketLeft".
  if label > KEY_SPACE and label < KEY_SPECIAL:
    return String.chr(label).to_upper()
  return OS.get_keycode_string(label as Key)


## The action's main key as printed on the player's keyboard, or '' — for hints such as tooltips.
static func key_label(action: String) -> String:
  return slot_label(slots(action)[0])


static func _entry(action: String) -> Dictionary:
  for entry in ACTIONS:
    if entry['action'] == action:
      return entry
  return {}


static func _store(action: String, new_slots: Array[Dictionary]) -> void:
  Prefs.set_keybind_slots(action, new_slots)
  apply(action)


# Exactly SLOT_COUNT slots, each a well-formed key slot or {}. A key repeated in a later slot is
# dropped, and anything badly formed (an old or hand-edited file) becomes an empty slot.
static func _cleaned(raw: Array) -> Array[Dictionary]:
  var result: Array[Dictionary] = []
  var seen: Array[int] = []
  for i in SLOT_COUNT:
    var slot: Variant = raw[i] if i < raw.size() else {}
    var physical: int = _keycode_of(slot) if slot is Dictionary else KEY_NONE
    if physical == KEY_NONE or seen.has(physical):
      result.append({})
    else:
      seen.append(physical)
      result.append(key_slot(physical))
  return result


static func _keycode_of(slot: Dictionary) -> int:
  if slot.get('kind', '') != KIND_KEY:
    return KEY_NONE
  var physical: Variant = slot.get('physical_keycode', KEY_NONE)
  return int(physical) if (physical is int or physical is float) else KEY_NONE


static func _event_of(slot: Dictionary) -> InputEventKey:
  var physical: int = _keycode_of(slot)
  if physical == KEY_NONE:
    return null
  var event: InputEventKey = InputEventKey.new()
  event.physical_keycode = physical as Key
  return event
