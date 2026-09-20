extends GutTest
## Content pool integrity — every string id referenced by a pool / kit / def resolves in
## its catalog (and every applied status id in the StatusRegistry), so a typo'd id fails
## HERE instead of crashing mid-draft or mid-spawn. Catalog get_def hard-errors on an
## unknown id, which is exactly the failure this sweep surfaces at test time.

const CHARACTER_IDS: Array = [
  CharacterCatalog.SPORE_DRUID,
  CharacterCatalog.FLESHMANCER,
]

const ENCOUNTER_IDS: Array = [
  EncounterCatalog.FIGHT_GRUNT,
  EncounterCatalog.REST,
  EncounterCatalog.FIGHT_ELITE,
  EncounterCatalog.FIGHT_RELIC,
  EncounterCatalog.FIGHT_TOUGH,
  EncounterCatalog.FIGHT_BOSS,
  EncounterCatalog.EVENT_SHRINE,
  EncounterCatalog.EVENT_WANDERER,
]

const ITEM_TYPE_IDS: Array = [
  ItemType.WEAPON,
  ItemType.ARMOUR,
  ItemType.SKILL,
  ItemType.SPELL,
  ItemType.TRINKET,
]


func test_character_pools_and_kits_resolve() -> void:
  for character_id in CHARACTER_IDS:
    var def: CharacterDef = CharacterCatalog.get_def(character_id)
    for item_id in def.item_pool + def.starting_item_ids:
      assert_not_null(ItemCatalog.get_def(item_id), '%s: item id %s resolves' % [character_id, item_id])
    if def.starting_relic_id != '':
      assert_not_null(RelicCatalog.get_def(def.starting_relic_id), '%s: starting relic resolves' % character_id)
    for potion_id in def.starting_potion_ids:
      assert_not_null(ConsumableCatalog.get_def(potion_id), '%s: starting potion resolves' % character_id)
    for enchant in def.starting_enchants:
      assert_not_null(EnchantCatalog.get_def(enchant['enchant_id']), '%s: starting enchant resolves' % character_id)


func test_map_beat_pools_resolve() -> void:
  for position in RunMap.TOTAL_BEATS:
    var spec: Dictionary = RunMap.beat_spec(position)
    if spec['kind'] == RunMap.BeatKind.FIXED:
      assert_not_null(EncounterCatalog.get_def(spec['id']), 'beat %d: fixed encounter resolves' % position)
    else:
      for encounter_id in spec['combat_pool'] + spec['event_pool']:
        assert_not_null(EncounterCatalog.get_def(encounter_id), 'beat %d: pool encounter %s resolves' % [position, encounter_id])


func test_encounter_defs_resolve_their_references() -> void:
  for encounter_id in ENCOUNTER_IDS:
    var def: EncounterDef = EncounterCatalog.get_def(encounter_id)
    for enemy_id in def.enemy_ids:
      assert_not_null(EnemyCatalog.get_def(enemy_id), '%s: enemy id %s resolves' % [encounter_id, enemy_id])
    for opt in def.event_options:
      if opt.effect == EventOptionDef.Effect.ADD_ALLY and opt.ally_def_id != '':
        assert_not_null(EnemyCatalog.get_def(opt.ally_def_id), '%s: recruit ally def resolves' % encounter_id)


func test_enemy_boards_resolve() -> void:
  for enemy_id in [EnemyCatalog.GRUNT, EnemyCatalog.BRUTE, EnemyCatalog.BOSS, EnemyCatalog.SPORE_THRALL]:
    var def: EnemyDef = EnemyCatalog.get_def(enemy_id)
    for item_id in def.item_ids:
      assert_not_null(ItemCatalog.get_def(item_id), '%s: board item %s resolves' % [enemy_id, item_id])


func test_reward_relic_pool_resolves() -> void:
  for relic_id in RelicCatalog.REWARD_POOL:
    assert_not_null(RelicCatalog.get_def(relic_id), 'reward relic %s resolves' % relic_id)


