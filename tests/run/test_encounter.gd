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


func _encounter(def_id: String, player: Actor) -> Encounter:
  var e := Encounter.new(EncounterCatalog.get_def(def_id), player)
  _encs.append(e)
  return e


func _default_player(hp: float) -> Actor:
  var a := Actor.new(hp)
  for id in [ItemCatalog.WEAPON, ItemCatalog.ARMOR, ItemCatalog.POISON_DAGGER]:
    a.board.append(Item.new(ItemCatalog.get_def(id), a))
  return a


func test_fight_spawns_enemies_at_creation() -> void:
  var enc := _encounter(EncounterCatalog.FIGHT_GRUNT, _default_player(100.0))
  assert_true(enc.is_fight())
  assert_eq(enc.enemies.size(), 1, 'the grunt is spawned for the approach')
  assert_null(enc.combat_manager(), 'but the CombatManager is not created until begin()')


func test_fight_win_relays_outcome_and_reward() -> void:
  var enc := _encounter(EncounterCatalog.FIGHT_GRUNT, _default_player(100.0))
  watch_signals(enc)
  enc.begin()
  assert_not_null(enc.combat_manager(), 'begin() creates the fight')
  enc.combat_manager().run_headless()
  assert_signal_emitted(enc, 'resolved')
  var params: Array = get_signal_parameters(enc, 'resolved')
  assert_eq(params[0], Encounter.Outcome.WON, 'the 100 HP build beats the grunt')
  assert_eq(params[1], EncounterDef.Reward.DRAFT, 'a regular fight rewards a draft')


func test_fight_loss_relays_lost() -> void:
  var enc := _encounter(EncounterCatalog.FIGHT_GRUNT, _default_player(1.0))
  watch_signals(enc)
  enc.begin()
  enc.combat_manager().run_headless()
  var params: Array = get_signal_parameters(enc, 'resolved')
  assert_eq(params[0], Encounter.Outcome.LOST, 'a 1 HP player loses to the grunt')


func test_rest_heals_and_resolves_immediately() -> void:
  var player := Actor.new(100.0)
  player.take_damage(40.0)   # 60 HP
  var enc := _encounter(EncounterCatalog.REST, player)
  watch_signals(enc)
  enc.begin()
  assert_almost_eq(player.hp, 90.0, 0.0001, 'a 30% rest heals 30 of 100 max')
  assert_signal_emitted_with_parameters(enc, 'resolved', [Encounter.Outcome.RESOLVED, EncounterDef.Reward.NONE])


func test_event_awaits_its_choice_then_resolves_on_pick() -> void:
  var player := Actor.new(100.0)
  player.take_damage(60.0)   # 40 HP
  var enc := _encounter(EncounterCatalog.EVENT_SHRINE, player)
  assert_true(enc.is_event())
  watch_signals(enc)
  enc.begin()
  assert_almost_eq(player.hp, 40.0, 0.0001, 'an event does NOT resolve/apply on begin — it awaits the pick')
  assert_signal_not_emitted(enc, 'resolved', 'no resolution until an option is picked')
  assert_gt(enc.event_options().size(), 1, 'a binary choice is offered')

  enc.pick_event_option(0)   # 'Kneel and drink' → heal a fraction of max HP
  assert_gt(player.hp, 40.0, 'the chosen outcome (heal) was applied')
  assert_signal_emitted_with_parameters(enc, 'resolved', [Encounter.Outcome.RESOLVED, EncounterDef.Reward.NONE])


func test_fight_seeds_run_scoped_allies_onto_the_player_side() -> void:
  # Cap 3 Stage B: the Encounter hands the CombatManager the run-scoped allies, which fight
  # on the player side (and are NOT dissolved at fight end — they're run-lifetime).
  var player := _default_player(100.0)
  var ally := Actor.new(15.0)
  ally.board.append(Item.new(ItemCatalog.get_def(ItemCatalog.ENEMY_CLAW), ally))
  var enc := Encounter.new(EncounterCatalog.get_def(EncounterCatalog.FIGHT_GRUNT), player, 0, [ally])
  _encs.append(enc)
  enc.begin()
  assert_true(ally in enc.combat_manager().allies, 'the run-scoped ally fights on the player side')
  enc.teardown()
  assert_eq(ally.board.size(), 1, 'the ally keeps its board after the fight (run-scoped, not dissolved)')


func test_event_max_hp_option_grows_max_hp() -> void:
  var player := Actor.new(100.0)
  var enc := _encounter(EncounterCatalog.EVENT_SHRINE, player)
  enc.begin()
  enc.pick_event_option(1)   # 'Pry the shard loose' → +max HP
  assert_almost_eq(player.max_hp, 100.0 + Balance.EVENT_SHRINE_MAX_HP, 0.0001, 'max HP grew')
  assert_almost_eq(player.hp, 100.0 + Balance.EVENT_SHRINE_MAX_HP, 0.0001, 'and current HP too')


func test_lethal_event_outcome_resolves_lost() -> void:
  # A damaging event option that kills the player must end the beat LOST — not
  # RESOLVED with a dead player walking on to the next fight.
  var def := EncounterDef.new()
  def.id = 'test_deathtrap'
  def.type = EncounterDef.Type.EVENT
  var opt := EventOptionDef.new()
  opt.label_key = 'Reach into the dark'
  opt.effect = EventOptionDef.Effect.DAMAGE
  opt.amount = 999.0
  def.event_options = [opt]
  var player := Actor.new(50.0)
  var enc := Encounter.new(def, player)
  _encs.append(enc)
  enc.begin()
  watch_signals(enc)
  enc.pick_event_option(0)
  assert_signal_emitted_with_parameters(enc, 'resolved', [Encounter.Outcome.LOST, EncounterDef.Reward.NONE])


func test_teardown_before_begin_dissolves_spawned_enemies() -> void:
  # Enemies spawn at _init (for the approach); a fight torn down BEFORE begin() has no
  # CombatManager to dissolve them — teardown must break the Actor<->Item cycles itself.
  var enc := Encounter.new(EncounterCatalog.get_def(EncounterCatalog.FIGHT_GRUNT), _default_player(100.0))
  var item_ref: WeakRef = weakref(enc.enemies[0].board[0])
  enc.teardown()
  enc.free()
  assert_null(item_ref.get_ref(), 'a never-begun fight still frees its spawned enemy boards')
