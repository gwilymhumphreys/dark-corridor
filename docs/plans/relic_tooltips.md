# Relic tooltips

Hovering a relic shows the same tooltip as an item: a main panel with the relic's name and what it
does, and a keyword card beside it for any status it names. This applies to the relic tokens on the
character sheet and the relic choices on the reward panel. Today a relic on the sheet shows nothing,
and a relic choice shows only its name in Godot's plain tooltip.

## What the player sees

| Part | Content |
|---|---|
| Name | The relic's name, tinted by rarity like an item's |
| Type line | "Relic" |
| Charge line | Not shown (relics have no charge time) |
| Effect line | Depends on the relic's kind, below |
| Keyword cards | The status a relic applies (Stone Ward: Shield). None for a max HP relic |

Proposed effect lines (the wording is the owner's call):

| Kind | Line | Example |
|---|---|---|
| Status at the start of each fight | "Start of each fight:" then the status icon and amount, like a basic apply | Stone Ward: "Start of each fight: [shield] 10" |
| Max HP on pick-up | "+N max HP" | Vital Charm: "+20 max HP" |

## Code

- `TooltipContent.build_relic(relic: RelicDef) -> Dictionary`: the same dictionary shape as
  `build(item)`, with an empty `charge_line` and `flavor`.
- `TooltipPanel._set_charge` hides the charge row when the line is empty.
- `TooltipCluster.update_target` accepts a target with `relic` in place of `item`. It keeps the
  current target as one `RefCounted` (Item or RelicDef) to decide when to rebuild.
- `CombatViewFramed.inspectable_at` also hit-tests the relic tokens and returns
  `{relic, rect, side}`. `_set_hovered_cell` gives the hovered relic token the hover border, like an
  item.
- `DraftOverlay.inspectable_at` returns `{relic, rect, side}` for a relic option;
  `RewardOption.setup_relic` stops setting `tooltip_text`.
- Tests: the builder for both relic kinds, the framed view's hit test on a relic token, and the
  reward panel returning a relic target.
- Docs: `tooltips.md` (scope, data flow), `run_screen.md` (the relics box), `lexicon.md` if a new
  term is needed (none expected).
