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
var statuses: Array[StatusEffect] = []   # item-targeted instances (silence, +damage, …)
var enchant: Enchantment = null          # one enchant slot


func _init(item_def: ItemDef, item_owner: Actor = null) -> void:
  def = item_def
  owner = item_owner
  cooldown = Ticker.from_seconds(def.cooldown)


## The fire pipeline (docs/systems/item.md): gate -> fire (reset the cooldown) -> resolve
## each effect into a Payload (applying modifiers / enchants — none yet) -> hand
## them up. Returns [] if a gate status (silence) suppresses the fire — a backstop:
## the Combat manager already freezes a gated item's cooldown (decision #30), so a
## gated item normally never crosses. The manager only calls this on a cooldown
## cross; the fire-emote + event routing are the manager's.
func fire() -> Array:
  if is_gated():
    return []
  cooldown.reset()
  var payloads: Array[Payload] = []
  for effect in def.effects:
    payloads.append(_resolve_effect(effect))
  return payloads


## True while a gate status (silence) sits on this item. The Combat manager consults
## this each step to FREEZE the cooldown (decision #30: a gate holds time — no accrual,
## so the gate lifting never releases a banked burst of fires).
func is_gated() -> bool:
  for s in statuses:
    if s.gates_fire():
      return true
  return false


## Read-only display value for the tooltip (docs/systems/tooltips.md) — the value the tooltip
## SHOWS, computed WITHOUT side effects. Mirrors the pure stages of _resolve_effect (enchant
## scaling + the outgoing stat-status seam) but never resets the cooldown or spends fuel, so it
## is safe to call every frame while inspecting. Consume-scaling is excluded (it needs a non-
## mutating stack peek; tooltips.md). Pairs with base_value for the changed-value highlight.
func display_value(effect: ItemEffect) -> float:
  var v: float = base_value(effect)
  if effect.kind == Delivery.Kind.DAMAGE and owner != null:
    v = StatusManager.modify_outgoing(owner, v)   # pure (Weak etc.)
  return v


## The baseline the changed-value highlight compares against: the authored value scaled by the
## enchant only (a PERMANENT modifier — #26), so the highlight reflects combat-scoped status
## changes (Weak), not the enchant. Read-only.
func base_value(effect: ItemEffect) -> float:
  var v: float = effect.value
  if enchant != null:
    v *= enchant.def.value_mult   # pure (permanent item modifier)
  return v


## The item-side stages on top of the shared template copy (Payload.from_effect):
## enchant scaling, the outgoing stat-status seam, self-fuel consume, source identity.
func _resolve_effect(effect: ItemEffect) -> Payload:
  var p := Payload.from_effect(effect)
  if enchant != null:
    p.value *= enchant.def.value_mult   # scale-a-value enchant (docs/systems/content.md / #26)
  # Outgoing-damage stat-status seam (#6): scale DAMAGE by the owner's modifiers AT FIRE
  # TIME (e.g. Weak). A % multiplier, so it's locked into the payload here, cascade-safe.
  if effect.kind == Delivery.Kind.DAMAGE and owner != null:
    p.value = StatusManager.modify_outgoing(owner, p.value)
  # Status-stack consume (docs/systems/spore_engine.md Cap 1): SELF-fuel resolves now (the
  # owner is known) by spending its stacks + scaling. OPPONENT-fuel (Mass) rides the
  # payload's consume declaration to the Combat manager, which knows the resolved target.
  if effect.consume_id != '' and not effect.consume_from_target and owner != null:
    p.value += StatusManager.consume(owner, effect.consume_id, effect.consume_amount) * effect.consume_scale
  p.source = self
  p.source_actor = owner
  return p
