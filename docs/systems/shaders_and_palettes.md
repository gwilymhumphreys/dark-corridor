# Shaders and palettes

A lookup table of every part of the screen: which shader draws it, where its colours come from,
which palette it is snapped to, and which debug panel tab sets it. Each system doc linked below has
the detail; this page only says which one to read.

## The two palettes

| Palette | What it does | Set in |
|---|---|---|
| **Main palette** | One palette file, with an optional darker colour added or swapped in. The corridor, the pictures and the combat effects are snapped to it, each with its own switch, and every interface colour takes one of its colours by brightness. | F1 ([interface_palette.md](interface_palette.md)) |
| **Mechanic palette** | The ten mechanic colours, used as they are by value pills, the health bar's shield, keyword glyphs, hit lights and the combat effects. | F1 ([interface_palette.md](interface_palette.md#the-mechanic-palette)) |

The corridor has its own dithering switch; the pictures and the combat effects share one.

## Each part of the screen

| Part | Shader or material | Colours from | Snapped to | Tab | Doc |
|---|---|---|---|---|---|
| Corridor walls and enemy images | Corridor look (`DebugPanels.world_material`) on the corridor viewport | The art, lit by the corridor light | Main palette | F2 | [corridor_look.md](corridor_look.md) |
| A dead enemy's sprite burning | `paper_burn_sprite.gdshader` on the sprite, inside the corridor look | The paper burn's colours, lit by the corridor light | Main palette | F8 | [paper_burn.md](paper_burn.md#enemy-sprites) |
| Hit lights in the corridor | Part of the 3D scene, so the corridor look | Mechanic colours | Main palette | F2 | [corridor_3d.md](corridors/corridor_3d.md#hit-lights) |
| Wear and worn edge over the corridor, border behind it | `PrintLook.overlay_material`, `border_material` | Interface colours | No | F4, F5 | [print_frame.md](print_frame.md) |
| Screen backgrounds | `PrintLook.background_material` | Interface colours | No | F5 | [background_wear.md](background_wear.md) |
| Panels, item borders, cardboard tokens | `PrintLook.panel_material`, through `WornStyleBox` in the theme; also draws the control feedback | Interface colours | No | F4, F6, F8 | [panel_wear.md](panel_wear.md), [control_feedback.md](control_feedback.md) |
| Pencil grid behind the boards | `PrintLook.grid_material` | Interface colours | No | F4, F8 | [print_frame.md](print_frame.md) |
| Item and potion icons, map icons when drawn as pictures | Interface look, `framed_material` | The art | Main palette | F3 | [interface_look.md](interface_look.md) |
| Character portraits (player, allies, enemy panels, character select) | Interface look, `portrait_material` | The art | Main palette | F3 | [interface_look.md](interface_look.md) |
| Status icons, keyword icons from art, the mouse cursor | Interface look, `material`, with picture wear | The art | Main palette | F3 | [interface_look.md](interface_look.md) |
| HP bars, value pills, the Temporary tag on item cells, icon slot glyphs, map icons when not drawn as pictures | Interface look, `element_material` | Interface colours | No | F3 | [interface_look.md](interface_look.md) |
| Cooldown fill on item cells | `cooldown_fill.gdshader`, one material per cell | `Colours.COOLDOWN_FILL`, an interface colour that keeps its alpha | No | F1 | [run_screen.md](run_screen.md) |
| Ordinary text | None; the main palette recolours the theme's font colours | Interface colours | No | F1 | [interface_palette.md](interface_palette.md) |
| Projectiles, impacts, damage numbers | Interface look, `effects_material`; off in the shader, turned on by the default preset (transparency dithering on, numbers drawn with the effects) | Mechanic palette | Main palette and mechanic colours | F3 Effects section; F6 has the switches for each trial effect | [interface_look.md](interface_look.md#the-combat-effects), [vfx_driver.md](vfx_driver.md) |
| Glow on a node | Godot's 2D glow, switched on by `InterfaceGlow` | The node's own colour | No | F3 | [interface_glow.md](interface_glow.md) |
| Page turn and paper burn | `page_turn.gdshader`, `paper_burn.gdshader`, only while they play | The screen underneath; the paper burn's bands from its interface colours | The paper burn's bands take the combat effects' colours when `paper_burn_palette` is on; the page turn is not snapped | F8 | [page_turn.md](page_turn.md), [paper_burn.md](paper_burn.md) |

## The interface look materials

The five interface look materials run the same shader with the same F3 settings. They differ in which
effects are kept off and which palette they are snapped to:

| Material | Picture wear | Grade, colour ramp, posterize | Palette snapping |
|---|---|---|---|
| `material` | Yes | Yes | Yes |
| `framed_material` | No, the frame draws panel wear | Yes | Yes |
| `portrait_material` | No, the frame draws panel wear | Yes | Yes |
| `element_material` | Yes | No, they would move the fill colour | No |
| `effects_material` | No | No, they would move the mechanic colour | Yes, to the main palette and the mechanic colours; patterns are laid out on the screen |

The rule for a new element: a picture from art takes `framed_material` inside a frame and `material`
outside one; anything filled with a palette colour takes `element_material`; a combat effect
is drawn by `VfxDriver` and takes `effects_material` from `VfxWall`. The full
list of nodes is in [interface_look.md](interface_look.md) and its test.
