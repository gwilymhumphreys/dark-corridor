class_name FixtureItems
## Plain item definitions for tests to spawn, so combat, UI and event tests do not depend on
## authored content. A test that needs "an attacker", "a shielder" or "a poison applier" builds
## one here instead of reaching into ItemCatalog, which means tuning or renaming a real card
## cannot break it. Each builder returns a fresh ItemDef.
##
## The numbers below are the ones the deleted prototype items carried (Rusted Blade, Iron Guard,
## Venom Fang), so the fights these produce behave exactly as they did before. They are fixture
## constants on purpose: they must NOT be pulled from Balance, or a tuning pass would move them.
##
## Use a real catalog item instead when a test is about the catalog itself (its caching, its icons)
## or about a specific card's behaviour.

const ATTACK_COOLDOWN: float = 1.2
const ATTACK_DAMAGE: float = 6.0

const SHIELD_COOLDOWN: float = 2.0
const SHIELD_VALUE: float = 8.0

const POISON_COOLDOWN: float = 1.6
const POISON_STACKS: float = 3.0

# The two filtered fixtures below. Fixture constants like the ones above: they are not pulled from
# Balance, because a tuning pass must not be able to move what a test asserts.
const CHARGE_COOLDOWN: float = 3.0
const CHARGE_SECONDS: float = 1.0
const SILENCE_COOLDOWN: float = 4.0
const SILENCE_DURATION: float = 2.0

# The trigger, debuff and buff fixtures below. Fixture constants for the same reason.
const TRIGGER_COOLDOWN: float = 2.0
const TRIGGER_SHIELD: float = 8.0
const TRIGGER_SECONDS: float = TRIGGER_COOLDOWN   # fills the whole bar
const VULNERABLE_COOLDOWN: float = 3.0
const VULNERABLE_DURATION: float = 3.0
const HEX_COOLDOWN: float = 2.5
const EMPOWER_COOLDOWN: float = 7.0
const EMPOWER_STACKS: float = 1.0


## A single-target attack that travels — the generic attacker.
static func attack() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_attack'
  d.types = [ItemType.WEAPON]
  d.mechanics = [AttackMechanic.ID]
  d.name_key = 'Fixture Blade'
  d.icon = 'res://assets/icons/items/old_sword.png'
  d.cooldown = ATTACK_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = ATTACK_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  d.effects = [hit]
  d.panel_colour_name = 'ATTACK'
  return d


## The same attack under a different name, for the other side of a fight. Tests that read a
## per-item report need the two sides' items to be tellable apart by name.
static func enemy_attack() -> ItemDef:
  var d := attack()
  d.id = 'fixture_enemy_attack'
  d.name_key = 'Fixture Claw'
  d.icon = 'res://assets/icons/items/loot_183_claw.png'
  return d


## A self-shield item — the generic defensive item.
static func shield() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_shield'
  d.types = [ItemType.ARMOUR]
  d.mechanics = [ShieldMechanic.ID]
  d.name_key = 'Fixture Guard'
  d.icon = 'res://assets/icons/items/metal_shield_1.png'
  d.cooldown = SHIELD_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = SHIELD_VALUE
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_colour_name = 'SHIELD'
  return d


## A pure applier: stacks poison on the leftmost opponent and deals no direct damage.
static func poison() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_poison'
  d.types = [ItemType.WEAPON]
  d.mechanics = [PoisonMechanic.ID]
  d.name_key = 'Fixture Fang'
  d.icon = 'res://assets/icons/items/loot_26_spiderteeth.png'
  d.cooldown = POISON_COOLDOWN
  var pois := ItemEffect.new()
  pois.mechanic = PoisonMechanic.ID
  pois.value = POISON_STACKS
  pois.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  d.effects = [pois]
  d.panel_colour_name = 'POISON'
  return d


## A charge item narrowed to your WEAPON items — the worked example of a type-tag target filter
## ("all your weapons"). It charges every weapon on its owner's board and leaves the rest alone.
## A fixture, not a catalog card: real items are the owner's to author.
static func charge_your_weapons() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_charge_your_weapons'
  d.types = [ItemType.SKILL]
  d.mechanics = [ChargeMechanic.ID]
  d.name_key = 'Fixture Whetstone'
  d.cooldown = CHARGE_COOLDOWN
  var f := TargetFilter.new()
  f.add_type(ItemType.WEAPON)
  var push := ItemEffect.new()
  push.mechanic = ChargeMechanic.ID
  push.value = CHARGE_SECONDS
  push.shape = ItemEffect.Shape.ALL_OWN_ITEMS
  push.target_filter = f
  d.effects = [push]
  d.panel_colour_name = 'ARCANE'
  return d


