class_name CombatStatsReadout
extends PanelContainer
## A small live HUD readout (docs/systems/combat_log.md): the player's running Dealt / Taken
## (net) this fight, read from the live CombatLog each frame. Presentation-only — it reads
## logic and writes nothing (the same discipline as the VFX wall).

@onready var _dealt: Label = $Margin/Rows/DealtLabel
@onready var _taken: Label = $Margin/Rows/TakenLabel


## Refresh from the live log. Safe to call every frame while a fight runs.
func update_from(log: CombatLog) -> void:
  if log == null:
    return
  var side: int = CombatLog.Side.PLAYER
  _dealt.text = tr('Dealt {0}').format([int(log.total_damage_dealt.get(side, 0.0))])
  _taken.text = tr('Taken {0}').format([int(log.total_damage_taken.get(side, 0.0))])
