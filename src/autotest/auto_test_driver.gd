class_name AutoTestDriver
extends RefCounted
## The decision source for headless play (autotest.md) — the seam that emits the
## same input-intents the UI does, so the harness "plays" the few human choices
## while combat auto-resolves.
##
## Phase 2 is a STUB. A single headless fight has no draft / choice / event /
## potion decisions to make, so nothing here is exercised yet — combat is fully
## automatic. The methods fix the interface (and a default "first-viable, never
## throw" policy) so the run loop (Phase 3) can plug in real, seeded strategies
## (`poison`, `block`, `greedy-synergy`, …) without reshaping the seam.

var strategy: String = 'first-viable'


func _init(strategy_name: String = 'first-viable') -> void:
  strategy = strategy_name


## 1-of-N reward draft. Stub: take the first candidate (no skip exists, so taking
## one is always correct — draft_prd). Real strategies weigh the candidates.
func choose_draft(candidates: Array) -> int:
  return 0 if not candidates.is_empty() else -1


## Binary choice inside a non-combat event. Stub: the first option.
func choose_event_option(options: Array) -> int:
  return 0 if not options.is_empty() else -1


## Which choice-layer path to take at a fork (fight / elite / event / rest).
## Stub: the first offered.
func choose_path(candidates: Array) -> int:
  return 0 if not candidates.is_empty() else -1


## Whether to throw a reserve consumable now. Minimal policy: throw the first
## available potion once (so the throw path is exercised in a run), then conserve.
## Real "when/which" policies arrive with the decision AI.
var _threw_potion: bool = false


func should_throw_potion(_run_state: Variant = null) -> bool:
  if _threw_potion:
    return false
  _threw_potion = true
  return true
