class_name AutoTestStuckDetector
extends RefCounted
## Guards the design's "a mutual engine that never resolves" failure mode
## (autotest.md). A fight is stuck if the combined HP of every actor doesn't
## change for `threshold_steps` consecutive sim-steps — i.e. nothing is making
## progress toward a win/loss (both sides only blocking, a damage-less stall).
## Fed one total-HP reading per sim-step by AutoTestMode; returns true the step
## the stall crosses the threshold. A fight whose HP merely oscillates (damage +
## heal) keeps changing total HP, so it never trips this — the game-timeout
## catches that case instead.

const EPSILON: float = 0.0001

var _threshold_steps: int
var _last_total_hp: float = 0.0
var _flat_steps: int = 0
var _primed: bool = false


func _init(threshold_steps: int) -> void:
  _threshold_steps = maxi(threshold_steps, 1)


## Record this step's total HP across all actors; returns true once the total has
## been flat for `threshold_steps` steps running. The first reading only seeds the
## baseline (no step has elapsed against it yet).
func note(total_hp: float) -> bool:
  if not _primed:
    _last_total_hp = total_hp
    _primed = true
    return false
  if absf(total_hp - _last_total_hp) > EPSILON:
    _last_total_hp = total_hp
    _flat_steps = 0
    return false
  _flat_steps += 1
  return _flat_steps >= _threshold_steps


## Steps the current stall has lasted (for the failure summary). 0 when progress
## is being made.
func flat_steps() -> int:
  return _flat_steps
