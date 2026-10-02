class_name RunManager
extends Node
## The descent (docs/systems/run_manager.md) — one run, instanced/owned by the Game manager.
## Owns the map, the player run-state { actor, relics, potions, position, gold, rng },
## the HP-economy, the sequencing cycle, and the run snapshot. Signals
## `run_ended(outcome)` up to Game on a death / final win.
##
## It advances by explicit call + signal — never _process. A fight beat's
## CombatManager clock is supplied externally (the autotest steps sim_step; the
## Phase-4 run screen will drive _physics_process), so the cycle here is: enter a
## beat (create the Encounter + auto-save) → begin it → on its `resolved` fulfil
## the reward (a pending offer of goods / a shop / a relic / none) and check run-end → the caller
## supplies a pick → advance. The Run manager is kept out of the scene tree
## in Phase 3 (driven by calls); freeing is manual via teardown().

signal run_ended(outcome: int)

enum Outcome { WON, DIED }

# The run events a relic's run_triggers react to (docs/systems/content.md → Relic).
enum RunEvent { PICKED_UP, FIGHT_WON, DRAFT_SKIPPED }

# Spreads the run seed into a distinct per-beat combat stream (a prime stride).
const COMBAT_SEED_STRIDE: int = 1000003

# The player side holds at most this many run-scoped allies (the 4 ally slots flanking the
# player — UI/Layout). The cap is the safety net: add_ally past it is a no-op. The placeholder
# recruit event relies on that; richer acquisition content can gate on can_add_ally() first to
# avoid offering a "join me" choice that can't be filled.
const MAX_ALLIES: int = 4

# Run-state (the snapshot persists exactly this). `position` is the global beat index
# (0 .. RunMap.TOTAL_BEATS-1); the act/beat-within-act are derived (RunMap).
var player: Actor
var allies: Array[Actor] = []        # run-scoped (persistent) player-side allies (shared
                                     # BY REFERENCE into the live CombatManager — untyped there)
var relics: Array[Relic] = []
var potions: Array[Consumable] = []
var position: int = 0
# Banked gold — a run-state resource (docs decision #33). Sources: skipping a draft
# (apply_draft_skip), walking past a choice, winning a fight, and run effects (RunEffect.GOLD, which
# an event option can also use as a cost). Persists in the snapshot.
var gold: int = 0
## Run flags (docs/plans/encounter_choice.md): a flag name to a whole number, set by run effects
## (SET_FLAG, ADD_FLAG) and read by conditions (FlagAtLeast, FlagBelow), so an encounter can remember
## what the player did. Never shown to the player. Persists in the snapshot.
var flags: Dictionary = {}
## How many times each encounter id was picked from a choice of encounters and finished (counted
## when it resolves), read by TimesPicked. Persists in the snapshot.
var times_picked: Dictionary = {}
var rng: RandomNumberGenerator
var character: CharacterDef    # the chosen character (#27) — its item pool feeds the draft

var _ally_def_ids: Array[String] = []  # parallel to `allies` — each ally's EnemyCatalog def id (snapshot)

var _current: Encounter = null
var _current_def_id: String = ''    # the resolved EncounterDef id for the current beat (resume)
# The enemies drawn for the current beat (docs/plans/encounter_points_budget.md). Empty for a
# non-fight, a boss, or an unpooled act — the Encounter then uses the def's authored enemy_ids.
# Saved, because the RNG state is written AFTER the draw, so a resume cannot redraw the same set.
var _current_enemy_ids: Array[String] = []

## Dev and test only (docs/systems/autotest.md): when non-empty, EVERY fight uses these EnemyCatalog
## ids — bosses and authored compositions included — so a tuning run reads one composition rather
## than generation noise. Static so the autotest can set it before a run starts. Never set in play.
static var pinned_enemy_ids: Array[String] = []
# The choice beat's offer: one EncounterCatalog id per card position, left to right, '' for a
# position left empty (only when fewer than three encounters can be offered). Empty otherwise.
var _pending_choice: Array[String] = []
# The held offer the player picks one of: a reward encounter's goods (a mix of ItemDef, RelicDef
# and ConsumableDef). It can be skipped for gold (apply_draft_skip).
var _pending_offer: Array = []
# The level of each good in _pending_offer, by index: drawn for an item, 1 for a relic or a potion.
var _pending_offer_levels: Array[int] = []
# The open shop's goods (ItemDef, RelicDef or ConsumableDef), their levels (as _pending_offer_levels),
# which of them are sold, by index, and how many rerolls this visit has had. Not saved: a resume
# re-enters the shop and draws the same goods and levels, with the gold as it was when the shop was
# picked. A shop stays open while its goods are empty, as after a reroll that draws nothing.
var _shop_open: bool = false
var _shop_goods: Array = []
var _shop_levels: Array[int] = []
var _shop_sold: Array[bool] = []
var _shop_rerolls: int = 0
var _ended: bool = false
var _outcome: int = Outcome.WON
var _torn_down: bool = false


# --- fresh run --------------------------------------------------------------

