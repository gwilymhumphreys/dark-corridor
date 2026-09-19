# Interface glow

A way to make a specific interface node glow, for code that has a reason to highlight something (for
example an item that just triggered). Nothing glows unless code asks for it.

**Location:** `InterfaceGlow` (`src/autoloads/interface_glow.gd`, class `InterfaceGlowAutoload`), the
`rendering/viewport/hdr_2d` project setting, and the glow step in `interface_look.gdshader`.

## How it works

- 2D HDR is on, so a node's colour can be brighter than white. A node glows while its `self_modulate` is
  above white, for example `Color(3, 3, 3)`.
- `InterfaceGlow` adds a `WorldEnvironment` with a canvas background and Godot's glow. Only pixels brighter
  than white glow, so text and nodes at normal brightness never do.
- The glow follows the bright, opaque pixels of the node. Icons and portraits have transparent
  backgrounds, so they glow along their shape; a solid `ColorRect` such as an HP bar fill glows as a
  rectangle.
- The screen glow is switched on only while a node set through `set_glow` or `flash` is glowing, because
  the glow pass darkens the whole screen slightly even when nothing is brighter than white. Setting
  `self_modulate` directly does not switch it on. A glowing node that is freed stops counting on the
  next frame, including one freed partway through a flash.
- Canvas layers up to `MAX_GLOW_LAYER` glow; the debug panels are above it.
- Nodes drawn through the [interface look](interface_look.md) material keep their extra brightness: the
  shader runs its effects on the colour up to white and multiplies the extra back in at the end.
- A node that is bright in its own right loses detail at high brightness, and text drawn over it can
  become hard to read. Keep the brightness low or use a short flash.

## Settings

Intensity, strength, threshold and blend mode, with defaults in `DEFAULTS`. They are saved in a
[preset's](look_presets.md) `interface_glow` section. The Interface tab's Glow section was removed on
2026-09-18, so they are changed in code (`InterfaceGlow.settings` then `apply_settings()`) or by
editing a preset file.

## Public API

| Member | Use |
|---|---|
| `InterfaceGlow.set_glow(item, brightness)` | Hold `item` at `brightness`; 1.0 is no glow |
| `InterfaceGlow.flash(item, brightness, duration)` | Brighten and fade back over `duration` seconds; replaces a flash already running on `item` |
| `InterfaceGlow.is_enabled() -> bool` | Whether the screen glow is on |
| `InterfaceGlow.settings`, `setting(property)`, `apply_settings()`, `reset()` | Glow settings |

`--glow-demo=<brightness>` makes every node drawn through a picture material glow, for
screenshots.

Tests: `tests/debug/test_interface_glow.gd`.
