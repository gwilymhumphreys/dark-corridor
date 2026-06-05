class_name Timekeeper
extends RefCounted
## The combat clock — one per fight, owned and driven by the Combat manager
## (timekeeper_prd). Fixed-step: a stepped `sim_time` (logic) + a continuous
## `render_time()` (the VFX wall) + the one speed dial + the `steps_due()`
## cadence (real time x dial -> whole sim-steps, capped, backlog dropped). It is
## passive — it holds no component registry and runs no loop; the Combat manager
## advances components on this clock.

const STEP: float = Balance.STEP
const MAX_STEPS: int = Balance.MAX_STEPS

var sim_time: float = 0.0
var base_scale: float = Balance.TIMESCALE_BASE
var override_scale: float = -1.0   # < 0 = no momentary override active

var _acc: float = 0.0


## The active dial: a momentary override (hover slow-mo) replaces the base while
## set, then returns TO the base — not to x1 (timekeeper_prd; replace-vs-multiply
## stays open, Phase 1 uses replace).
func effective_scale() -> float:
  return override_scale if override_scale >= 0.0 else base_scale


func set_base_scale(scale: float) -> void:
  base_scale = maxf(scale, 0.0)


func set_override(scale: float) -> void:
  override_scale = maxf(scale, 0.0)


func clear_override() -> void:
  override_scale = -1.0


## Real delta x dial -> whole sim-steps to run this frame. Caps at MAX_STEPS and
## drops the backlog on a hang (game-time slips, never spirals). Delta is
## resolved here and nowhere else.
func steps_due(real_delta: float) -> int:
  _acc += real_delta * effective_scale()
  var n: int = 0
  while _acc >= STEP and n < MAX_STEPS:
    _acc -= STEP
    n += 1
  if _acc > STEP:
    _acc = 0.0
  return n


func advance() -> void:
  sim_time += STEP


## Continuous time for the VFX/audio wall — smooth between sim-steps so slow-mo
## glides rather than stuttering. Only discrete events snap to `sim_time`.
func render_time() -> float:
  return sim_time + _acc + Engine.get_physics_interpolation_fraction() * STEP * effective_scale()