func test_draftable_item_effects_reference_registered_statuses() -> void:
  # Every status an item applies (or consumes as fuel) must exist in the StatusRegistry.
  var item_ids: Dictionary = {}
  for character_id in CHARACTER_IDS:
    var character: CharacterDef = CharacterCatalog.get_def(character_id)
    for item_id in character.item_pool + character.starting_item_ids:
      item_ids[item_id] = true
  for item_id in ColorlessPool.ITEMS:
    item_ids[item_id] = true
  for item_id in item_ids.keys():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    for effect in def.effects:
      if effect.status_id != '':
        assert_true(StatusRegistry.has(effect.status_id), '%s: status %s is registered' % [item_id, effect.status_id])
      if effect.consume_id != '':
        assert_true(StatusRegistry.has(effect.consume_id), '%s: consume target %s is registered' % [item_id, effect.consume_id])


## Every mechanic id in an item's authored mechanics list resolves in the MechanicRegistry.
## A typo'd id would silently never match a target filter, so it fails here instead.
func test_item_mechanics_list_resolves() -> void:
  for item_id in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    for mechanic_id in def.mechanics:
      assert_true(MechanicRegistry.has(mechanic_id), '%s: mechanic id %s resolves' % [item_id, mechanic_id])


## Every authored mechanics list is sorted alphabetically by id string and holds no duplicates.
## The failure message prints the correctly sorted list so fixing it is a copy and paste.
func test_item_mechanics_list_sorted_and_unique() -> void:
  for item_id in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    var sorted: Array[String] = []
    for id: String in def.mechanics:
      sorted.append(id)
    sorted.sort()
    var deduped: Array[String] = []
    for id: String in def.mechanics:
      if not deduped.has(id):
        deduped.append(id)
    assert_eq(deduped.size(), def.mechanics.size(),
        '%s: mechanics list holds no duplicates' % item_id)
    assert_true(def.mechanics == sorted,
        '%s: mechanics list is sorted; correct value: %s' % [item_id, sorted])


## The floor: every mechanic an effect deals (its `mechanic` field), applies as a status that is
## also a registered mechanic (`status_id`), or via `crit_chance > 0` (CritMechanic.ID) must be
## listed in the item's authored mechanics list. One-way only — an item may list more.
func test_item_mechanics_floor_is_covered() -> void:
  for item_id in ItemCatalog.all_ids():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    for effect in def.effects:
      if effect.mechanic != '':
        assert_true(def.mechanics.has(effect.mechanic),
            '%s: effect mechanic %s is listed' % [item_id, effect.mechanic])
      if effect.status_id != '' and MechanicRegistry.has(effect.status_id):
        assert_true(def.mechanics.has(effect.status_id),
            '%s: status-as-mechanic %s is listed' % [item_id, effect.status_id])
    if def.crit_chance > 0.0:
      assert_true(def.mechanics.has(CritMechanic.ID),
          '%s: crit chance set but %s not listed' % [item_id, CritMechanic.ID])


## Every target filter condition names an id that resolves: TYPE conditions name an ItemType const,
## MECHANIC conditions resolve in the MechanicRegistry. No catalog item sets a filter yet, so today
## this rests on the two filtered fixtures; it is the guard for when the owner authors one.
func test_item_target_filter_ids_resolve() -> void:
  # The catalog first, then the two filtered fixtures — which are the only authored filters today,
  # so without them this sweep would pass without asserting anything at all.
  var defs: Array[ItemDef] = []
  for item_id in ItemCatalog.all_ids():
    defs.append(ItemCatalog.get_def(item_id))
  defs.append(FixtureItems.charge_your_weapons())
  defs.append(FixtureItems.silence_enemy_poison_item())
  for def: ItemDef in defs:
    var item_id: String = def.id
    for effect in def.effects:
      if effect.target_filter == null:
        continue
      for condition: Dictionary in effect.target_filter.conditions:
        var kind: int = condition.get('kind', TargetFilter.Kind.TYPE)
        var id: String = condition.get('id', '')
        match kind:
          TargetFilter.Kind.TYPE:
            assert_true(ITEM_TYPE_IDS.has(id),
                '%s: target filter TYPE condition id %s is a valid ItemType' % [item_id, id])
          TargetFilter.Kind.MECHANIC:
            assert_true(MechanicRegistry.has(id),
                '%s: target filter MECHANIC condition id %s resolves' % [item_id, id])
