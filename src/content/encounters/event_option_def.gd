class_name EventOptionDef
extends RefCounted
## One option of an EVENT encounter (docs/systems/encounter.md): a label, the run effects it applies
## when picked, and the conditions it needs. Authored in GDScript (#23). The Run manager applies the
## effects (RunManager.pick_event_option). An option whose conditions do not all hold is not shown.
## Player-facing `label_key` is localized via tr().

var label_key: String = ''              # the option's button text (source English; tr())
var effects: Array[RunEffect] = []      # applied in order when the option is picked
## Shown and pickable only while every one of these holds (RunCondition subclasses, src/run/conditions/).
var requires: Array[RunCondition] = []


## Whether `run` meets every one of this option's conditions.
func is_available(run: RunManager) -> bool:
  return requires.all(func(condition: RunCondition) -> bool: return condition.holds(run))
