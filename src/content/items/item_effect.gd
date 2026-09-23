class_name ItemEffect
extends RefCounted
## One authored effect of an item (docs/systems/item.md). An item fires one payload per
## effect. Carries a relative target-SHAPE (not a resolved target — the Combat
## manager resolves it) plus an optional target-FILTER that narrows the shape's pool,
## + the payload kind/value + presentation. Travel is not authored: every delivery flies
## Balance.TRAVEL_STEPS.

enum Shape { SELF, OPPONENT_LEFTMOST, ALL_OPPONENTS, OPPONENT_ITEM_RANDOM, ALL_OPPONENT_ITEMS,
    OWN_ITEM_RANDOM, ALL_OWN_ITEMS }

var kind: int = Delivery.Kind.MECHANIC
var value: float = 0.0
var shape: int = Shape.OPPONENT_LEFTMOST
# Optional narrowing of the target pool (docs/systems/item.md) — applied by the Combat manager after
# the shape picks the pool and before it picks the targets. Null = no filtering. Item pools only;
# actor shapes ignore it.
var target_filter: TargetFilter = null
var mechanic: String = ''        # for kind == MECHANIC (MechanicRegistry id; docs/systems/mechanics.md)
var status_id: String = ''       # for kind == APPLY_STATUS (string id, #23)
var duration: float = 0.0        # for kind == APPLY_STATUS — per-application duration (timed statuses)
var flags: int = 0               # Delivery.Flag bits (e.g. unblockable)
# The colour the effect's delivery is drawn in, worked out on each read so a palette change shows at
# once: the `Colours` variable named by `colour_name` when set, else the mechanic's colour, else the
# applied status's colour, else white.
var colour_name: String = ''
var color: Color:
  get = _get_color

# Status-stack consumption (docs/systems/spore_engine.md Cap 1) — spend a stacked status as fuel,
# scaling this effect's value by `consume_scale` per stack removed. `consume_from_target`
# false = self-fuel (the owner's stacks, resolved at fire — Item._resolve_effect); true =
# opponent-fuel (the resolved target's stacks — Mass, resolved by the Combat manager at
# Delivery spawn). Numbers are content (ItemDef).
var consume_id: String = ''      # status id to spend ('' = none)
var consume_amount: float = 0.0  # up to this many stacks
var consume_from_target: bool = false
var consume_scale: float = 0.0   # value added to the payload per stack consumed

# Scale by a status the owner holds WITHOUT spending it (docs/systems/item.md): at fire time the value
# gains `per_owner_stack_scale` for each stack of `per_owner_stack_id` on the owner. Shield Bash uses
# it to hit for the Smith's shield. Unlike consume, the stacks stay, and any status counts.
var per_owner_stack_id: String = ''      # status id to read ('' = none)
var per_owner_stack_scale: float = 0.0   # value added per stack held

# Summon (docs/systems/spore_engine.md Cap 3): a kind == SUMMON effect spawns a token Actor from an
# EnemyCatalog def onto the summoner's OWN side (shape SELF). `summon_in_front` puts it
# leftmost (body-block / adds-in-front). The token def + the trigger are content.
var summon_def_id: String = ''
var summon_in_front: bool = true

# Mid-fight item creation (docs/systems/item_creation_and_decay.md Cap 1): a kind == CREATE_ITEM
# effect puts a new Item (an ItemCatalog def) on the firing actor's OWN board (shape SELF) — the
# cousin of SUMMON's roster-add. WHICH item, and its decay/numbers, are content (the created def).
var create_item_def_id: String = ''

# Own-board item-consume (docs/systems/item_creation_and_decay.md — the Mass-twin on board items):
# spend a pile of the OWNER's matching board items as fuel, scaling this effect's value by
# `consume_item_scale` per item removed. Resolved in CombatManager._fire_item (item-removal lives on
# the manager), removing each via remove_item so the consumed items publish ITEM_DESTROYED — a
# charge-on-destroy item charges off active consume for free. `consume_item_amount` <= 0 = consume
# ALL present; > 0 = up to that many. WHICH item, how many, and the scaling are content (ItemDef).
var consume_item_def_id: String = ''   # board item def id to eat ('' = none)
var consume_item_amount: int = 0       # up to this many (<= 0 = all present)
var consume_item_scale: float = 0.0    # value added to the payload per item consumed


## An attack for `value` damage.
static func attack(value: float, shape: int = Shape.OPPONENT_LEFTMOST) -> ItemEffect:
  return make(AttackMechanic.ID, value, shape)


## Shield of `value` on the holder.
static func shield(value: float) -> ItemEffect:
  return make(ShieldMechanic.ID, value, Shape.SELF)


## Healing of `value` on the holder.
static func heal(value: float) -> ItemEffect:
  return make(HealMechanic.ID, value, Shape.SELF)


## Any mechanic (`MechanicRegistry` id) for `value` on `shape`.
static func make(mechanic_id: String, value: float, shape: int) -> ItemEffect:
  var effect := ItemEffect.new()
  effect.mechanic = mechanic_id
  effect.value = value
  effect.shape = shape
  return effect


## Apply `value` of the status `status_id` on `shape`; `duration` is for a timed status.
static func apply_status(status_id: String, value: float, shape: int,
    duration: float = 0.0) -> ItemEffect:
  var effect := ItemEffect.new()
  effect.kind = Delivery.Kind.APPLY_STATUS
  effect.status_id = status_id
  effect.value = value
  effect.shape = shape
  effect.duration = duration
  return effect


func _get_color() -> Color:
  if colour_name != '':
    return Colours.named(colour_name)
  if mechanic != '':
    return MechanicRegistry.get_mechanic(mechanic).color()
  if kind == Delivery.Kind.APPLY_STATUS and StatusRegistry.has(status_id):
    return StatusRegistry.create(status_id).color
  return Color.WHITE
