extends GutTest
## Step 4 — the per-beat orchestrator. A fight spawns its enemies, begin() readies
## the CombatManager, and stepping it to a verdict relays the outcome + reward-kind
## through the Encounter. A rest heals and resolves immediately.


var _encs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  for e in _encs:
    if is_instance_valid(e):
      e.teardown()
      e.free()
  _encs.clear()
  TestCleanup.reset_all_managers()


func _encounter(def_id: int, player: Actor) -> Encounter:
  var e := Encounter.new(EncounterCatalog.get_def(def_id), player)
  _encs.append(e)
  return e


func _default_player(hp: float) -> Actor:
  var a := Actor.new(hp)
  for id in [ItemCatalog.Id.WEAPON, ItemCatalog.Id.ARMOR, ItemCatalog.Id.POISON_DAGGER]:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func test_fight_spawns_enemies_at_creation() -> void:
  var enc := _encounter(EncounterCatalog.Id.FIGHT_GRUNT, _default_player(100.0))
  assert_true(enc.is_fight())
  assert_eq(enc.enemies.size(), 1, 'the grunt is spawned for the approach')
  assert_null(enc.combat_manager(), 'but the CombatManager is not created until begin()')


func test_fight_win_relays_outcome_and_reward() -> void:
  var enc := _encounter(EncounterCatalog.Id.FIGHT_GRUNT, _default_player(100.0))
  watch_signals(enc)
  enc.begin()
  assert_not_null(enc.combat_manager(), 'begin() creates the fight')
  enc.combat_manager().run_headless()
  assert_signal_emitted(enc, 'resolved')
  var params: Array = get_signal_parameters(enc, 'resolved')
  assert_eq(params[0], Encounter.Outcome.WON, 'the 100 HP build beats the grunt')
  assert_eq(params[1], EncounterDef.Reward.DRAFT, 'a regular fight rewards a draft')


func test_fight_loss_relays_lost() -> void:
  var enc := _encounter(EncounterCatalog.Id.FIGHT_GRUNT, _default_player(1.0))
  watch_signals(enc)
  enc.begin()
  enc.combat_manager().run_headless()
  var params: Array = get_signal_parameters(enc, 'resolved')
  assert_eq(params[0], Encounter.Outcome.LOST, 'a 1 HP player loses to the grunt')


func test_rest_heals_and_resolves_immediately() -> void:
  var player := Actor.new(100.0)
  player.take_damage(40.0)   # 60 HP
  var enc := _encounter(EncounterCatalog.Id.REST, player)
  watch_signals(enc)
  enc.begin()
  assert_almost_eq(player.hp, 90.0, 0.0001, 'a 30% rest heals 30 of 100 max')
  assert_signal_emitted_with_parameters(enc, 'resolved', [Encounter.Outcome.RESOLVED, EncounterDef.Reward.NONE])
