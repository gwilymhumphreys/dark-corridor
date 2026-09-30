# Plan: the page turn into a run

**Status: built 2026-09-30.** As-built detail is in [`../systems/page_turn.md`](../systems/page_turn.md). Differences from the plan are listed at the end.

When a run starts, the menu's right half turns over like a book page on the centre fold and lands on
the left half. The run screen is on the next two pages: its right half is under the turning page, and
its left half is printed on the back of the page. When the page lands flat, the run screen is showing
and the effect is removed. The menus also show the same folds as the run screen, so the fold the page
turns on is visible before it turns.

## What the code does now

- Folds are drawn by the background wear shader (`print_wear.gdshaderinc`, `folds()` and
  `nearest_fold()`). They are hidden on the title screen and its menus: `ScreenBackground.folds_shown`
  is only set on the run screen, and the shared material's `folds_shown` uniform follows it.
- With follow layout on, the run screen's folds sit at the split point (`split_across`, `split_down`
  in the print settings), worked out from `print_corridor_rect`, which `PrintFrame` sets while a
  combat view exists. On a screen with no corridor the folds are spaced evenly instead, so on the
  title screen the side-to-side fold would be at mid-height, not at the split point.
- `MainController._swap()` frees the title screen and adds the run screen in the same frame, with no
  transition. Start goes through the character select overlay on the title screen; Resume goes
  straight to `Game.resume_run()`. Both end in the phase change to RUN.
- The canvas is 2560x1440 with the `canvas_items` stretch mode, on the Compatibility renderer. Screen
  reading shaders already work there (`corridor_overlay.gdshader`, `paper_burn.gdshader`).
- The drawn mouse cursor is on the canvas layer above the debug panels, so a capture of the screen
  includes it unless it is hidden for that frame.

## Research

The common ways to draw a turning page, and why this plan uses the last one:

| Approach | Result |
|---|---|
| Squash the page's width by the cosine of its angle, with no perspective | Reads as a flat card flip. The page never lifts towards the player. |
| The classic page curl shader: the page wraps round a cylinder at a fold line that moves across the sheet | Good for peeling a corner. The fold line moves, so it does not turn on a fixed fold. |
| A subdivided 3D plane bent in a vertex shader, in a SubViewport over the interface | Real perspective and lighting, but a SubViewport cannot read the screen underneath it, so the back of the page cannot show the live run screen. |
| One full-screen 2D shader that finds, for each screen pixel, the point of the page seen there (ray casting against the page) | Perspective, bending, lighting, shadows and a live back face in one shader. Chosen. |

The ray casting stays cheap because the page bends only across its width: every line parallel to the
fold stays straight. The page is then a curve seen from above, and each screen column meets that
curve at a few points at most. For each pixel the shader walks the curve (64 short segments, worked
out once a frame on the CPU and passed in as a uniform array), finds where the column meets it, and
keeps the point closest to the camera. That handles the page overlapping itself when it curls, and
tells the front of the page from the back.

What makes a page turn look real, from reference footage of book pages turning:

- **The page bends.** A hand lifts the outer edge first, so the edge leads and the page curves up.
  Past upright, air holds the edge back, so the edge trails and the page curves the other way before
  it lies flat. A stiff page turning in one piece looks like a card.
- **The page keeps its length.** Building the curve from its angles, segment by segment, keeps the
  page the same length whatever the bend, so the paper never stretches.
- **Perspective.** The page grows as it rises towards the camera and is largest when upright.
- **Light across the bend.** The side facing the light brightens and the side turned away darkens,
  with a faint highlight along the tightest part of the bend.
- **Shadow.** The page throws a soft shadow on the pages it is over: onto the run screen's right
  half as it lifts, and onto the menu's left half before it lands. The shadow is sharp and dark near
  the paper and wide and faint when the page is high.
- **Timing.** It starts slowly as the page is lifted, is fastest through upright, and settles at the
  end. A short hold before it starts lets the eye take in the fold.

## The effect

**Location:** `src/ui/page_turn.gd` (class `PageTurn`), `src/ui/page_turn.tscn` (a `CanvasLayer` over
everything except the debug panels and the cursor, holding one full-screen `ColorRect`),
`src/shaders/page_turn.gdshader`.

### What each pixel shows

The shader samples two images: the captured menu (`menu_texture`) and the screen as drawn under the
effect, which is the live run screen (`hint_screen_texture`).

| Where the pixel is | Shows |
|---|---|
| On the front of the page | The menu's right half |
| On the back of the page | The run screen's left half, at the place it will sit once the page lands, so the corridor moves on the back of the page while it turns |
| Left half, not under the page | The menu's left half, darkened by the page's shadow |
| Right half, not under the page | Transparent, so the run screen shows through, darkened by the page's shadow |

At the start the page is flat and every pixel matches the captured menu, and at the end every pixel
matches the run screen, so neither end jumps.

### The page's shape

- The hinge is the side-to-side position of the fold that runs top to bottom. The page is the part of
  the screen right of it. On the default layout that is the centre of the screen, so the page covers
  the left half exactly when it lands. If the fold is moved off centre, the part of the left side the
  page does not reach is covered by the run screen as the page lands.
