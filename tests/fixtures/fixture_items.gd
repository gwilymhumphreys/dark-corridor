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
const ATTACK_TRAVEL: float = 0.6

const SHIELD_COOLDOWN: float = 2.0
const SHIELD_VALUE: float = 8.0

const POISON_COOLDOWN: float = 1.6
const POISON_STACKS: float = 3.0


## A single-target attack that travels — the generic attacker.
static func attack() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_attack'
  d.types = [ItemType.WEAPON]
  d.name_key = 'Fixture Blade'
  d.icon = 'res://assets/icons/items/old_sword.png'
  d.cooldown = ATTACK_COOLDOWN
  var hit := ItemEffect.new()
  hit.mechanic = AttackMechanic.ID
  hit.value = ATTACK_DAMAGE
  hit.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  hit.travel = ATTACK_TRAVEL
  d.effects = [hit]
  d.panel_color = Colours.ATTACK
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
  d.name_key = 'Fixture Guard'
  d.icon = 'res://assets/icons/items/metal_shield_1.png'
  d.cooldown = SHIELD_COOLDOWN
  var blk := ItemEffect.new()
  blk.mechanic = ShieldMechanic.ID
  blk.value = SHIELD_VALUE
  blk.shape = ItemEffect.Shape.SELF
  d.effects = [blk]
  d.panel_color = Colours.SHIELD
  return d


## A pure applier: stacks poison on the leftmost opponent and deals no direct damage.
static func poison() -> ItemDef:
  var d := ItemDef.new()
  d.id = 'fixture_poison'
  d.types = [ItemType.WEAPON]
  d.name_key = 'Fixture Fang'
  d.icon = 'res://assets/icons/items/loot_26_spiderteeth.png'
  d.cooldown = POISON_COOLDOWN
  var pois := ItemEffect.new()
  pois.mechanic = PoisonMechanic.ID
  pois.value = POISON_STACKS
  pois.shape = ItemEffect.Shape.OPPONENT_LEFTMOST
  pois.travel = ATTACK_TRAVEL
  d.effects = [pois]
  d.panel_color = Colours.POISON
  return d
