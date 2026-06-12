class_name EventBus
extends RefCounted
## The per-fight trigger pub/sub (docs/systems/combat_manager.md). Items subscribe their
## declared trigger conditions (an event -> a Ticker push); emitted events push
## the subscribed Tickers. A push only adds to the accumulator — it is evaluated
## on the NEXT step's advance, so a chain advances at most one link per step
## (loop-proof by construction; docs/systems/combat_model.md's Bazaar lesson).

enum Event { ITEM_FIRED, DAMAGE_DEALT, STATUS_APPLIED, HEALED }

# Event -> Array[{ ticker: Ticker, amount: float, filter: Variant, subscriber: Item|null }]
var _subs: Dictionary = {}


## Subscribe a Ticker to an event. `filter` (non-null) restricts the push to events whose `data`
## matches — e.g. STATUS_APPLIED filtered to the 'poison' status id, so "on poison applied"
## doesn't fire on block. `data`/`filter` are Variant (the status id is a String now, #23).
## `subscriber` (the owning Item, when there is one) lets a push respect the item's gate.
func subscribe(event: int, ticker: Ticker, amount: float, filter = null, subscriber: Item = null) -> void:
  if not _subs.has(event):
    _subs[event] = []
  _subs[event].append({ 'ticker': ticker, 'amount': amount, 'filter': filter, 'subscriber': subscriber })


func publish(event: int, data = null) -> void:
  if not _subs.has(event):
    return
  for sub in _subs[event]:
    var filter = sub['filter']
    if filter != null and filter != data:
      continue
    # A gated item's Ticker is FROZEN — trigger pushes are dropped too (decision #30:
    # silence deletes the item's time; nothing banks toward a burst).
    var subscriber: Item = sub['subscriber']
    if subscriber != null and subscriber.is_gated():
      continue
    var ticker: Ticker = sub['ticker']
    ticker.push(sub['amount'])