- `PageTurn` works out the curve each frame from the progress: the angle at the hinge goes from flat
  on the right to flat on the left, and the angle at the free edge leads it in the first half and
  trails it in the second. The bend along the page follows a power of the distance from the hinge.
- The camera sits above the fold, at a set distance chosen so the flat page fills the screen exactly;
  a shorter distance gives stronger perspective.

### Settings

The settings are shader uniforms in their own uniform group, shown as a Page turn section on the F7
Tokens tab, saved in presets with the print part of the look.

| Setting | Does |
|---|---|
| Duration | Time from the page lifting to lying flat, after the hold |
| Hold | Time the menu stays still, with the fold showing, before the page lifts |
| Easing | How slowly the turn starts and ends |
| Lead and trail | How far the free edge leads the hinge in the first half and trails it in the second |
| Bend | How the bend spreads along the page, from all at the edge to even along the page |
| Camera distance | Strength of the perspective |
| Light direction | Where the light comes from, for the shading and the shadow's direction |
| Shading | How much the light darkens the side turned away; a flat page is never shaded |
| Highlight | The faint highlight along the tightest part of the bend |
| Back print show-through | How much of the menu shows faintly through the back of the page, like thin paper; off by default |
| Shadow darkness and softness | The shadow under the page |
| Edge line | A thin light line along the free edge, the paper's edge catching the light |

## The folds on the menus

- The title screen, the character select screen and the settings screen opened from the title set
  `folds_shown`, so every screen shows the folds.
- With follow layout on, the folds sit at the split point on every screen. `PrintLook` sets a new
  `fold_point` uniform on the background material from `split_across` and `split_down`, turned into
  window pixels, whenever the split point changes, and `nearest_fold()` places the last fold there.
  This replaces working it out from `print_corridor_rect`, which gives the same place on the run
  screen. The corridor overlay gets the same uniform, since `PrintFrame` copies the background
  settings onto it.
- `folds_shown` and the `fold_backgrounds` count in `PrintLook` become unused and are removed.

## Starting the turn

`MainController` runs it when the phase changes from TITLE to RUN, which covers both Start and Resume:

1. Hide the cursor, wait for the frame to finish drawing, read the screen into an image, and show the
   cursor again. The menu is still on screen, so the capture is exactly what the player was looking
   at, including the pressed character card.
2. Show `PageTurn` with the capture, flat, then swap in the run screen underneath it.
3. Wait until the run screen has drawn and frames are coming at an even rate, with a cap on the wait,
   so shader compiling on the run screen's first frames does not stutter the turn.
4. Play the hold and the turn on its own clock, then free `PageTurn`.

The run starts normally underneath: the approach walk begins at once and is seen on the back of the
page. Pausing does not pause the turn. The turn is skipped when the game runs headless (autotest and
GUT) and when a start-up argument skips the title screen.

A page turn sound plays as the page lifts. Sounds are found with the `sfx` skill as a batch in the
folder they play from, for the owner to delete the ones not wanted.

## Tuning it

- A dev argument `--page-turn-at=<progress>` freezes the turn at that progress, for screenshots of
  the page mid-turn.
- A Replay button in the Page turn section captures the current screen and turns it over onto
  itself, so the motion can be tuned without starting new runs.
- The default values are picked from screenshots at several points of the turn and from watching it
  at full speed, before the owner sees it.

## Tests

- `PageTurn` works out the page curve with the right length and hinge at the start, the middle and
  the end, and ends flat on the left.
- The shader's two ends: a pixel test is not practical headless, so the check at progress 0 and 1 is
  done by screenshot comparison with the menu and the run screen.
- `MainController` swaps straight to the run screen when headless, as now.

## Docs to update when built

- New `docs/systems/page_turn.md`, catalogued in `docs/index.md`.
- `background_wear.md`: folds on every screen, placed at the split point.
- `run_screen.md`: the transition from the title into a run.
- `print_frame.md` and `debug_panel.md`: the Page turn section on the Tokens tab.
- `dev_tools.md`: `--page-turn-at`.

## Questions for the owner

- Should Resume turn the page too, or only a new run?
- Should returning to the title (Quit to menu, New Run after an outcome) turn the page back, left
  onto right? The shader supports it by running the progress backwards with the images swapped.

## Differences from the plan

- Resume and the outcome screen turn the page too, and returning to the title screen turns it back
  (the owner's answers to the two questions above).
- `PageTurn` is an autoload, so the run screen can capture itself before it tears down its combat view.
- The camera sits off the hinge towards the side the page lands on (`page_turn_camera_offset`); with
  it over the hinge, the upright page was seen edge-on and vanished.
- The fold position is worked out by `ScreenSections.fold_point_on_screen`, not `PrintLook`, which
  would have made the two scripts depend on each other.
- The sound is `page_34` from the paper pool, copied to `ui/page_turn`.
- Added after the first build at the owner's request: the page twists as if pulled from its bottom
  corner (`page_turn_corner`). The top and bottom edges each have a curve and the shader blends them
  per row, searching again for the row until perspective settles it.
- Measured on the development machine, the page starts turning about half a second after the click:
  about a quarter of a second to build the run screen under the still image, then one long frame while
  its shaders compile. The engine is blocked for most of it, so the hold before the turn defaults to 0.
