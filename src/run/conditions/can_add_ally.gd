class_name CanAddAlly
extends RunCondition
## Holds when the player side has a free ally slot (RunManager.can_add_ally).


func holds(run: RunManager) -> bool:
  return run.can_add_ally()
