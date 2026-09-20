class_name Mechanic
extends RefCounted
## A mechanic is a named combat rule with one class that holds its name, description, icon,
## colour and what it does when a delivery lands (docs/systems/mechanics.md). Item effects name
## the mechanic they use, so items, relics and enchantments can refer to them ("your poison
## items", "when you shield"). One shared instance per id lives in the MechanicRegistry.


var id: String = ''
var name_key: String = ''
var desc_key: String = ''
var icon: String = ''
var status_id: String = ''   # the status this mechanic applies; empty for direct mechanics


## Its Colours variable. A function, so a palette applied at runtime is read each time.
func color() -> Color:
  return Color.WHITE


## The sound folder played when a delivery of this mechanic lands, under
## assets/sound-effects/. A mechanic with no folder of its own falls back to the
## mechanics fallback folder, so a new mechanic is never silent. Takes the delivery so a
## mechanic can vary its sound by what landed; `AttackMechanic` is the one that does.
func sound_key(_delivery: Delivery) -> String:
  return 'mechanics/' + id


## How much of a shield a hit of this mechanic uses (1.0 = normal). Poison, burn and bleed
## return their constants.
func shield_multiplier() -> float:
  return 1.0


## What happens when a delivery of this mechanic lands. The base applies the mechanic's
## `status_id` to the target (the shield mechanic's behaviour) and logs it; `AttackMechanic`
## and `HealMechanic` override it for their direct effects. Only `CombatManager._land` calls it.
func land(delivery: Delivery, combat: CombatManager) -> void:
  if status_id == '':
    return
  var applied: StatusEffect = StatusManager.apply(delivery.target, status_id, delivery.value,
      delivery.duration, delivery.source, delivery.flags)
  if applied != null:   # an unknown id applies nothing — publish no event for it
    combat.bus.publish(EventBus.Event.APPLIED, id, delivery.source_actor,
        combat._source_item_of(delivery))
    if combat.combat_log != null:
      # Shield carries its value; every other status is a count. Use ShieldStatus.ID,
      # not a literal, so the two stay in step (docs/systems/combat_log.md Cap 2 site 5).
      if status_id == ShieldStatus.ID:
        combat.combat_log.on_shield(combat._delivery_source_name(delivery),
            combat._delivery_source_side(delivery), combat._target_name(delivery.target),
            combat._target_side(delivery.target), delivery.value, combat.timekeeper.sim_time)
      else:
        combat.combat_log.on_status_applied(combat._delivery_source_name(delivery),
            combat._delivery_source_side(delivery), combat._target_name(delivery.target),
            combat._target_side(delivery.target), status_id, combat.timekeeper.sim_time)
