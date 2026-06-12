extends GutTest
## Step 1 — the trigger pub/sub. A published event pushes subscribed Tickers;
## the optional filter scopes a subscription (e.g. "on poison applied" only).
## (That a push fires only on the NEXT step is a Combat-manager concern — Step 4.)


func test_publish_pushes_subscribed_ticker() -> void:
  var bus := EventBus.new()
  var cd := Ticker.new(10)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, cd, 1.0)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  assert_true(cd.crossed(), 'a full-bar push via the bus crosses the ticker')


func test_filter_only_pushes_on_match() -> void:
  var bus := EventBus.new()
  var cd := Ticker.new(10)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, cd, 1.0, 7)   # only status type 7
  bus.publish(EventBus.Event.STATUS_APPLIED, 3)
  assert_false(cd.crossed(), 'a non-matching event is ignored by a filtered sub')
  bus.publish(EventBus.Event.STATUS_APPLIED, 7)
  assert_true(cd.crossed(), 'a matching event pushes')


func test_event_with_no_subscribers_is_noop() -> void:
  var bus := EventBus.new()
  var cd := Ticker.new(10)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, cd, 1.0)
  bus.publish(EventBus.Event.ITEM_FIRED)
  assert_false(cd.crossed(), 'an event with no subscribers pushes nothing')


# --- Source identity + side filtering (decision #30) ---

## A resolver stub: exactly one actor counts as the player side.
func _bus_with_sides(player_actor: Actor) -> EventBus:
  var bus := EventBus.new()
  bus.side_resolver = func(actor) -> bool: return actor == player_actor
  return bus


func test_own_side_filter_matches_own_side_only() -> void:
  var player_actor := Actor.new(10.0)
  var enemy_actor := Actor.new(10.0)
  var bus := _bus_with_sides(player_actor)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), player_actor)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, item.cooldown, 0.2, null, EventBus.SourceFilter.OWN_SIDE, item)
  bus.publish(EventBus.Event.STATUS_APPLIED, 'poison', enemy_actor, null)
  assert_eq(item.cooldown.accum, 0.0, "an opponent's event does not push an OWN_SIDE sub")
  bus.publish(EventBus.Event.STATUS_APPLIED, 'poison', player_actor, null)
  assert_gt(item.cooldown.accum, 0.0, 'an own-side event pushes')


func test_opponent_side_filter_is_the_inverse() -> void:
  var player_actor := Actor.new(10.0)
  var enemy_actor := Actor.new(10.0)
  var bus := _bus_with_sides(player_actor)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), player_actor)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, item.cooldown, 0.2, null, EventBus.SourceFilter.OPPONENT_SIDE, item)
  bus.publish(EventBus.Event.STATUS_APPLIED, 'poison', player_actor, null)
  assert_eq(item.cooldown.accum, 0.0, 'an own-side event does not push an OPPONENT_SIDE sub')
  bus.publish(EventBus.Event.STATUS_APPLIED, 'poison', enemy_actor, null)
  assert_gt(item.cooldown.accum, 0.0, "an opponent's event pushes")


func test_null_source_fails_side_filters_but_passes_any() -> void:
  # Strict matching: a side filter needs the whole identity chain; a null-identity
  # event (no source actor) only reaches ANY subscriptions.
  var player_actor := Actor.new(10.0)
  var bus := _bus_with_sides(player_actor)
  var own_side := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), player_actor)
  var any_ticker := Ticker.new(10)
  bus.subscribe(EventBus.Event.DAMAGE_DEALT, own_side.cooldown, 0.2, null, EventBus.SourceFilter.OWN_SIDE, own_side)
  bus.subscribe(EventBus.Event.DAMAGE_DEALT, any_ticker, 1.0)
  bus.publish(EventBus.Event.DAMAGE_DEALT)   # no source identity
  assert_eq(own_side.cooldown.accum, 0.0, 'a null-source event fails the side filter')
  assert_true(any_ticker.crossed(), 'an ANY sub still receives it')


func test_data_and_side_filters_compose() -> void:
  var player_actor := Actor.new(10.0)
  var bus := _bus_with_sides(player_actor)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), player_actor)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, item.cooldown, 0.2, 'poison', EventBus.SourceFilter.OWN_SIDE, item)
  bus.publish(EventBus.Event.STATUS_APPLIED, 'block', player_actor, null)
  assert_eq(item.cooldown.accum, 0.0, 'right side, wrong data — no push')
  bus.publish(EventBus.Event.STATUS_APPLIED, 'poison', player_actor, null)
  assert_gt(item.cooldown.accum, 0.0, 'matching data AND side pushes')


func test_unsubscribe_removes_all_of_an_items_subscriptions() -> void:
  var holder := Actor.new(10.0)
  var bus := EventBus.new()
  var leaving := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), holder)
  var staying := Ticker.new(10)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, leaving.cooldown, 1.0, null, EventBus.SourceFilter.ANY, leaving)
  bus.subscribe(EventBus.Event.DAMAGE_DEALT, leaving.cooldown, 1.0, null, EventBus.SourceFilter.ANY, leaving)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, staying, 1.0)
  bus.unsubscribe(leaving)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  bus.publish(EventBus.Event.DAMAGE_DEALT)
  assert_eq(leaving.cooldown.accum, 0.0, 'every subscription of the removed item is gone')
  assert_true(staying.crossed(), 'other subscriptions survive, in order')


func test_listener_observes_data_and_source_identity() -> void:
  var player_actor := Actor.new(10.0)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), player_actor)
  var bus := EventBus.new()
  var seen: Array = []
  bus.add_listener(EventBus.Event.ITEM_FIRED,
      func(data, source_actor, source_item) -> void:
        seen.append([data, source_actor, source_item]))
  bus.publish(EventBus.Event.ITEM_FIRED, 'weapon', player_actor, item)
  assert_eq(seen.size(), 1, 'the listener observed the publish')
  assert_eq(seen[0][0], 'weapon', 'data passed through')
  assert_eq(seen[0][1], player_actor, 'source actor passed through')
  assert_eq(seen[0][2], item, 'source item passed through')


func test_push_to_gated_subscriber_is_dropped() -> void:
  # Decision #30: a gated item's Ticker is frozen — trigger pushes are dropped too,
  # so nothing banks toward a burst while silenced.
  var bus := EventBus.new()
  var holder := Actor.new(10.0)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), holder)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, item.cooldown, 1.0, null, EventBus.SourceFilter.ANY, item)
  var silence: StatusEffect = StatusManager.apply(item, 'silence', 1.0)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  assert_eq(item.cooldown.accum, 0.0, 'a push to a gated subscriber is dropped')
  item.statuses.erase(silence)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  assert_gt(item.cooldown.accum, 0.0, 'pushes resume once the gate lifts')
  holder.dissolve()
