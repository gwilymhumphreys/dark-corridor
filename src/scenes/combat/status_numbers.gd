class_name StatusNumbers
extends HBoxContainer
## The health-bar status numbers (docs/systems/mechanics.md → Health bar): one entry per mechanic
## status (poison, burn, bleed, regen), each the mechanic's icon and its stack count in the
## mechanic's colour. Shield is shown by HealthBar instead. An entry pops in when its status appears
## and bumps when its stacks rise (PopAnimation). Reads the actor's statuses each frame; writes
## nothing.


var actor: Actor = null
var _counts: Dictionary = {}   # mechanic id -> the stacks shown last frame, 0 when hidden

@onready var _poison: HBoxContainer = $Poison
@onready var _burn: HBoxContainer = $Burn
@onready var _bleed: HBoxContainer = $Bleed
@onready var _regen: HBoxContainer = $Regen


func _ready() -> void:
  _set_icon(_poison, PoisonMechanic.ID)
  _set_icon(_burn, BurnMechanic.ID)
  _set_icon(_bleed, BleedMechanic.ID)
  _set_icon(_regen, RegenMechanic.ID)


func _process(_delta: float) -> void:
  if actor == null:
    _hide_all()
    return
  _refresh(_poison, PoisonMechanic.ID)
  _refresh(_burn, BurnMechanic.ID)
  _refresh(_bleed, BleedMechanic.ID)
  _refresh(_regen, RegenMechanic.ID)


func _set_icon(entry: HBoxContainer, id: String) -> void:
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(id)
  var icon: TextureRect = entry.get_node('Icon')
  icon.texture = load(mechanic.icon) as Texture2D
  KeywordIcon.dress(icon, mechanic.icon, mechanic.color())


## The entry for the mechanic status `id`, or null for any other id.
func entry_for(id: String) -> HBoxContainer:
  match id:
    PoisonMechanic.ID:
      return _poison
    BurnMechanic.ID:
      return _burn
    BleedMechanic.ID:
      return _bleed
    RegenMechanic.ID:
      return _regen
  return null


func _refresh(shown: HBoxContainer, id: String) -> void:
  var status: StatusEffect = _find_status(id)
  var before: int = int(_counts.get(id, 0))
  if status != null and status.count > 0:
    var value: Label = shown.get_node('Value')
    value.text = str(status.count)
    value.modulate = MechanicRegistry.get_mechanic(id).color()
    shown.show()
    if before == 0:
      PopAnimation.pop_in(shown)
    elif status.count > before:
      PopAnimation.bump(shown)
    _counts[id] = status.count
  else:
    shown.hide()
    _counts[id] = 0


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
  _counts.clear()
  actor = null
