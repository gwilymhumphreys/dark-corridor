extends GutTest
## Step 3 — the reward draw. Returns 3 candidates from the pool, distinct within an
## offer, and is fully determined by the handed RNG state (the no-save-scum
## property: same run-state ⇒ same offer).


func before_each() -> void:
  TestCleanup.reset_all_managers()
  FixtureContent.install()   # Draft.draw looks the pool ids up in ItemCatalog


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _ids(offer: Array) -> Array:
  var out: Array = []
  for d in offer:
    out.append(d.id)
  return out


## The fixture character's pool, which has the three items a distinct offer needs.
func _pool() -> Array:
  return FixtureCharacter.def().item_pool


func _rng(seed_value: int) -> RandomNumberGenerator:
  var r := RandomNumberGenerator.new()
  r.seed = seed_value
  return r


func test_draw_returns_three_candidates() -> void:
  var offer := Draft.draw(_pool(), 0, _rng(1))
  assert_eq(offer.size(), 3, 'a 1-of-3 offer')


func test_candidates_come_from_the_pool() -> void:
  var offer := Draft.draw(_pool(), 0, _rng(5))
  for d in offer:
    assert_true(_pool().has(d.id), 'every candidate is a pool item')


func test_offer_is_distinct_when_the_pool_has_breadth() -> void:
  var ids := _ids(Draft.draw(_pool(), 0, _rng(9)))
  assert_eq(ids.size(), 3)
  assert_false(ids[0] == ids[1] or ids[1] == ids[2] or ids[0] == ids[2], 'no duplicate slots (pool >= 3)')


func test_same_rng_state_yields_the_same_offer() -> void:
  var a := _ids(Draft.draw(_pool(), 0, _rng(42)))
  var b := _ids(Draft.draw(_pool(), 0, _rng(42)))
  assert_eq(a, b, 'same seed/state ⇒ identical offer (no save-scum)')


func test_draw_advances_the_rng_deterministically() -> void:
  # Two RNGs seeded alike must produce identical successive offers — proves the
  # draw consumes RNG state deterministically (so the saved state replays).
  var r1 := _rng(7)
  var r2 := _rng(7)
  var a1 := _ids(Draft.draw(_pool(), 0, r1))
  var a2 := _ids(Draft.draw(_pool(), 0, r1))
  var b1 := _ids(Draft.draw(_pool(), 0, r2))
  var b2 := _ids(Draft.draw(_pool(), 0, r2))
  assert_eq(a1, b1, 'first draws match')
  assert_eq(a2, b2, 'second draws match (state advanced identically)')


# --- reward encounter stock (Draft.draw_stock) ------------------------------------

func test_stock_draws_each_entry_in_order() -> void:
  var stock: Array[StockEntry] = [StockEntry.items(2), StockEntry.relics(1), StockEntry.potions(1)]
  var goods: Array = Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(3))
  assert_eq(goods.size(), 4, 'two items, a relic and a potion')
  assert_true(goods[0] is ItemDef and not goods[0] is RelicDef, 'items first')
  assert_true(goods[1] is ItemDef and not goods[1] is RelicDef, 'both of them')
  assert_true(goods[2] is RelicDef, 'then the relic')
  assert_true(goods[3] is ConsumableDef, 'then the potion')


func test_stock_items_keep_to_the_entry_types() -> void:
  var stock: Array[StockEntry] = [StockEntry.items(3, [ItemType.ARMOUR] as Array[String])]
  for seed_value: int in range(10):
    for def: ItemDef in Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(seed_value)):
      assert_true(ItemType.ARMOUR in def.types, 'only armour items are offered')


func test_stock_with_no_matching_item_offers_none() -> void:
  var stock: Array[StockEntry] = [StockEntry.items(2, [ItemType.SPELL] as Array[String])]
  assert_eq(Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(1)).size(), 0, 'the pool has no spell')


func test_stock_relics_never_repeat() -> void:
  var stock: Array[StockEntry] = [StockEntry.relics(RelicCatalog.REWARD_POOL.size() + 2)]
  var ids := _ids(Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(7)))
  assert_eq(ids.size(), RelicCatalog.REWARD_POOL.size(), 'no more relics than the pool holds')
  for id: String in ids:
    assert_eq(ids.count(id), 1, 'each relic once')


func test_stock_draw_is_determined_by_the_rng() -> void:
  var stock: Array[StockEntry] = [StockEntry.items(2), StockEntry.relics(2)]
  assert_eq(_ids(Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(11))), _ids(Draft.draw_stock(stock, _pool(), RelicCatalog.REWARD_POOL, _rng(11))),
    'the same RNG state draws the same goods')


func test_stock_relics_come_from_the_relic_pool_handed_in() -> void:
  var stock: Array[StockEntry] = [StockEntry.relics(3)]
  var pool: Array = [RelicCatalog.REWARD_POOL[0]]
  assert_eq(_ids(Draft.draw_stock(stock, _pool(), pool, _rng(2))), pool, 'only the relics in the pool')
  assert_eq(Draft.draw_stock(stock, _pool(), [], _rng(2)).size(), 0, 'none from an empty pool')


func test_can_draw_stock_says_whether_anything_would_be_drawn() -> void:
  var relics_only: Array[StockEntry] = [StockEntry.relics(1)]
  assert_true(Draft.can_draw_stock(relics_only, _pool(), RelicCatalog.REWARD_POOL), 'relics are left')
  assert_false(Draft.can_draw_stock(relics_only, _pool(), []), 'no relics are left')
  var spells: Array[StockEntry] = [StockEntry.items(1, [ItemType.SPELL] as Array[String])]
  assert_false(Draft.can_draw_stock(spells, _pool(), []), 'no item matches')
  spells.append(StockEntry.potions(1))
  assert_true(Draft.can_draw_stock(spells, _pool(), []), 'but a potion can be drawn')