func start(seed_value: int, character_id: String = CharacterCatalog.DEFAULT) -> void:
  rng = RandomNumberGenerator.new()
  rng.seed = seed_value
  character = CharacterCatalog.get_def(character_id)
  player = _make_starting_player()
  # Starting kit from the character (#27): its signature relic, any starting enchants on
  # the board, and its starting potions — the run opens in the character's identity.
  relics = []
  gold = 0
  flags = {}
  times_picked = {}
  if character.starting_relic_id != '':
    var starting_relic := Relic.new(RelicCatalog.get_def(character.starting_relic_id))
    relics.append(starting_relic)
    _apply_relic_grant(starting_relic)
  potions = []
  for potion_id in character.starting_potion_ids:
    potions.append(Consumable.new(ConsumableCatalog.get_def(potion_id)))
  for enchant_spec in character.starting_enchants:
    apply_enchant(Enchantment.new(EnchantCatalog.get_def(enchant_spec['enchant_id'])), enchant_spec['item_index'])
  position = 0
  _ended = false
  _set_offer([])
  _close_shop()
  _current_def_id = ''
  _pending_choice = []
  allies = []                  # no starting allies by default (the owner wires acquisition)
  _ally_def_ids = []
  _enter_beat(position)
  _save()


## Build the run-start player Actor from the character's starting board (#27). Run-lifetime,
## owned here. Max HP is the character's (the global default unless its def sets one).
func _make_starting_player() -> Actor:
  var actor: Actor = character.make_actor()
  for id in CharacterCatalog.starting_board(character, rng):
    actor.board.append(Item.new(ItemCatalog.get_def(id), actor))
  return actor


# --- the cycle (driven by the autotest / run screen) ------------------------

func current_encounter() -> Encounter:
  return _current


func combat_manager() -> CombatManager:
  return _current.combat_manager() if _current != null else null


func act() -> int:
  return RunMap.act_of(position)


func beat_in_act() -> int:
  return RunMap.beat_in_act(position)


# --- the choice of encounters before each fight (docs/plans/encounter_choice.md) ----------------

## True while a choice beat is waiting on the player to pick an encounter or walk past.
func has_pending_choice() -> bool:
  return not _pending_choice.is_empty()


## The offered EncounterDef ids, one per card position left to right; '' marks an empty position.
func pending_choice() -> Array:
  return _pending_choice


## Apply the player's pick: the chosen encounter becomes the live `Encounter` (created here, then it
## resolves). Re-saves so resume re-enters the PICKED encounter, not the choice. An empty position
## cannot be picked.
func pick_path(index: int) -> void:
  if _pending_choice.is_empty():
    return
  var id: String = _pending_choice[clampi(index, 0, _pending_choice.size() - 1)]
  if id == '':
    return
  _current_def_id = id
  _pending_choice = []
  _current_enemy_ids = _draw_enemies(EncounterCatalog.get_def(_current_def_id))
  _create_current_encounter()
  _save()


## Debug only (the F7 Restart encounter button): offer this beat's encounters again, dropping the
## picked encounter, its open shop and its pending offer. Anything the encounter already gave or
## took, such as a rest's heal or gold spent in a shop, stays.
func offer_choice_again(ids: Array[String]) -> void:
  _teardown_current()
  _current_def_id = ''
  _current_enemy_ids = []
  _close_shop()
  _set_offer([])
  _pending_choice = ids.duplicate()
  _save()


## Walk past the three encounters: bank Balance.ENCOUNTER_SKIP_GOLD and leave the beat with no
## encounter, so the caller advances straight to the fight. Draws no run RNG.
func skip_choice() -> void:
  if _pending_choice.is_empty():
    return
  gold += Balance.ENCOUNTER_SKIP_GOLD
  _pending_choice = []


# Draw the choice beat's offer: one encounter per position from that position's EncounterPools list,
# by weight on the run RNG, never the same encounter twice and never one the player cannot choose (its
# requirements fail). A position whose own list has nothing left to offer takes one from the other
# lists instead, so the offer is three whenever three encounters can be offered; only then is a
# position left '' (docs/plans/encounter_choice.md).
func _draw_choice() -> Array[String]:
  var offer: Array[String] = []
  for index: int in EncounterPools.POSITIONS:
    offer.append(_draw_one(EncounterPools.at(index), offer))
  for index: int in offer.size():
    if offer[index] == '':
      var others: Array[String] = []
      for list: int in EncounterPools.POSITIONS:
        others.append_array(EncounterPools.at(list))
      offer[index] = _draw_one(others, offer)
  return offer


# One id from `ids`, not already in `offer`, drawn by EncounterDef.offer_weight; '' when none can be
# offered.
func _draw_one(ids: Array[String], offer: Array[String]) -> String:
  var eligible: Array[String] = []
  var weights: Array[float] = []
  var total: float = 0.0
  for id: String in ids:
    if id in offer or id in eligible:
      continue
    var weight: float = EncounterCatalog.get_def(id).offer_weight(self)
    if weight <= 0.0:
      continue
    eligible.append(id)
    weights.append(weight)
    total += weight
  if eligible.is_empty():
    return ''
  var roll: float = rng.randf() * total
  for i in eligible.size():
    roll -= weights[i]
    if roll < 0.0:
      return eligible[i]
  return eligible[-1]   # float rounding left the roll at the very top