## A silence aimed at one enemy POISON item — the worked example of a mechanic target filter
## ("a random enemy poison item"). It picks at random from the enemy items that poison, so it does
## nothing against a board with none. A fixture, not a catalog card.
static func silence_enemy_poison_item() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_silence_enemy_poison_item'
  d.types = [ItemType.SPELL]
  d.mechanics = []
  d.name_key = 'Fixture Muzzle'
  d.cooldown = SILENCE_COOLDOWN
  var f := TargetFilter.new()
  f.add_mechanic(PoisonMechanic.ID)
  var hush := ItemEffect.new()
  hush.kind = Delivery.Kind.APPLY_STATUS
  hush.status_id = 'silence'
  hush.duration = SILENCE_DURATION
  hush.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  hush.target_filter = f
  d.effects = [hush]
  d.panel_colour_name = 'ARCANE'
  return d


## A self-shield that also pushes its own cooldown whenever its side applies poison — the generic
## trigger item. It subscribes to APPLIED with the poison filter and the default own-side source.
static func poison_trigger() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_poison_trigger'
  d.types = [ItemType.ARMOUR]
  d.mechanics = [PoisonMechanic.ID, ShieldMechanic.ID]
  d.name_key = 'Fixture Ward'
  d.icon = 'res://assets/icons/items/skull_shield.png'
  d.cooldown = TRIGGER_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = TRIGGER_SHIELD
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.trigger_subs = [{
    'event': EventBus.Event.APPLIED,
    'seconds': TRIGGER_SECONDS,
    'filter': 'poison',
  }]
  d.panel_colour_name = 'SHIELD'
  return d


## Makes the leftmost opponent Vulnerable for a fixed duration — the generic debuff applier.
static func vulnerable() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_vulnerable'
  d.types = [ItemType.SKILL]
  d.mechanics = []
  d.name_key = 'Fixture Sunder'
  d.cooldown = VULNERABLE_COOLDOWN
  var hit := ItemEffect.new()
  hit.kind = Delivery.Kind.APPLY_STATUS
  hit.status_id = 'vulnerable'
  hit.duration = VULNERABLE_DURATION
  hit.value = 1.0
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  d.effects = [hit]
  d.panel_colour_name = 'ARCANE'
  return d


## Silences one enemy item picked at random on the fight's seeded RNG, with no filter.
static func silence_random_enemy_item() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_silence_random_enemy_item'
  d.types = [ItemType.SPELL]
  d.mechanics = []
  d.name_key = 'Fixture Hex'
  d.cooldown = HEX_COOLDOWN
  var hex := ItemEffect.new()
  hex.kind = Delivery.Kind.APPLY_STATUS
  hex.status_id = 'silence'
  hex.value = 1.0
  hex.shape = ItemEffect.Shape.OPPONENT_ITEM_RANDOM
  d.effects = [hex]
  d.panel_colour_name = 'ARCANE'
  return d


## Applies one charge of 'empowered' to its owner on each fire — the generic empower applier.
static func empower() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_empower'
  d.types = [ItemType.SKILL]
  d.mechanics = []
  d.name_key = 'Fixture Rally'
  d.cooldown = EMPOWER_COOLDOWN
  var buff := ItemEffect.new()
  buff.kind = Delivery.Kind.APPLY_STATUS
  buff.status_id = 'empowered'
  buff.value = EMPOWER_STACKS
  buff.shape = ItemEffect.Shape.SELF
  d.effects = [buff]
  d.panel_colour_name = 'STATUS_EMPOWERED'
  return d


## Every fixture item, for FixtureContent to register in ItemCatalog.
static func all() -> Array[ItemDef]:
  return [
    attack(),
    enemy_attack(),
    shield(),
    poison(),
    charge_your_weapons(),
    silence_enemy_poison_item(),
    poison_trigger(),
    vulnerable(),
    silence_random_enemy_item(),
    empower(),
  ]
