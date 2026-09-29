class_name RunCondition
extends RefCounted
## A yes-or-no question about the run (docs/plans/encounter_choice.md): the base of every condition an
## encounter's `requires` and `weights` are built from. Each kind is one small subclass in this folder
## overriding `holds`, so a new kind of rule is one new file. A condition only reads the run.


## Whether the condition holds for `run` right now.
func holds(_run: RunManager) -> bool:
  return true