## Begin resolving the current beat. For a fight, builds the player's relic items first, so the
## Combat manager registers them with the board, then begins it. A rest resolves synchronously (its heal lands and `resolved`
## fires here); a fight readies its CombatManager for the caller to step.
func begin_current() -> void:
  if _current == null or _ended:
    return
  if not _current.resolved.is_connected(_on_encounter_resolved):
    _current.resolved.connect(_on_encounter_resolved)
  if _current.is_fight():
    _build_relic_items()      # before begin(): the Combat manager registers them at start()
  _current.begin()
  # Ordering constraint: revive runs AFTER begin() (the CM exists, its registration done). Safe
  # because registration reads no HP and no sim time passes until the caller steps — don't insert
  # anything between that changes that.
  if _current.is_fight():
    _revive_allies()          # run-scoped allies enter every fight at full HP (downed → revived)


## Run-scoped allies are revived to full HP at the start of every fight (design: allies revive
## between combats — only the player carries HP attrition through the run). A downed ally from
## the previous fight is restored; its slot was kept on the roster, so it simply rejoins.
func _revive_allies() -> void:
  for ally in allies:
    ally.hp = ally.max_hp


## Give the player one Item per relic for this fight (Actor.relics, docs/systems/content.md → Relic).
## Combat-scoped: CombatManager.teardown dissolves and empties the list, so each fight starts fresh.
func _build_relic_items() -> void:
  for it in player.relics:
    it.dissolve()
  player.relics.clear()
  for relic in relics:
    player.relics.append(Item.new(relic.def, player))


func _on_encounter_resolved(outcome_value: int, reward: int) -> void:
  if RunMap.is_choice_beat(position):   # the encounter was picked from the choice of encounters
    times_picked[_current_def_id] = int(times_picked.get(_current_def_id, 0)) + 1
  if outcome_value == Encounter.Outcome.LOST:
    _end_run(Outcome.DIED)
    return
  if RunMap.is_final_beat(position):   # the final act's boss — beating it ends the descent
    _end_run(Outcome.WON)
    return
  # Before the reward, so a relic won in this fight does not react to winning it. Only a fight
  # resolves WON (a rest or event resolves RESOLVED).
  if outcome_value == Encounter.Outcome.WON:
    _apply_fight_won_gain()
    _fire_run_event(RunEvent.FIGHT_WON)
    if _ended:
      return   # a relic's fight-won damage killed the player
  match reward:
    EncounterDef.Reward.RELIC, EncounterDef.Reward.ELITE:
      _grant_relic()                                          # an act boss or an elite
    EncounterDef.Reward.GOODS:
      _set_offer(Draft.draw_stock(_current.def.stock, _draft_pool(), relic_pool(), rng))   # a reward encounter
    EncounterDef.Reward.SHOP:
      _shop_open = true
      _shop_rerolls = 0
      _draw_shop_goods()
    _:
      pass


## Every fight won gives some health and gold before its reward (owner, docs/plans/encounter_choice.md).
func _apply_fight_won_gain() -> void:
  _apply_run_effect(RunEffect.heal(Balance.FIGHT_WON_HEAL))
  _apply_run_effect(RunEffect.gold(Balance.FIGHT_WON_GOLD))


## The reward relics the player does not hold yet: RelicCatalog.REWARD_POOL minus the relics held, in
## pool order. Every relic reward draws from this, so the player never gets the same relic twice. It
## is worked out from the relics held, so it needs no saving.
func relic_pool() -> Array[String]:
  var held: Array = relics.map(func(relic: Relic) -> String: return relic.def.id)
  var pool: Array[String] = []
  for id: String in RelicCatalog.REWARD_POOL:
    if not id in held:
      pool.append(id)
  return pool


## Whether a reward encounter with `stock` would offer at least one good now (EncounterDef.offer_weight).
func can_draw_stock(stock: Array[StockEntry]) -> bool:
  return Draft.can_draw_stock(stock, _draft_pool(), relic_pool())


## Whether every item entry in `stock` has at least `minimum` matching items in the player's pool
## (the character's pool plus the colourless items). Entries for relics and potions are not counted.
func has_items_for(stock: Array[StockEntry], minimum: int) -> bool:
  var pool: Array = _draft_pool()
  return stock.all(func(entry: StockEntry) -> bool:
    return entry.kind != StockEntry.Kind.ITEM or Draft.matching_items(entry, pool).size() >= minimum)


## The draft pool handed to Draft (#27): the chosen character's pool plus the shared
## colorless items (the exception-that-earns-it). Draft stays pool-agnostic — it draws
## from whatever this composes.
func _draft_pool() -> Array:
  return character.item_pool + ColorlessPool.ITEMS


## Grant a relic reward (#2): draw one from the reward pool on the run RNG (so it's
## deterministic + resume-stable), add it to run-state, and apply any one-time direct mod.
func _grant_relic() -> void:
  var pool: Array[String] = relic_pool()
  if pool.is_empty():
    push_warning('RunManager: a relic reward fired but the player holds every reward relic — nothing granted')
    return
  var id: String = pool[rng.randi_range(0, pool.size() - 1)]
  var relic := Relic.new(RelicCatalog.get_def(id))
  relics.append(relic)
  _apply_relic_grant(relic)


## Fire a newly granted relic's PICKED_UP run triggers, once. Their result is kept in the saved
## health and gold, and rehydrate does not call this, so it is never applied twice. A relic's fight
## triggers have no grant-time effect (its item is built per fight, above).
func _apply_relic_grant(relic: Relic) -> void:
  _fire_relic_run_triggers(relic, RunEvent.PICKED_UP)


