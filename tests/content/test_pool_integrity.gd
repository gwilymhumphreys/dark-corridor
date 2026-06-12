extends GutTest
## Content pool integrity — every string id referenced by a pool / kit / def resolves in
## its catalog (and every applied status id in the StatusRegistry), so a typo'd id fails
## HERE instead of crashing mid-draft or mid-spawn. Catalog get_def hard-errors on an
## unknown id, which is exactly the failure this sweep surfaces at test time.

const CHARACTER_IDS: Array = [
  CharacterCatalog.DEFAULT,
  CharacterCatalog.DUELIST,
  CharacterCatalog.SPORE_DRUID,
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
  for item_id in DraftPool.ITEMS + ColorlessPool.ITEMS:
    item_ids[item_id] = true
  for item_id in item_ids.keys():
    var def: ItemDef = ItemCatalog.get_def(item_id)
    for effect in def.effects:
      if effect.status_id != '':
        assert_true(StatusRegistry.has(effect.status_id), '%s: status %s is registered' % [item_id, effect.status_id])
      if effect.consume_id != '':
        assert_true(StatusRegistry.has(effect.consume_id), '%s: consume target %s is registered' % [item_id, effect.consume_id])
