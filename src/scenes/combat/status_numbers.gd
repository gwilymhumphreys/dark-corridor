class_name StatusNumbers
extends HBoxContainer
## The health-bar status numbers (docs/plans/mechanics.md → Health bar numbers): one label per
## mechanic status (shield, poison, burn, bleed, regen) showing its stack count in the mechanic's
## colour, beside the health bar. Reads the actor's statuses each frame; writes nothing.


var actor: Actor = null

@onready var _shield: Label = $Shield
@onready var _poison: Label = $Poison
@onready var _burn: Label = $Burn
@onready var _bleed: Label = $Bleed
@onready var _regen: Label = $Regen


func _process(_delta: float) -> void:
  if actor == null:
    _hide_all()
    return
  _refresh(_shield, ShieldMechanic.ID)
  _refresh(_poison, PoisonMechanic.ID)
  _refresh(_burn, BurnMechanic.ID)
  _refresh(_bleed, BleedMechanic.ID)
  _refresh(_regen, RegenMechanic.ID)


func _refresh(label: Label, id: String) -> void:
  var status: StatusEffect = _find_status(id)
  if status != null and status.count > 0.0:
    label.text = str(int(status.count))
    label.modulate = MechanicRegistry.get_mechanic(id).color()
    label.show()
  else:
    label.hide()


func _hide_all() -> void:
  _shield.hide()
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