## Apply the run triggers for `event` of every relic the run holds, in relic order.
func _fire_run_event(event: RunEvent) -> void:
  for relic in relics:
    _fire_relic_run_triggers(relic, event)


func _fire_relic_run_triggers(relic: Relic, event: RunEvent) -> void:
  for entry: Dictionary in relic.def.run_triggers:
    if entry.get('event', -1) != event:
      continue
    for effect: RunEffect in entry.get('effects', []):
      _apply_run_effect(effect)
  if not player.is_alive():
    _end_run(Outcome.DIED)   # lethal run-trigger damage ends the run at once


## Apply one run effect (relic run triggers, event options). Lethal DAMAGE is not handled here: a
## relic's run triggers check the player once they have all applied (_fire_relic_run_triggers), and
## an event checks the player after its effects (Encounter.resolve_event).
func _apply_run_effect(effect: RunEffect) -> void:
  match effect.kind:
    RunEffect.Kind.MAX_HP:
      player.max_hp += effect.amount
      player.hp += effect.amount
    RunEffect.Kind.HEAL:
      player.heal(effect.amount)
    RunEffect.Kind.GOLD:
      gold += effect.amount
    RunEffect.Kind.HEAL_FRACTION:
      player.heal(effect.fraction * player.max_hp)
    RunEffect.Kind.DAMAGE:
      player.take_damage(effect.amount)
    RunEffect.Kind.ADD_ALLY:
      add_ally(effect.id)
    RunEffect.Kind.SET_FLAG:
      flags[effect.id] = effect.amount
    RunEffect.Kind.ADD_FLAG:
      flags[effect.id] = flag(effect.id) + effect.amount
    RunEffect.Kind.GAIN_ITEM:
      player.board.append(Item.new(ItemCatalog.get_def(effect.id), player))
    RunEffect.Kind.GAIN_RELIC:
      var relic := Relic.new(RelicCatalog.get_def(effect.id))
      relics.append(relic)
      _apply_relic_grant(relic)
    RunEffect.Kind.GAIN_POTION:
      potions.append(Consumable.new(ConsumableCatalog.get_def(effect.id)))


## The value of the run flag `flag_name`; 0 when it was never set.
func flag(flag_name: String) -> int:
  return int(flags.get(flag_name, 0))


## True while an offer waits for the player: a reward encounter's goods.
func has_pending_draft() -> bool:
  return not _pending_offer.is_empty()


## The offered goods: ItemDef, RelicDef or ConsumableDef.
func pending_draft() -> Array:
  return _pending_offer


## The level of each offered good, in the order of pending_draft (1 for a relic or a potion).
func pending_draft_levels() -> Array[int]:
  return _pending_offer_levels


## Apply the player's pick from the offer (a draft-pick intent): an item goes on the board at its
## offered level, a relic to the relics (its PICKED_UP triggers fire), a potion to the potions. Clears
## the offer. Skipping instead banks gold — apply_draft_skip.
func apply_draft_pick(index: int) -> void:
  if _pending_offer.is_empty():
    return
  var picked_index: int = clampi(index, 0, _pending_offer.size() - 1)
  var picked: Variant = _pending_offer[picked_index]
  var level: int = _pending_offer_levels[picked_index]
  _set_offer([])
  _gain(picked, level)


# Hold `goods` as the pending offer, each with a level (_draw_offer_levels). An empty list clears it.
func _set_offer(goods: Array) -> void:
  _pending_offer = goods
  _pending_offer_levels = _draw_offer_levels(goods)


## The level of an item offered at fight number `fight` (RunMap.fight_number, from 0): a weighted draw
## on `rng` from that fight's row of Balance.ITEM_OFFER_LEVEL_ODDS, or the last row past the end. A row
## with only level 1 draws no RNG.
static func draw_offer_level(fight: int, rng_value: RandomNumberGenerator) -> int:
  var rows: Array[Array] = Balance.ITEM_OFFER_LEVEL_ODDS
  var odds: Array = rows[clampi(fight, 0, rows.size() - 1)]
  if odds.size() <= 1:
    return 1
  return mini(rng_value.rand_weighted(PackedFloat32Array(odds)) + 1, Balance.ITEM_MAX_LEVEL)


# The level of each of `goods`: drawn for an item (draw_offer_level at this beat's fight number), 1 for
# a relic or a potion, which are item definitions too.
func _draw_offer_levels(goods: Array) -> Array[int]:
  var levels: Array[int] = []
  for good: Variant in goods:
    var is_item: bool = good is ItemDef and not (good is RelicDef or good is ConsumableDef)
    levels.append(draw_offer_level(RunMap.fight_number(position), rng) if is_item else 1)
  return levels


# Give the player one of the goods: an item goes on the board at `level`, a relic to the relics (its
# PICKED_UP triggers fire), a potion to the potions. Relics and potions are item definitions too, so
# they are checked first.
func _gain(good: Variant, level: int = 1) -> void:
  if good is RelicDef:
    var relic := Relic.new(good)
    relics.append(relic)
    _apply_relic_grant(relic)
  elif good is ConsumableDef:
    potions.append(Consumable.new(good))
  elif good is ItemDef:
    var item := Item.new(good, player)
    item.level = level
    player.board.append(item)


