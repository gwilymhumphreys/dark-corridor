class_name FixtureContent
## Puts the test fixtures into the content catalogs (docs/systems/testing.md), so a test can build
## fixture content by id and a whole run plays on fixture content only. A test calls install() in
## before_each; TestCleanup.reset_all_managers() calls uninstall(), so the fixtures never leak into
## the next test.
##
## The catalogs are written to directly rather than through a registration call, so the game has
## no test-only code. Each catalog is built before it is written to, because the catalogs build on
## first access only while they are empty.

static var _installed: bool = false


## Add every fixture definition to its catalog, and put a fixture in place of every authored enemy,
## encounter and relic under the authored id. Every act's regular and boss enemy lists are emptied,
## so filling the authored EnemyPools cannot change which enemies a whole-run test meets. Those three are replaced rather than added because
## the game names them by id (the map names encounters, encounters name enemies, the relic reward
## draws from RelicCatalog.REWARD_POOL); replacing every id keeps this working as content is
## authored. Authored items, characters, potions and enchants stay, but no fixture refers to them.
static func install() -> void:
  assert(ColorlessPool.ITEMS.is_empty(),
    'FixtureContent: the colorless pool is not empty, so fixture runs would draft authored items')
  _build_all()
  for def: ItemDef in FixtureItems.all():
    ItemCatalog._defs[def.id] = def
  CharacterCatalog._defs[FixtureCharacter.ID] = FixtureCharacter.def()
  for id: String in EnemyCatalog._defs.keys():
    EnemyCatalog._defs[id] = FixtureEnemies.enemy(id)
  for def: EnemyDef in [FixtureEnemies.enemy(), FixtureEnemies.big_enemy(), FixtureEnemies.ally()]:
    EnemyCatalog._defs[def.id] = def
  for id: String in EncounterCatalog._defs.keys():
    EncounterCatalog._defs[id] = FixtureEncounters.standing_in_for(EncounterCatalog._defs[id])
  for def: EncounterDef in [FixtureEncounters.fight(), FixtureEncounters.rest(), FixtureEncounters.event()]:
    EncounterCatalog._defs[def.id] = def
  for id: String in RelicCatalog._defs.keys():
    RelicCatalog._defs[id] = FixtureKit.shield_relic(id)
  for def: RelicDef in [FixtureKit.shield_relic(), FixtureKit.max_hp_relic()]:
    RelicCatalog._defs[def.id] = def
  ConsumableCatalog._defs[FixtureKit.POTION_ID] = FixtureKit.potion()
  EnchantCatalog._defs[FixtureKit.ENCHANT_ID] = FixtureKit.enchant()
  EnemyPools._by_act['regular'] = _empty_acts()
  EnemyPools._by_act['boss'] = _empty_acts()
  _installed = true


## Empty the catalogs so the next access rebuilds them from the authored content.
static func uninstall() -> void:
  if not _installed:
    return
  ItemCatalog._defs.clear()
  CharacterCatalog._defs.clear()
  EnemyCatalog._defs.clear()
  EncounterCatalog._defs.clear()
  RelicCatalog._defs.clear()
  ConsumableCatalog._defs.clear()
  EnchantCatalog._defs.clear()
  EnemyPools._by_act.clear()
  _installed = false


## One empty enemy list per act.
static func _empty_acts() -> Array:
  var acts: Array = []
  for act: int in range(RunMap.ACTS):
    acts.append([])
  return acts


static func _build_all() -> void:
  ItemCatalog.all_ids()
  CharacterCatalog.has(FixtureCharacter.ID)
  EnemyCatalog.has(FixtureEnemies.ID)
  if EncounterCatalog._defs.is_empty():
    EncounterCatalog._build()
  if RelicCatalog._defs.is_empty():
    RelicCatalog._build()
  if ConsumableCatalog._defs.is_empty():
    ConsumableCatalog._build()
  if EnchantCatalog._defs.is_empty():
    EnchantCatalog._build()
