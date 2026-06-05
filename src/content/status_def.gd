class_name StatusDef
extends RefCounted
## The per-type status rule + presentation (status_manager_prd). Authored in
## GDScript (decision #23), collected in StatusCatalog. The StatusManager looks
## up the def by `type` to apply / step / resolve. Specific numbers point to
## Balance, not baked here.

enum Type { BLOCK, POISON, WEAK, SILENCE }
enum Shape { PERIODIC, TIMED, POOL, STATIC }
enum Stacking { ADD, REFRESH }

var type: int
var shape: int
var stacking: int = Stacking.ADD
var gates: bool = false        # if true, suppresses the host item's fire (silence)
var color: Color = Color.WHITE
var icon: String = ''
var name_key: String = ''      # source English; displayed via tr() — localizable

# Behaviour params (per-shape; seconds where time-driven).
var tick_interval: float = 0.0   # PERIODIC
var damage_per_tick: float = 0.0 # PERIODIC — per-stack multiplier
var duration: float = 0.0        # TIMED