## Skip the pending offer (a draft-skip intent, the sibling of apply_draft_pick): bank a fixed
## amount of gold (Balance.GOLD_SKIP) instead of taking one, then clear the offer. The escape hatch
## from an anti-synergy draft (docs decision #33 — reverses #17's no-skip), and a way to change one's
## mind after picking a reward encounter. Draws no run RNG, like a pick.
func apply_draft_skip() -> void:
  if _pending_offer.is_empty():
    return
  gold += Balance.GOLD_SKIP
  _set_offer([])
  _fire_run_event(RunEvent.DRAFT_SKIPPED)


# --- the shop (docs/systems/encounter.md → Shops) ------------------------------

## True while a shop is open: the player buys what they want and then leaves (leave_shop).
func has_open_shop() -> bool:
  return _shop_open


## The open shop's goods, in stock order: ItemDef, RelicDef or ConsumableDef. Sold goods stay in the
## list (is_sold).
func shop_goods() -> Array:
  return _shop_goods


func is_sold(index: int) -> bool:
  return index >= 0 and index < _shop_sold.size() and _shop_sold[index]


## The level of the shop good at `index` (1 for a relic or a potion).
func shop_level(index: int) -> int:
  return _shop_levels[index] if index >= 0 and index < _shop_levels.size() else 1


## What the shop charges for the good at `index`: its price at its level (price_at_level).
func shop_price(index: int) -> int:
  return price_at_level(_shop_goods[index], shop_level(index))


## What a shop charges for `good`: a Balance value by its kind (item, relic, potion) and rarity.
static func price_of(good: Variant) -> int:
  var prices: Array[int] = Balance.SHOP_PRICE_ITEM
  if good is RelicDef:
    prices = Balance.SHOP_PRICE_RELIC
  elif good is ConsumableDef:
    prices = Balance.SHOP_PRICE_POTION
  return prices[clampi(good.rarity, 0, prices.size() - 1)]


## What `good` is worth at `level`: the price of the level 1 copies it would be merged from (price_of,
## doubled for each level above 1).
static func price_at_level(good: Variant, level: int) -> int:
  return price_of(good) * (1 << (level - 1))


## Whether the player can buy the good at `index` now: it is on sale, not sold, and affordable.
func can_buy(index: int) -> bool:
  return index >= 0 and index < _shop_goods.size() and not _shop_sold[index] \
    and gold >= shop_price(index)


## Buy the good at `index`: pay its price and gain it at its level. Returns false, changing nothing,
## when it cannot be bought (can_buy). Draws no run RNG.
func buy(index: int) -> bool:
  if not can_buy(index):
    return false
  gold -= shop_price(index)
  _shop_sold[index] = true
  _gain(_shop_goods[index], shop_level(index))
  return true


## What the next reroll of the open shop costs: SHOP_REROLL_PRICE, plus SHOP_REROLL_PRICE_STEP for
## each reroll already made in this visit.
func reroll_price() -> int:
  return Balance.SHOP_REROLL_PRICE + Balance.SHOP_REROLL_PRICE_STEP * _shop_rerolls


## Whether the player can reroll the open shop now: a shop is open and they can pay.
func can_reroll() -> bool:
  return _shop_open and gold >= reroll_price()


## Reroll the open shop: pay reroll_price and draw every good again from the shop's stock, bought
## goods included (owner). A relic bought earlier has left the relic pool, so it is not offered
## again. Returns false, changing nothing, when the shop cannot be rerolled (can_reroll).
func reroll_shop() -> bool:
  if not can_reroll():
    return false
  gold -= reroll_price()
  _shop_rerolls += 1
  _draw_shop_goods()
  return true


## Leave the open shop. The caller then advances.
func leave_shop() -> void:
  _close_shop()


func _draw_shop_goods() -> void:
  _shop_goods = Draft.draw_stock(_current.def.stock, _draft_pool(), relic_pool(), rng)
  _shop_levels = _draw_offer_levels(_shop_goods)
  _shop_sold.assign(_shop_goods.map(func(_good: Variant) -> bool: return false))


func _close_shop() -> void:
  _shop_open = false
  _shop_goods = []
  _shop_levels = []
  _shop_sold = []
  _shop_rerolls = 0


# --- selling items (docs/systems/run_manager.md → Selling) --------------------

## What `item` is worth at its level (price_at_level of its definition).
static func item_price(item: Item) -> int:
  return price_at_level(item.def, item.level)


## What selling `item` gives: SELL_SHARE of item_price, rounded down. An enchant does not change it.
static func sell_price(item: Item) -> int:
  return floori(item_price(item) * Balance.SELL_SHARE)


## Whether the player can sell `item` now: it is on their board and no fight is under way (the
## choice of encounters, events, rests, reward encounters and shops all allow it).
func can_sell(item: Item) -> bool:
  if _ended or item == null or not item in player.board:
    return false
  var cm: CombatManager = combat_manager()
  return cm == null or cm.is_resolved()


## Sell `item`: take it off the board and add sell_price to gold. Returns false, changing nothing,
## when it cannot be sold (can_sell). Kept by the next save, like a shop purchase.
func sell_item(item: Item) -> bool:
  if not can_sell(item):
    return false
  gold += sell_price(item)
  player.board.erase(item)
  item.dissolve()   # as CombatManager.remove_item does
  return true


# --- merging items (docs/systems/run_manager.md → Merging items) -------------

