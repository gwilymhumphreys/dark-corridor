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
