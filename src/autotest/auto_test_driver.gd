class_name AutoTestDriver
extends RefCounted
## The decision source for headless play (autotest.md) — the seam that emits the same
## input-intents the UI does, so the harness "plays" the few human choices while
## combat auto-resolves. The driver does NOT play fights; it makes the draft / potion
## decisions.
##
## Phase 5: real, SEEDED draft strategies, so `--strategy` is live and the harness can
## play *different builds* (the `tune` "build viability" lever). A strategy scores each
## candidate against the current board and the driver takes the best (ties → lowest
## index, for determinism). `random` draws from a seeded RNG so runs reproduce.

var strategy: String = 'first-viable'

var _rng: RandomNumberGenerator
var _threw_potion: bool = false


func _init(strategy_name: String = 'first-viable', seed_value: int = 0) -> void:
  strategy = strategy_name
  _rng = RandomNumberGenerator.new()
  _rng.seed = seed_value


## 1-of-N reward draft. Scores each candidate by the strategy + the current board and
## returns the best index. No skip exists, so a pick always resolves (docs/systems/draft.md).
func choose_draft(candidates: Array, board: Array = []) -> int:
  if candidates.is_empty():
    return -1
  match strategy:
    'random':
      return _rng.randi_range(0, candidates.size() - 1)
    'greedy-synergy':
      return _best_by(candidates, func(d): return _synergy_score(d, board))
    'first-viable':
      return 0
    _:
      # Family strategies: 'damage' / 'block' / 'poison' / 'heal' (+ aliases). Prefer a
      # candidate whose primary effect family matches; fall back to index 0 on a tie.
      var family: String = _strategy_family(strategy)
      return _best_by(candidates, func(d): return 1.0 if _family_of(d) == family else 0.0)


## Argmax over candidates by `score` (a Callable def -> float); ties keep the lowest
## index (deterministic). Returns 0 when nothing outscores the first.
func _best_by(candidates: Array, score: Callable) -> int:
  var best_index: int = 0
  var best: float = score.call(candidates[0])
  for i in range(1, candidates.size()):
    var s: float = score.call(candidates[i])
    if s > best:
      best = s
      best_index = i
  return best_index


## The effect family of an item def (its primary effect) — mirrors the colour
## vocabulary (design): damage / block / poison / heal / status / other.
func _family_of(def: ItemDef) -> String:
  if def.effects.is_empty():
    return 'other'
  var effect: ItemEffect = def.effects[0]
  match effect.kind:
    Delivery.Kind.DAMAGE:
      return 'damage'
    Delivery.Kind.HEAL:
      return 'heal'
    Delivery.Kind.APPLY_STATUS:
      match effect.status_id:
        'block':
          return 'block'
        'poison':
          return 'poison'
        _:
          return 'status'
  return 'other'


## Map a strategy name to the family it targets. `scaling` / `burn` alias to the
## nearest family present in the prototype pool until their own content exists
## (docs/history/phase5_plan.md: the deferred raw-damage/scaling + burn content).
func _strategy_family(strat: String) -> String:
  match strat:
    'scaling':
      return 'damage'
    'burn':
      return 'poison'
    _:
      return strat


## Synergy score for `greedy-synergy`: how well `def` connects to the current board. A
## connection is a trigger on one side keyed off a status the other side applies.
func _synergy_score(def: ItemDef, board: Array) -> float:
  var score: float = 0.0
  # (a) def triggers off a status the board already applies. An OPPONENT_SIDE
  # subscription can't be fed by the own board, so it scores no connection.
  for sub in def.trigger_subs:
    if _sub_listens_to_own_side(sub) and _board_applies_status(board, sub.get('filter', '')):
      score += 1.0
  # (b) a board item triggers off a status def applies.
  var applied: String = _status_applied_by(def)
  if applied != '':
    for item in board:
      for sub in item.def.trigger_subs:
        if _sub_listens_to_own_side(sub) and sub.get('filter', '') == applied:
          score += 1.0
  return score


func _sub_listens_to_own_side(sub: Dictionary) -> bool:
  var source_filter: int = sub.get('source_filter', EventBus.SourceFilter.OWN_SIDE)
  return source_filter != EventBus.SourceFilter.OPPONENT_SIDE


func _board_applies_status(board: Array, status_id: String) -> bool:
  if status_id == '':
    return false
  for item in board:
    if _status_applied_by(item.def) == status_id:
      return true
  return false


func _status_applied_by(def: ItemDef) -> String:
  for effect in def.effects:
    if effect.kind == Delivery.Kind.APPLY_STATUS:
      return effect.status_id
  return ''


## The binary choice inside a non-combat event (the tier-2 pick). Seeded so a run takes a
## deterministic option (different seeds explore both). Real value-aware policies (heal at
## low HP, growth when safe) arrive with richer run state.
func choose_event_option(options: Array) -> int:
  if options.is_empty():
    return -1
  return _rng.randi_range(0, options.size() - 1)


## Which choice-layer path to take at a fork (fight / elite / event). A seeded pick so a
## run explores a deterministic path (different seeds take different routes). Real
## category-aware policies (prefer elites for reward, avoid risk at low HP) arrive with
## telegraphs + richer run state.
func choose_path(candidates: Array) -> int:
  if candidates.is_empty():
    return -1
  return _rng.randi_range(0, candidates.size() - 1)


## Whether to throw a reserve consumable now. Minimal policy: throw the first available
## potion once (so the throw path is exercised in a run), then conserve. Real
## "when/which" policies arrive with richer combat state.
func should_throw_potion(_run_state: Variant = null) -> bool:
  if _threw_potion:
    return false
  _threw_potion = true
  return true
