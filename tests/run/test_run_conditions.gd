extends GutTest
## The conditions an encounter's requirements and weight rules are built from, and how an encounter
## turns them into the weight it is offered with (docs/plans/encounter_choice.md). The fixture
## character starts with two attack items (weapons) and one shield item (armour).


var _runs: Array = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()
  Save.clear()


func after_each() -> void:
  for r in _runs:
    if is_instance_valid(r):
      r.teardown()
      r.free()
  _runs.clear()
  Save.clear()
  TestCleanup.reset_all_managers()


func _run() -> RunManager:
  var r := RunManager.new()
  _runs.append(r)
  r.start(1, FixtureCharacter.ID)
  return r


# --- conditions -------------------------------------------------------------

func test_has_items_counts_each_listed_item() -> void:
  var run := _run()
  var attack: String = FixtureItems.attack().id
  var shield: String = FixtureItems.shield().id
  assert_true(HasItems.new([attack]).holds(run), 'the board holds an attack item')
  assert_true(HasItems.new([attack], 2).holds(run), 'two of them')
  assert_false(HasItems.new([attack], 3).holds(run), 'but not three')
  assert_true(HasItems.new([attack, shield]).holds(run), 'a combination holds when every item is there')
  assert_false(HasItems.new([attack, FixtureItems.poison().id]).holds(run), 'and fails when one is missing')


func test_has_item_type_counts_items_with_the_tag() -> void:
  var run := _run()
  assert_true(HasItemType.new(ItemType.WEAPON, 2).holds(run), 'two weapons')
  assert_false(HasItemType.new(ItemType.WEAPON, 3).holds(run), 'not three')
  assert_false(HasItemType.new(ItemType.SPELL).holds(run), 'and no spell')


func test_has_relic() -> void:
  var run := _run()
  var condition := HasRelic.new(FixtureKit.SHIELD_RELIC_ID)
  assert_false(condition.holds(run), 'no relic yet')
  run.relics.append(Relic.new(FixtureKit.shield_relic()))
  assert_true(condition.holds(run), 'held once granted')


func test_health_below_and_above() -> void:
  var run := _run()
  run.player.hp = roundi(run.player.max_hp * 0.25)
  assert_true(HealthBelow.new(0.5).holds(run), 'a quarter health is below half')
  assert_false(HealthAbove.new(0.5).holds(run), 'and not above it')
  run.player.hp = run.player.max_hp
  assert_false(HealthBelow.new(0.5).holds(run), 'full health is not below half')
  assert_true(HealthAbove.new(0.5).holds(run), 'it is above it')


func test_gold_at_least() -> void:
  var run := _run()
  assert_false(GoldAtLeast.new(10).holds(run), 'no gold at the start')
  run.gold = 10
  assert_true(GoldAtLeast.new(10).holds(run), 'enough gold')


func test_fight_between_counts_from_one() -> void:
  var run := _run()
  assert_true(FightBetween.new(1, 1).holds(run), 'the opening choice is before fight 1')
  assert_false(FightBetween.new(2).holds(run), 'so it is not before fight 2 or later')
  run.position = 2   # the choice before the second fight
  assert_true(FightBetween.new(2).holds(run), 'the next choice is before fight 2')
  assert_false(FightBetween.new(3, 5).holds(run), 'outside the range')


func test_can_add_ally() -> void:
  var run := _run()
  assert_true(CanAddAlly.new().holds(run), 'a free ally slot')
  for _i in RunManager.MAX_ALLIES:
    run.add_ally(FixtureEnemies.ALLY_ID)
  assert_false(CanAddAlly.new().holds(run), 'none once the slots are full')


func test_not_and_any_of() -> void:
  var run := _run()
  var yes := GoldAtLeast.new(0)
  var no := GoldAtLeast.new(999)
  assert_false(Not.new(yes).holds(run), 'Not turns a holding condition false')
  assert_true(Not.new(no).holds(run), 'and a failing one true')
  assert_true(AnyOf.new([no, yes]).holds(run), 'AnyOf holds when one does')
  assert_false(AnyOf.new([no, no]).holds(run), 'and fails when none do')


# --- the offer weight -------------------------------------------------------

func test_the_offer_weight_follows_the_rarity() -> void:
  var run := _run()
  var def := FixtureEncounters.rest('test_weight')
  assert_eq(def.offer_weight(run), Balance.ENCOUNTER_WEIGHT_COMMON, 'common by default')
  def.rarity = EncounterDef.Rarity.RARE
  assert_eq(def.offer_weight(run), Balance.ENCOUNTER_WEIGHT_RARE, 'rare')


func test_a_failed_requirement_makes_the_weight_zero() -> void:
  var run := _run()
  var def := FixtureEncounters.rest('test_weight')
  def.requires = [GoldAtLeast.new(0), GoldAtLeast.new(999)]
  assert_eq(def.offer_weight(run), 0.0, 'every requirement must hold')
  run.gold = 999
  assert_eq(def.offer_weight(run), Balance.ENCOUNTER_WEIGHT_COMMON, 'offered once they all do')


func test_weight_rules_multiply_while_they_hold() -> void:
  var run := _run()
  var def := FixtureEncounters.rest('test_weight')
  def.weights = [
    { 'if': GoldAtLeast.new(0), 'multiplier': 3.0 },
    { 'if': GoldAtLeast.new(999), 'multiplier': 10.0 },
  ]
  assert_eq(def.offer_weight(run), Balance.ENCOUNTER_WEIGHT_COMMON * 3.0, 'only the rule that holds applies')
  def.weights = [{ 'if': GoldAtLeast.new(0), 'multiplier': 0.0 }]
  assert_eq(def.offer_weight(run), 0.0, 'a multiplier of 0 stops it being offered')
