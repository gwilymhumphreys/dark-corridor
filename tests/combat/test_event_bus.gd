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


func test_push_to_gated_subscriber_is_dropped() -> void:
  # Decision #30: a gated item's Ticker is frozen — trigger pushes are dropped too,
  # so nothing banks toward a burst while silenced.
  var bus := EventBus.new()
  var holder := Actor.new(10.0)
  var item := Item.new(ItemCatalog.get_def(ItemCatalog.WEAPON), holder)
  bus.subscribe(EventBus.Event.STATUS_APPLIED, item.cooldown, 1.0, null, item)
  var silence: StatusEffect = StatusManager.apply(item, 'silence', 1.0)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  assert_eq(item.cooldown.accum, 0.0, 'a push to a gated subscriber is dropped')
  item.statuses.erase(silence)
  bus.publish(EventBus.Event.STATUS_APPLIED)
  assert_gt(item.cooldown.accum, 0.0, 'pushes resume once the gate lifts')
  holder.dissolve()
