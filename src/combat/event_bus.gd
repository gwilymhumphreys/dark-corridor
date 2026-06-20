class_name EventBus
extends RefCounted
## The per-fight trigger pub/sub (docs/systems/combat_manager.md). Items subscribe their
## declared trigger conditions (an event -> a Ticker push); emitted events push
## the subscribed Tickers. A push only adds to the accumulator — it is evaluated
## on the NEXT step's advance, so a chain advances at most one link per step
## (loop-proof by construction; docs/systems/combat_model.md's Bazaar lesson).
##
## Every publish carries SOURCE IDENTITY — the acting Actor plus the acting Item where
## one exists — and a subscription filters on the event's data AND on which SIDE the
## source is on. The bus-level default is ANY (the bus is side-blind without a
## resolver); the CONTENT default, applied where trigger_subs are wired
## (CombatManager._register_actor), is OWN_SIDE — "when MY side does X" (decision #30).
## Side is resolved AT EVENT TIME via `side_resolver`, never cached at subscribe time
## (rosters change mid-fight — a summon subscribes before it is inserted into its roster).

enum Event { ITEM_FIRED, DAMAGE_DEALT, STATUS_APPLIED, HEALED, ITEM_DESTROYED }

## Which event sources a subscription listens to, relative to the SUBSCRIBER's side.
enum SourceFilter { OWN_SIDE, ANY, OPPONENT_SIDE }


## One trigger subscription. The strong ref to the subscriber Item is deliberate —
## CombatManager.teardown() drops every subscription via clear().
class Subscription extends RefCounted:
  var event: int = 0
  var ticker: Ticker = null
  var amount: float = 0.0
  var data_filter = null          # Variant: non-null restricts to matching event data
  var source_filter: int = 0      # a SourceFilter value (set by subscribe)
  var subscriber: Item = null     # the owning Item (gate + side checks); null = a bare ticker


## Resolves "is this actor on the player side?" — handed by the CombatManager at start()
## (its _on_player_side). Left unset, side filters can never match (only ANY passes).
var side_resolver: Callable = Callable()

var _subs: Dictionary = {}        # Event -> Array[Subscription], insertion order (#24)
var _listeners: Dictionary = {}   # Event -> Array[Callable] — the observation-only channel


## Subscribe a Ticker to an event. `data_filter` (non-null) restricts the push to events
## whose `data` matches — e.g. STATUS_APPLIED filtered to the 'poison' status id, so "on
## poison applied" doesn't fire on block. `source_filter` scopes by the source's side
## relative to the subscriber. `subscriber` (the owning Item, when there is one) is what
## the gate check and the side check read.
func subscribe(event: int, ticker: Ticker, amount: float, data_filter = null,
    source_filter: int = SourceFilter.ANY, subscriber: Item = null) -> void:
  var sub := Subscription.new()
  sub.event = event
  sub.ticker = ticker
  sub.amount = amount
  sub.data_filter = data_filter
  sub.source_filter = source_filter
  sub.subscriber = subscriber
  if not _subs.has(event):
    _subs[event] = []
  _subs[event].append(sub)


## Remove ALL of an item's subscriptions (a reaped body's items must stop receiving
## pushes; future mid-fight item removal needs the same). Survivor order is preserved.
func unsubscribe(subscriber: Item) -> void:
  for event in _subs:
    var subs: Array = _subs[event]
    for i in range(subs.size() - 1, -1, -1):
      if subs[i].subscriber == subscriber:
        subs.remove_at(i)


## Publish an event with its source identity. Pushes matching subscriptions (data filter
## -> side filter -> gate), then notifies listeners as `(data, source_actor, source_item)`.
func publish(event: int, data = null, source_actor: Actor = null, source_item: Item = null) -> void:
  if _subs.has(event):
    for sub in _subs[event]:
      if sub.data_filter != null and sub.data_filter != data:
        continue
      if not _source_matches(sub, source_actor):
        continue
      # A gated item's Ticker is FROZEN — trigger pushes are dropped too (decision #30:
      # silence deletes the item's time; nothing banks toward a burst).
      if sub.subscriber != null and sub.subscriber.is_gated():
        continue
      sub.ticker.push(sub.amount)
  if _listeners.has(event):
    for listener in _listeners[event]:
      listener.call(data, source_actor, source_item)


## Register an OBSERVATION-ONLY listener (the autotest's exact fire counts). Listeners
## receive `(data, source_actor, source_item)` after the pushes; they observe state,
## they never push a Ticker — the accrual-only trigger model stays intact.
func add_listener(event: int, listener: Callable) -> void:
  if not _listeners.has(event):
    _listeners[event] = []
  _listeners[event].append(listener)


## Drop every subscription + listener and the resolver (CombatManager.teardown calls
## this — it is what releases the bus's strong Subscription -> Item references).
func clear() -> void:
  _subs.clear()
  _listeners.clear()
  side_resolver = Callable()


## Side matching, strict: OWN_SIDE / OPPONENT_SIDE require the WHOLE identity chain —
## a resolver, a subscriber with an owner, and a source actor. Any gap fails the
## filter; only ANY matches a null-identity event.
func _source_matches(sub: Subscription, source_actor: Actor) -> bool:
  if sub.source_filter == SourceFilter.ANY:
    return true
  if not side_resolver.is_valid() or sub.subscriber == null \
      or sub.subscriber.owner == null or source_actor == null:
    return false
  var subscriber_on_player_side: bool = side_resolver.call(sub.subscriber.owner)
  var source_on_player_side: bool = side_resolver.call(source_actor)
  if sub.source_filter == SourceFilter.OWN_SIDE:
    return subscriber_on_player_side == source_on_player_side
  return subscriber_on_player_side != source_on_player_side   # OPPONENT_SIDE
