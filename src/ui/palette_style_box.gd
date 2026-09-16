class_name PaletteStyleBox
extends StyleBoxFlat
## A flat fill that follows a named `Colours` variable (docs/systems/interface_palette.md), used for
## the theme's flat panel styles (docs/systems/ui_theme.md) so a panel is drawn in the interface's
## background colour and stays in step when a palette changes.
##
## `InterfacePalette` sets `bg_color` straight from the named `Colours` variable when a palette is
## applied and restores it on reset, instead of mapping it through the panel brightness ramp it uses
## for the remaining pack art. The `bg_color` saved on the resource is only the default value; nothing
## in this script reads `Colours` itself, so a theme that embeds this stylebox loads safely before
## autoloads and the global class cache are ready (the same trap `WornStyleBox` avoids).

## The `Colours` variable to fill from, for example 'UI_BACKGROUND'.
@export var colour_name: String = 'UI_BACKGROUND'