## The copy `item` would merge with: another item on the board with the same definition and level,
## or null. One with no enchantment is preferred, so no enchantment is lost when one can be kept.
func merge_partner(item: Item) -> Item:
  var partner: Item = null
  for other: Item in player.board:
    if other == item or other.def.id != item.def.id or other.level != item.level:
      continue
    if other.enchant == null:
      return other
    if partner == null:
      partner = other
  return partner


## Whether the player can merge `item` now: it could be sold now (on the board, no fight under way),
## it is below Balance.ITEM_MAX_LEVEL, and a copy at its level is on the board.
func can_merge(item: Item) -> bool:
  return can_sell(item) and item.level < Balance.ITEM_MAX_LEVEL and merge_partner(item) != null


## Whether merging `item` loses an enchantment: it and its copy both hold one, and only `item`'s is kept.
func will_lose_enchantment(item: Item) -> bool:
  var partner: Item = merge_partner(item)
  return partner != null and item.enchant != null and partner.enchant != null


## Merge `item` with its copy (decision #61): `item` goes up a level and keeps its place on the board,
## takes the copy's enchantment when it has none, and the copy leaves the board. Returns false,
## changing nothing, when it cannot be merged (can_merge). Costs nothing and draws no run RNG.
func merge_item(item: Item) -> bool:
  if not can_merge(item):
    return false
  var partner: Item = merge_partner(item)
  item.level += 1
  if item.enchant == null:
    item.enchant = partner.enchant
  player.board.erase(partner)
  partner.dissolve()   # as sell_item does
  return true


## Whether the player side has a free ally slot (cap = MAX_ALLIES). The gating surface for
## acquisition content (a draftable `ally` category, or a recruit event that wants to hide its
## offer when full) — the cap in add_ally enforces it regardless.
func can_add_ally() -> bool:
  return allies.size() < MAX_ALLIES


## Acquire a run-scoped (persistent) ally (docs/systems/spore_engine.md Cap 3, Stage B): build an Actor
## from an EnemyDef and add it to the player-side roster. It persists across fights, is saved
## in the snapshot, and joins every fight (the Encounter seeds the CombatManager with it).
## The acquisition path today is a run effect (RunEffect.ADD_ALLY, used by the recruit event); a
## draftable `ally` category is the deferred alternative. No-op past the MAX_ALLIES cap.
func add_ally(def_id: String) -> void:
  if not can_add_ally():
    return   # the 4 ally slots are full — the source should have gated on can_add_ally()
  var ally := _make_ally(def_id)
  allies.append(ally)   # the live CombatManager shares this array by reference, so it sees it
  _ally_def_ids.append(def_id)
  var combat: CombatManager = combat_manager()
  if combat != null and not combat.is_resolved():
    combat.register_ally(ally)   # acquired mid-fight → register its Tickers so it joins the fight


## The indices of the current event's options that the player can pick now (their conditions
## hold). The event panel shows only these, and pick_event_option refuses any other. Empty when
## the current beat is not an event.
func available_event_options() -> Array[int]:
  if _current == null or not _current.is_event():
    return []
  return _current.def.available_options(self)


## The event option intent (docs/systems/encounter.md): apply every run effect of the option at
## `index` in the event's authored list, in order, then resolve the event (lost if the effects
## killed the player). Refuses an index out of range or an option whose conditions do not hold.
## The autotest and the run screen call this for events.
func pick_event_option(index: int) -> void:
  if _current == null or not _current.is_event():
    return
  var options: Array[EventOptionDef] = _current.def.event_options
  if index < 0 or index >= options.size():
    return
  var option: EventOptionDef = options[index]
  if not option.is_available(self):
    push_warning('RunManager: event option %d of %s was picked but its conditions do not hold' % [index, _current_def_id])
    return
  for effect: RunEffect in option.effects:
    _apply_run_effect(effect)
  _current.resolve_event()


func _make_ally(def_id: String) -> Actor:
  return EnemyCatalog.get_def(def_id).make_actor()


## Attach an enchantment to a chosen board item (the enchant-target sub-choice; a
## drafted-enchant intent, or the starting-kit grant). One enchant per item.
func apply_enchant(enchant: Enchantment, item_index: int) -> void:
  if item_index < 0 or item_index >= player.board.size():
    return
  player.board[item_index].enchant = enchant


## Throw-potion intent: consume the potion in `index` and activate it in the live
## fight (docs/systems/content.md). Only valid mid-fight (a consumable resolves through the
## Combat manager). Returns whether it was thrown.
func throw_potion(index: int) -> bool:
  var combat: CombatManager = combat_manager()
  if combat == null or index < 0 or index >= potions.size():
    return false
  var consumable: Consumable = potions[index]
  potions.remove_at(index)
  combat.throw_consumable(consumable, player)
  return true


## Advance to the next beat: tear the resolved one down, apply the between-act full heal
## when crossing into a new act (HP-economy, design), step position, enter the next beat
## (a fight, or a fresh choice of encounters), and auto-save (the encounter-entry resume point).
func advance() -> void:
  if _ended:
    return
  if not _pending_offer.is_empty():
    # The consume-before-advance invariant: a draft must be resolved — by a pick OR a skip
    # (docs decision #33) — before advancing. A caller that advances past one has a flow bug —
    # drop the offer loudly rather than carry it unsaved into the next beat.
    push_error('RunManager.advance: advancing past an unconsumed draft offer — dropping it')
    _set_offer([])
  if has_open_shop():
    push_error('RunManager.advance: advancing without leaving the shop — closing it')
    _close_shop()
  if not _pending_choice.is_empty():
    push_error('RunManager.advance: advancing past an unpicked choice of encounters — dropping it')
    _pending_choice = []
  _teardown_current()
  if RunMap.crosses_act(position):   # the act boss was just cleared → enter the next act full
    _full_heal()
  position += 1
  _enter_beat(position)
  _save()


