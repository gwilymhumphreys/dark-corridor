class_name StatusNumbers
extends HBoxContainer
## The health-bar status numbers (docs/systems/mechanics.md → Health bar): one entry per mechanic
## status (poison, burn, bleed, regen), each the mechanic's icon and its stack count in the
## mechanic's colour. Shield is shown by HealthBar instead. A count that changes moves to its new
## value over EasedValue.DEFAULT_DURATION instead of jumping. Reads the actor's statuses each frame;
## writes nothing.


var actor: Actor = null:
  set(value):
    actor = value
    _shown.clear()   # a new actor is not a change: its counts show at once

var _shown: Dictionary[String, EasedValue] = {}   # mechanic id -> the count on screen

@onready var _poison: HBoxContainer = $Poison
@onready var _burn: HBoxContainer = $Burn
@onready var _bleed: HBoxContainer = $Bleed
@onready var _regen: HBoxContainer = $Regen


func _ready() -> void:
  _set_icon(_poison, PoisonMechanic.ID)
  _set_icon(_burn, BurnMechanic.ID)
  _set_icon(_bleed, BleedMechanic.ID)
  _set_icon(_regen, RegenMechanic.ID)


func _process(delta: float) -> void:
  if actor == null:
    _hide_all()
    return
  _refresh(_poison, PoisonMechanic.ID, delta)
  _refresh(_burn, BurnMechanic.ID, delta)
  _refresh(_bleed, BleedMechanic.ID, delta)
  _refresh(_regen, RegenMechanic.ID, delta)


func _set_icon(entry: HBoxContainer, id: String) -> void:
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(id)
  var icon: TextureRect = entry.get_node('Icon')
  icon.texture = load(mechanic.icon) as Texture2D
  KeywordIcon.dress(icon, mechanic.icon, mechanic.color())


# The entry stays up while its number counts down to zero, and hides once it shows zero.
func _refresh(entry: HBoxContainer, id: String, delta: float) -> void:
  var status: StatusEffect = _find_status(id)
  var count: int = status.count if status != null else 0
  if not _shown.has(id):
    _shown[id] = EasedValue.new()
    _shown[id].snap(float(count))
  var shown: int = roundi(_shown[id].step(float(count), delta))
  if shown > 0:
    var value: Label = entry.get_node('Value')
    value.text = str(shown)
    value.modulate = MechanicRegistry.get_mechanic(id).color()
    entry.show()
  else:
    entry.hide()


func _hide_all() -> void:
  _poison.hide()
  _burn.hide()
  _bleed.hide()
  _regen.hide()


func _find_status(id: String) -> StatusEffect:
  for s in actor.statuses:
    if s.id == id:
      return s
  return null


func _exit_tree() -> void:
  actor = null
