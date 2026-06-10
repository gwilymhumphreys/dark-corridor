class_name VulnerableStatus
extends TimedStatus
## Vulnerable — the incoming-damage amplifier (#6): while it sits on a holder, damage TO it is
## scaled up in the amplifier stage, before block soaks the amplified amount. Timed; duration
## rides the application.

const ID := 'vulnerable'


func _init() -> void:
  id = ID
  name_key = 'Vulnerable'
  color = Colours.STATUS_VULNERABLE


func modify_incoming(amount: float, target, ctx) -> float:
  return amount * Balance.STATUS_VULNERABLE_DAMAGE_MULT