## HP-economy: the automatic between-act full restore (design — players enter each act at
## full HP). The in-act partial rest is the REST encounter; max-HP growth comes from relics.
func _full_heal() -> void:
  if player != null:
    player.hp = player.max_hp
  for ally in allies:   # the between-act restore covers the whole run-scoped player side
    ally.hp = ally.max_hp


func is_ended() -> bool:
  return _ended


func outcome() -> int:
  return _outcome


# --- map + run-end ----------------------------------------------------------

## Set up the beat at `pos` (RunMap.beat_spec): a CHOICE beat draws its three encounters and waits
## for pick_path or skip_choice; a FIXED beat (an elite fight, the boss) names its encounter; a DRAWN
## beat (a regular fight) draws a def from its pool on the run RNG (deterministic + resume-stable),
## and that encounter is live at once. Clears any prior beat's transient state.
func _enter_beat(pos: int) -> void:
  _current_def_id = ''
  _current_enemy_ids = []
  _pending_choice = []
  var spec: Dictionary = RunMap.beat_spec(pos)
  if spec['kind'] == RunMap.BeatKind.CHOICE:
    _pending_choice = _draw_choice()
    if not _pending_choice.any(func(id: String) -> bool: return id != ''):
      push_warning('RunManager: no encounter can be offered at beat %d — the choice is skipped' % pos)
      _pending_choice = []
    return
  if spec['kind'] == RunMap.BeatKind.FIXED:
    _current_def_id = spec['id']
  else:
    var pool: Array = spec['pool']
    _current_def_id = pool[rng.randi_range(0, pool.size() - 1)]
  _current_enemy_ids = _draw_enemies(EncounterCatalog.get_def(_current_def_id))
  _create_current_encounter()


func _create_current_encounter() -> void:
  _current = Encounter.new(EncounterCatalog.get_def(_current_def_id), player, _combat_seed_for(position), allies, _current_enemy_ids)


## Draw the enemies for a generated fight (docs/plans/encounter_points_budget.md): add enemies from
## the act's pool on the run RNG until their points reach the beat's target, up to the enemy limit.
## The draw is random and ignores composition — positioning is handled later. A boss is not drawn:
## it takes the act's boss list (EnemyPools.BOSS). Returns empty, leaving the def's authored
## enemy_ids in place, for a non-fight, for a boss with an empty list and for an empty pool.
func _draw_enemies(def: EncounterDef) -> Array[String]:
  if def.type != EncounterDef.Type.FIGHT:
    return []
  if not pinned_enemy_ids.is_empty():
    return pinned_enemy_ids.duplicate()
  if _current_def_id == RunMap.boss_for(RunMap.act_of(position)):
    return EnemyPools.boss(RunMap.act_of(position))
  var target: float = RunMap.target_points(position)
  if def.reward == EncounterDef.Reward.ELITE:
    target *= Balance.POINTS_ELITE_MULTIPLIER
  return RunMap.draw_enemies(RunMap.enemy_pool(RunMap.act_of(position)), target, rng)


## The per-fight RNG seed for beat `pos` (decision #20): derived from the run SEED (a
## constant, saved) + the beat index — NOT the evolving run stream. So combat randomness
## is reproducible, a re-entered fight replays identically (resume isn't save-scummable),
## and deriving it never perturbs the run stream that draft offers draw from.
func _combat_seed_for(pos: int) -> int:
  return rng.seed + (pos + 1) * COMBAT_SEED_STRIDE


func _end_run(outcome_value: int) -> void:
  if _ended:
    return
  _ended = true
  _outcome = outcome_value
  run_ended.emit(outcome_value)


# --- snapshot / rehydrate (the Run manager owns the schema) -----------------

func _save() -> void:
  Save.write(snapshot())


func snapshot() -> Dictionary:
  var board: Array = []
  for item in player.board:
    var enchant_id: Variant = null
    if item.enchant != null:
      enchant_id = item.enchant.def.id
    board.append({ 'id': item.def.id, 'enchant': enchant_id, 'level': item.level })
  var relic_ids: Array = []
  for relic in relics:
    relic_ids.append(relic.def.id)
  var potion_ids: Array = []
  for consumable in potions:
    potion_ids.append(consumable.def.id)
  var ally_snaps: Array = []
  for ally_def_id in _ally_def_ids:
    # Def id only — an ally's HP is NOT saved: allies are revived to full at every fight
    # begin (only the player carries HP attrition), so a saved value would be dead weight.
    ally_snaps.append({ 'id': ally_def_id })
  return {
    'character': character.id,
    'hp': player.hp,
    'max_hp': player.max_hp,
    'board': board,
    'allies': ally_snaps,   # run-scoped allies persist (def id + current HP; board is the def's)
    'relics': relic_ids,
    'potions': potion_ids,
    'position': position,
    'gold': gold,   # banked run-state (decision #33); optional on read (.get) — no migration
    'flags': flags,
    'times_picked': times_picked,
    # The current beat's encounter id (resume re-enters it, never redrawn); '' at a choice beat.
    'current_def_id': _current_def_id,
    'pending_choice': _pending_choice,   # the offered encounters — the RNG has already moved past them
    'current_enemy_ids': _current_enemy_ids,   # the drawn set — the RNG has already moved past it
    # RNG full state as strings — a JSON double can't hold a 64-bit value exactly.
    'rng': { 'seed': str(rng.seed), 'state': str(rng.state) },
  }


