# Shaders and palettes

A lookup table of every part of the screen: which shader draws it, where its colours come from,
which palette it is snapped to, and which debug panel tab sets it. Each system doc linked below has
the detail; this page only says which one to read.

## The three palette choices

| Palette | What it does | Set in |
|---|---|---|
| **Interface palette** | Sets the colours things are filled with: panels, text, HP bars, and the mechanic colours that effects, value pills and status swatches use. Nothing is snapped to it. | F2 ([interface_palette.md](interface_palette.md)) |
| **Portrait palette** | The colours interface pictures are snapped to, with optional dithering: off, the interface palette, the world palette, or a palette file. With no preset it is the interface palette; the default preset sets it to the world palette. | F2 ([interface_palette.md](interface_palette.md#images)) |
| **Effects palette** | The colours the combat effects are snapped to when they take the interface look: off, the portrait palette, the interface palette (default), or a palette file. | F2 ([interface_look.md](interface_look.md#the-combat-effects)) |
| **World palette** | The colours the corridor image is snapped to, with optional dithering. Off with no preset; the default preset sets `2bit-demichrome`. | F1 ([palette_clamp.md](palette_clamp.md)) |

The corridor has its own dithering switch; the interface pictures and the combat effects share one.

## Each part of the screen

| Part | Shader or material | Colours from | Snapped to | Tab | Doc |
|---|---|---|---|---|---|
| Corridor walls and enemy images | Corridor look (`DebugPanels.world_material`) on the corridor viewport | The art, lit by the corridor light | World palette | F1 | [corridor_look.md](corridor_look.md) |
| A dead enemy's sprite burning | `paper_burn_sprite.gdshader` on the sprite, inside the corridor look | The paper burn's colours, lit by the corridor light | World palette | F7 | [paper_burn.md](paper_burn.md#enemy-sprites) |
| Hit lights in the corridor | Part of the 3D scene, so the corridor look | Mechanic colours | World palette | F1 | [corridor_3d.md](corridors/corridor_3d.md#hit-lights) |
| Wear and worn edge over the corridor, border behind it | `PrintLook.overlay_material`, `border_material` | Interface palette | No | F3, F4 | [print_frame.md](print_frame.md) |
| Screen backgrounds | `PrintLook.background_material` | Interface palette | No | F4 | [background_wear.md](background_wear.md) |
| Panels, item borders, cardboard tokens | `PrintLook.panel_material`, through `WornStyleBox` in the theme; also draws the control feedback | Interface palette | No | F3, F5, F7 | [panel_wear.md](panel_wear.md), [control_feedback.md](control_feedback.md) |
| Pencil grid behind the boards | `PrintLook.grid_material` | Interface palette | No | F3, F7 | [print_frame.md](print_frame.md) |
| Item and potion icons, map icons when drawn as pictures | Interface look, `framed_material` | The art | Portrait palette | F2 | [interface_look.md](interface_look.md) |
| Character portraits (player, allies, enemy panels, character select) | Interface look, `portrait_material` | The art | Portrait palette | F2 | [interface_look.md](interface_look.md) |
| Status icons, keyword icons from art, the mouse cursor | Interface look, `material`, with picture wear | The art | Portrait palette | F2 | [interface_look.md](interface_look.md) |
| HP bars, value pills, the Temporary tag on item cells, icon slot glyphs, map icons when not drawn as pictures | Interface look, `element_material` | Interface palette | No | F2 | [interface_look.md](interface_look.md) |
| Cooldown fill on item cells | `cooldown_fill.gdshader`, one material per cell | `Colours.COOLDOWN_FILL`, which is translucent, so no palette file sets it | No | none | [run_screen.md](run_screen.md) |
| Ordinary text | None; the interface palette recolours the theme's font colours | Interface palette | No | F2 | [interface_palette.md](interface_palette.md) |
| Projectiles, impacts, damage numbers | Interface look, `effects_material`; off in the shader, turned on by the default preset (transparency dithering on, numbers drawn with the effects) | Mechanic colours from the interface palette | Effects palette | F2 Effects section; F5 has the switches for each trial effect | [interface_look.md](interface_look.md#the-combat-effects), [vfx_driver.md](vfx_driver.md) |
| Glow on a node | Godot's 2D glow, switched on by `InterfaceGlow` | The node's own colour | No | F2 | [interface_glow.md](interface_glow.md) |
| Page turn and paper burn | `page_turn.gdshader`, `paper_burn.gdshader`, only while they play | The screen underneath; the paper burn's bands from the interface palette, set to its Burn colour and its darkest colour | The paper burn's bands take the effects palette when `paper_burn_palette` is on; the page turn is not snapped | F7 | [page_turn.md](page_turn.md), [paper_burn.md](paper_burn.md) |

## The interface look materials

The five interface look materials run the same shader with the same F2 settings. They differ in which
effects are kept off and which palette they are snapped to:

| Material | Picture wear | Grade, colour ramp, posterize | Palette snapping |
|---|---|---|---|
| `material` | Yes | Yes | Yes |
| `framed_material` | No, the frame draws panel wear | Yes | Yes |
| `portrait_material` | No, the frame draws panel wear | Yes | Yes |
| `element_material` | Yes | No, they would move the fill colour | No |
| `effects_material` | No | No, they would move the mechanic colour | Yes, to the effects palette; patterns are laid out on the screen |

The rule for a new element: a picture from art takes `framed_material` inside a frame and `material`
outside one; anything filled with an interface palette colour takes `element_material`; a combat effect
is drawn by `VfxDriver` and takes `effects_material` from `VfxWall`. The full
list of nodes is in [interface_look.md](interface_look.md) and its test.
