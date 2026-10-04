# Page turn

The change between the menus and a run, and between the title screen and character select, drawn as a book page turning over on the fold. Going into a
run, the right side of the screen turns over onto the left; going back to the title screen, the left
side turns over onto the right. The screen being left is on the front of the page, and the new screen
is on its back and under it.

**Location:** `src/autoloads/page_turn.gd` (class `PageTurnAutoload`, registered as the `PageTurn`
autoload from `src/scenes/ui/page_turn.tscn`), `src/shaders/page_turn.gdshader`. Started by
`MainController` (`src/scenes/main_controller.gd`), by the title screen for character select and, for
Quit to menu, by the run screen. The
sound is the `ui/page_turn` folder.

## When it plays

| From | To | Turn |
|---|---|---|
| Title screen (Start) | Character select | Forward |
| Character select (Back) | Title screen | Back |
| Character select (a pick), title screen (Resume) | Run | Forward |
| Outcome screen (New Run) | Run | Forward |
| Run (Quit to menu) | Title screen | Back |
| Outcome screen (Title) | Title screen | Back |
| Run | Outcome screen | None |

`MainController._turn_direction` holds the turns between phases. Character select is part of the title
screen's phase, so `TitleScreen.open_select` and `_close_select` play its two turns themselves. No turn plays when the game runs headless
(`PageTurn.can_turn()`, so the GUT suite and the autotest swap screens at once) or when the screen
being left was never drawn, as when a start-up argument skips the title screen.

## How it works

1. `PageTurn.capture()` hides the cursor and the debug panels, waits for a frame to be drawn, reads it
   into an image and shows them again. Clicks are blocked from here to the end of the turn.
   `MainController` captures on the phase change, while the old screen is still in the tree. The run
   screen captures before it tears down its combat view and before `Game.return_to_title()`, with the
   pause menu hidden, so its page shows the fight rather than an empty screen. Exit Game does not
   capture.
2. `MainController` swaps the screens and calls `PageTurn.play(direction)`. The page shows the image
   flat at once, so the new screen is never seen before the turn.
3. The page waits until the new screen draws a few frames in a row at an even rate (`STEADY_FRAMES`,
   `STEADY_FRAME_TIME`, capped by `MAX_WAIT`), so the first frames of the new screen, which compile
   shaders, do not stutter the turn. It then waits `page_turn_hold` seconds and plays the page turn
   sound as the page lifts.
4. Each frame `page_curve()` works out the page's shape, and the shader draws it. At the end the layer
   hides and `finished` is emitted.

The new screen runs normally under the page: a run's corridor walk has already started and is seen
moving on the back of the page.

### The page's shape

The hinge is the fold down the middle of the screen ([background_wear.md](background_wear.md)), so the
page is the half of the screen it starts on and exactly covers the other half when it lands.

`page_curve()` describes an edge of the page seen from the side: points from the hinge to the free
edge, built piece by piece from each piece's angle so the page never stretches. The angle at the hinge
goes from flat to flat on the other side, eased at both ends. The free edge's angle leads the hinge in
the first half, like a hand lifting the edge, and trails it in the second, like air holding it back.

The page's top and bottom edges each get a curve. The bottom edge leads further through the whole
turn (`page_turn_corner`), so the page twists as if pulled from its bottom corner: that corner lifts
first and lands first. Every row between the edges is a blend of the two curves.

### The shader

For each pixel the shader guesses which row of the page it shows, walks that row's curve for the
points whose perspective projection lands on the pixel's column, and keeps the one nearest the camera.
Perspective moves the row, so it corrects the row from the point found and searches again, up to
`ROW_PASSES` times, until the row settles. The camera is above the screen,
offset from the hinge towards the side the page lands on, so the page is not seen edge-on when it
stands upright.

| Where the pixel is | Shows |
|---|---|
| Front of the page | The captured image, at the page point's place before the turn |
| Back of the page | The new screen, read live from the screen texture, at the place the page point lands |
| Landing side, not under the page | The captured image, in the page's shadow |
| Starting side, not under the page | The new screen, in the page's shadow |

The page is shaded by its angle to the light, with a faint highlight on the bend and a light line
along its free edge. The shadow is the page projected along the light onto the screen, softer where the
page is higher. The shadow and the edge line fade in and out with how far the page is lifted, so a
flat page at either end matches the screen exactly.

## Settings

The `page_turn_*` print settings (`PrintLook.PRINT_SETTING_DEFAULTS`), on the Page turn section of
the Tokens tab (F7, [debug_panel.md](debug_panel.md)), saved with the print part of a
[preset](look_presets.md). They are read when a turn starts; the timing settings are read each frame.

| Setting | Does |
|---|---|
| Duration, hold | The turn's length, and the pause between the new screen drawing evenly and the page lifting |
| Easing | How slow the turn is at both ends (1 is even speed) |
| Lead, bend | How far in radians the free edge leads and trails the hinge, and how that bend spreads along the page |
| Corner | How much further in radians the bottom edge leads, most at the middle of the turn; negative pulls the top corner instead |
| Camera distance, camera offset | The camera's height in screen heights (lower is stronger perspective), and its distance from the hinge in page widths |
| Light across, light down | The light's direction; across is mirrored for a turn back |
| Shading, highlight | How much the light darkens the side turned away from it, and the highlight on the bend |
| Show through | How much of the front shows faintly on the back |
| Shadow darkness, shadow softness | The shadow under the page |
| Edge width | The light line along the free edge, in interface pixels |

The section's Replay button captures the current screen and turns it over onto itself, to try the
settings. `--page-turn-at=P` starts a run from the title screen and stops the turn at progress P, for
screenshots ([dev_tools.md](dev_tools.md)).

## Public API

| Member | Use |
|---|---|
| `capture()` | Take the image of the screen for the next turn (a coroutine, one frame) |
| `play(direction)` | Turn from the captured image onto the screen drawn under it |
| `has_capture()`, `can_turn()` | Whether an image is waiting; whether turns can play at all |
| `is_turning()` | Whether a turn is being captured or plays, the time clicks are blocked; code that reads keys checks it |
| `replay()` | Capture and turn the current screen onto itself |
| `page_curve(progress, length, corner)` | An edge of the page seen from the side at `progress`, leading further by `corner` |
| `held_progress` | Stop every turn at this progress (below 0 turns normally) |
| `finished` | Emitted when a turn ends |

Tests: `tests/ui/test_page_turn.gd`.
