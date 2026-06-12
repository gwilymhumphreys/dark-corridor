class_name Item
extends RefCounted
## A board participant (docs/systems/item.md) configured by an ItemDef. Owns a cooldown
## Ticker; the Combat manager advances it each step and, on cross, calls fire().
## Every item is active (ticks); declared triggers push the SAME accumulator (the
## def's trigger_subs, wired to the event bus by the manager). Holds its own
## item-targeted statuses + one enchant slot (stubbed in Phase 1).

var def: ItemDef
var owner: Actor               # board membership (self-target; opponent resolution)
var cooldown: Ticker
var statuses: Array = []       # item-targeted StatusEffect instances (silence, +damage, …)
var enchant = null             # one enchant slot (Content PRD; later)


func _init(item_def: ItemDef, item_owner: Actor = null) -> void:
  def = item_def
  owner = item_owner
  cooldown = Ticker.from_seconds(def.cooldown)


## The fire pipeline (docs/systems/item.md): gate -> fire (reset the cooldown) -> resolve
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
    if s.gates_fire():
      return true
  return false


func _resolve_effect(effect: ItemEffect) -> Payload:
  var p := Payload.new()
  p.kind = effect.kind
  p.value = effect.value         # (item-status value-modifiers: later)
  if enchant != null:
    p.value *= enchant.def.value_mult   # scale-a-value enchant (docs/systems/content.md / #26)
  # Outgoing-damage stat-status seam (#6): scale DAMAGE by the owner's modifiers AT FIRE
  # TIME (e.g. Weak). A % multiplier, so it's locked into the payload here, cascade-safe.
  if effect.kind == Delivery.Kind.DAMAGE and owner != null:
    p.value = StatusManager.modify_outgoing(owner, p.value)
  # Status-stack consume (docs/systems/spore_engine.md Cap 1). Carry the declaration on the payload;
  # SELF-fuel resolves now (the owner is known) by spending its stacks + scaling. OPPONENT-
  # fuel (Mass) is left for the Combat manager, which knows the resolved target.
  p.consume_id = effect.consume_id
  p.consume_amount = effect.consume_amount
  p.consume_from_target = effect.consume_from_target
  p.consume_scale = effect.consume_scale
  if effect.consume_id != '' and not effect.consume_from_target and owner != null:
    p.value += StatusManager.consume(owner, effect.consume_id, effect.consume_amount) * effect.consume_scale
  p.summon_def_id = effect.summon_def_id
  p.summon_in_front = effect.summon_in_front
  p.shape = effect.shape
  p.travel = effect.travel
  p.status_id = effect.status_id
  p.duration = effect.duration
  p.flags = effect.flags
  p.color = effect.color
  p.source = self
  return p
