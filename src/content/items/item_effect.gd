class_name ItemEffect
extends RefCounted
## One authored effect of an item (docs/systems/item.md). An item fires one payload per
## effect. Carries a relative target-SHAPE (not a resolved target — the Combat
## manager resolves it) + the payload kind/value + travel + presentation.

enum Shape { SELF, OPPONENT_LEFTMOST, ALL_OPPONENTS, OPPONENT_ITEM_RANDOM, ALL_OPPONENT_ITEMS }

var kind: int = Delivery.Kind.DAMAGE
var value: float = 0.0
var shape: int = Shape.OPPONENT_LEFTMOST
var travel: float = 0.0          # seconds (0 = instant; docs/systems/combat_model.md's zero case)
var status_id: String = ''       # for kind == APPLY_STATUS (string id, #23)
var duration: float = 0.0        # for kind == APPLY_STATUS — per-application duration (timed statuses)
var flags: int = 0               # Delivery.Flag bits (e.g. unblockable)
var color: Color = Color.WHITE

# Status-stack consumption (docs/systems/spore_engine.md Cap 1) — spend a stacked status as fuel,
# scaling this effect's value by `consume_scale` per stack removed. `consume_from_target`
# false = self-fuel (the owner's stacks, resolved at fire — Item._resolve_effect); true =
# opponent-fuel (the resolved target's stacks — Mass, resolved by the Combat manager at
# Delivery spawn). Numbers are content (ItemDef).
var consume_id: String = ''      # status id to spend ('' = none)
var consume_amount: float = 0.0  # up to this many stacks
var consume_from_target: bool = false
var consume_scale: float = 0.0   # value added to the payload per stack consumed

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