# Snapshot keys a save must carry to be usable. Save already discards corrupt / wrong-
# version files; this catches a parsable save with a broken SHAPE (truncated, hand-edited)
# so resume discards to fresh instead of crashing (the no-migration rule, docs/systems/save.md).
const SNAPSHOT_KEYS: Array = [
  'hp', 'max_hp', 'board', 'relics', 'potions', 'position', 'current_def_id', 'rng',
]


## Rebuild run-state from a snapshot and re-enter the saved beat (the resume point).
## Does not re-save (this is a load, not an encounter entry). Returns false — building
## nothing — when the snapshot is shape-incompatible; the Game manager then discards it.
func rehydrate(snap: Dictionary) -> bool:
  if not _snapshot_usable(snap):
    return false
  character = CharacterCatalog.get_def(snap.get('character', CharacterCatalog.DEFAULT))
  player = character.make_actor()
  player.max_hp = roundi(float(snap['max_hp']))
  player.hp = roundi(float(snap['hp']))
  player.board.clear()
  for entry in snap['board']:
    var item := Item.new(ItemCatalog.get_def(str(entry['id'])), player)
    item.level = int(entry.get('level', 1))
    if entry['enchant'] != null:
      item.enchant = Enchantment.new(EnchantCatalog.get_def(str(entry['enchant'])))
    player.board.append(item)
  allies = []
  _ally_def_ids = []
  for entry in snap.get('allies', []):
    add_ally(str(entry['id']))
  relics = []
  for relic_id in snap['relics']:
    relics.append(Relic.new(RelicCatalog.get_def(str(relic_id))))
  potions = []
  for potion_id in snap['potions']:
    potions.append(Consumable.new(ConsumableCatalog.get_def(str(potion_id))))
  position = int(snap['position'])
  gold = int(snap.get('gold', 0))   # absent in pre-gold snapshots → 0 (forward-compatible, no migration)
  # JSON reads every number back as a float, so the counts are made whole again.
  flags = {}
  var saved_flags: Dictionary = snap.get('flags', {})
  for flag_name: Variant in saved_flags:
    flags[str(flag_name)] = int(saved_flags[flag_name])
  times_picked = {}
  var saved_picks: Dictionary = snap.get('times_picked', {})
  for encounter_id: Variant in saved_picks:
    times_picked[str(encounter_id)] = int(saved_picks[encounter_id])
  rng = RandomNumberGenerator.new()
  rng.seed = int(snap['rng']['seed'])
  rng.state = int(snap['rng']['state'])
  _ended = false
  _set_offer([])
  _close_shop()
  # Restore the current beat exactly — the offered encounters or the encounter — never redraw it
  # (no save-scum).
  _pending_choice = []
  for id: Variant in snap.get('pending_choice', []):
    _pending_choice.append(str(id))
  _current_def_id = str(snap['current_def_id'])
  _current_enemy_ids = []
  for enemy_id: Variant in snap.get('current_enemy_ids', []):
    _current_enemy_ids.append(str(enemy_id))
  if _pending_choice.is_empty():
    _create_current_encounter()
  return true


## Shape check for a parsed snapshot: every required key present, the RNG pair intact, and a
## resolved current beat — an encounter, or at a choice beat the offered encounters (every save
## happens after _enter_beat sets one).
func _snapshot_usable(snap: Dictionary) -> bool:
  for key in SNAPSHOT_KEYS:
    if not snap.has(key):
      return false
  var rng_snap: Variant = snap['rng']
  if not (rng_snap is Dictionary and rng_snap.has('seed') and rng_snap.has('state')):
    return false
  return str(snap['current_def_id']) != '' or not (snap.get('pending_choice', []) as Array).is_empty()


# --- teardown ---------------------------------------------------------------

## Dev and test only: move the run to beat `pos` and enter it, without playing the beats before it.
func jump_to(pos: int) -> void:
  _teardown_current()
  position = pos
  _enter_beat(pos)


func _teardown_current() -> void:
  if _current != null:
    _current.teardown()
    _current.free()
    _current = null


## End the run cleanly (idempotent). The player is run-lifetime, so this is where
## its Actor<->Item cycle is finally broken (dissolve) — never at fight end, where
## its board must survive. Called by Game on the next start / resume / reset.
func teardown() -> void:
  if _torn_down:
    return
  _torn_down = true
  _teardown_current()
  if player != null:
    player.dissolve()
    player = null
  for ally in allies:   # run-scoped allies are run-lifetime too — break their cycle at run end
    ally.dissolve()
  allies.clear()
  _ally_def_ids.clear()
  relics.clear()
  potions.clear()
  flags.clear()
  times_picked.clear()
  _set_offer([])
  _close_shop()
  _pending_choice.clear()
