class_name TimedStatus
extends StatusEffect
## Intermediate base for duration-timer statuses (Weak / Vulnerable / Blind) — the old
## StatusDef.Shape.TIMED. Owns a duration Ticker built from the APPLICATION's duration (not a
## global), counts down each step, and STACKS on reapply by extending the timer. Concrete timed
## statuses extend this and override only their modifier hook.


func setup(amount: float, dur: float, src, applied_flags: int) -> void:
  super(amount, dur, src, applied_flags)
  ticker = Ticker.from_seconds(dur)


## Expired the step the duration Ticker crosses.
func on_step(target, ctx) -> bool:
  return ticker.step()


## STACK (the ratified default): a re-application extends the remaining time by the incoming
## duration — `accum` (elapsed) is untouched, the threshold grows — and adds count. Override for
## refresh-to-new or max. NOTE: nothing reads a timed status's `count` yet — the built timed
## statuses (Weak / Vulnerable / Blind) use flat Balance magnitudes; per-stack scaling is the
## owner's content call, so the counter accrues quietly until then.
func reapply(add_count: float, add_duration: float, src, new_flags: int) -> void:
  super(add_count, add_duration, src, new_flags)
  duration += add_duration
  ticker.threshold += Ticker.from_seconds(add_duration).threshold
