class_name Item
extends RefCounted
## A board participant (item_prd) configured by an ItemDef. Owns a cooldown
## Ticker; the Combat manager advances it each step and, on cross, calls fire().
## Every item is active (ticks); declared triggers push the SAME accumulator (the
## def's trigger_subs, wired to the event bus by the manager). Holds its own
## item-targeted statuses + one enchant slot (stubbed in Phase 1).

var def: ItemDef
var owner: Actor               # board membership (self-target; opponent resolution)
var cooldown: Ticker
var statuses: Array = []       # item-targeted Status instances (silence, +damage, …)
var enchant = null             # one enchant slot (Content PRD; later)


func _init(item_def: ItemDef, item_owner: Actor = null) -> void:
  def = item_def
  owner = item_owner
  cooldown = Ticker.from_seconds(def.cooldown)


## The fire pipeline (item_prd): gate -> fire (reset the cooldown) -> resolve
## each effect into a Payload (applying modifiers / enchants — none yet) -> hand
## them up. Returns [] if a gate status (silence) suppresses the fire. The
## manager only calls this on a cooldown cross; the fire-emote + event routing
## are the manager's.
func fire() -> Array:
  if _is_gated():
    return []
  cooldown.reset()
  var payloads: Array = []
  for effect in def.effects:
    payloads.append(_resolve_effect(effect))
  return payloads


func _is_gated() -> bool:
  for s in statuses:
    if StatusCatalog.get_def(s.type).gates:
      return true
  return false


func _resolve_effect(effect: ItemEffect) -> Payload:
  var p := Payload.new()
  p.kind = effect.kind
  p.value = effect.value         # item-status value-modifiers + enchant hooks: later
  p.shape = effect.shape
  p.travel = effect.travel
  p.status_type = effect.status_type
  p.flags = effect.flags
  p.color = effect.color
  p.source = self
  return p
