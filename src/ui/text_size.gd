class_name TextSize
## The game's text ladder and the player's text size setting (docs/systems/ui_theme.md).
##
## Seven named sizes. Every label and button in the game takes one of them through its
## `theme_type_variation` instead of carrying a number of its own, so the whole interface can be
## resized from one place. `Body` is the theme's own default size, which is what a Control with no
## variation gets — including a `RichTextLabel`, whose text is always body copy here.
##
## `apply(scale)` writes `base size x scale` into the loaded theme resource, for the default size
## and for every variation. Controls read that resource live, so one call resizes the whole
## interface. The base sizes live here rather than in the `.tres`, so applying a scale twice is
## never cumulative and the authored ladder cannot drift.
##
## Static only. `Prefs` owns the stored scale and calls `apply()` at boot and on every change.
##
## Not covered, deliberately: the combat board's own numbers (`ValuePill`, `ItemIcon`) and the
## damage numbers on the wall. Those are sized to fit a fixed cell or drawn into the corridor
## image, so scaling them with the interface text would overflow the cell or the wall.

## The base size of each rung, smallest first. The names are the second half of a variation name:
## `Medium` is `LabelMedium` on a Label and `ButtonMedium` on a Button.
const SIZES: Dictionary = {
  'Small': 18,
  'Body': 24,
  'Medium': 30,
  'Large': 36,
  'Heading': 44,
  'Title': 64,
  'Display': 96,
}

## The rung that is the theme's default size, so it needs no variation of its own.
const DEFAULT_RUNG: String = 'Body'

## The control types that have a variation per rung, and the theme entry each one's size is written
## to. A type only lists the rungs some scene actually uses; `_variations` builds the names.
const VARIATIONS: Dictionary = {
  'Label': ['Small', 'Medium', 'Large', 'Heading', 'Title', 'Display'],
  'Button': ['Medium', 'Large', 'Heading'],
}

## The player's setting is a multiple of the ladder, clamped to this range.
const MIN_SCALE: float = 0.75
const MAX_SCALE: float = 2.0
const DEFAULT_SCALE: float = 1.0


## Write `base size x scale` into the theme for the default size and every variation. Safe to call
## repeatedly: each size is computed from the constant ladder, never from what the theme holds now.
## A null theme (the resource failed to load) is a no-op rather than an error.
static func apply(theme: Theme, scale: float) -> void:
  if theme == null:
    return
  var factor: float = clampf(scale, MIN_SCALE, MAX_SCALE)
  theme.default_font_size = size_of(DEFAULT_RUNG, factor)
  for type_name: String in VARIATIONS:
    for rung: String in VARIATIONS[type_name]:
      theme.set_font_size('font_size', type_name + rung, size_of(rung, factor))


## One rung's size at `scale`, rounded to a whole pixel and never below 1.
static func size_of(rung: String, scale: float) -> int:
  return maxi(1, roundi(float(SIZES.get(rung, SIZES[DEFAULT_RUNG])) * scale))
