class_name WeakStatus
extends TimedStatus
## Weak — the outgoing-damage debuff (#6): while it sits on an actor, that actor's outgoing DAMAGE
## payloads are scaled down at fire time. A timed status whose duration now rides the application
## (e.g. Wilt Frond applies a 2s Weak; another applier could apply a longer one). The whole file is
## this small because TimedStatus carries the timer + stacking — a status overrides only what it does.

const ID := 'weak'


func _init() -> void:
  id = ID
  name_key = 'Weak'                          # plain assignment → localized by extract_pot
  desc_key = 'Deals less damage while it lasts.'   # PLACEHOLDER desc — owner writes
  color = Colours.STATUS_WEAK


func modify_outgoing(amount: float, target, ctx) -> float:
  return amount * Balance.STATUS_WEAK_DAMAGE_MULT
