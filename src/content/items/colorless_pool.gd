class_name ColorlessPool
## The shared "colorless" item pool (decision #27 refinement): items available to EVERY
## character, appended to the character's own pool at draft time. Deliberately SMALL — the
## exception that earns it, never a default tier characters lean on (that would re-create the
## rejected colorless-layer hybrid). Empty by default; the owner adds an id here only when an
## item genuinely belongs to all characters.

const ITEMS: Array = []
