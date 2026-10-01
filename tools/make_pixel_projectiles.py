"""Make the pixel projectile sheets in assets/vfx/projectile/pixel/ (docs/systems/vfx_driver.md).

Each sheet holds one looping animation from a pixel-art effects pack in ../3rd party assets. Its
columns are the frames and its rows are brightness bands, darkest first: every pixel of a frame is
put in one band by how bright its colour is among the colours the animation uses, and drawn there
in white with its own transparency. The game draws each band in a shade of the delivery's colour,
so the art keeps its shading in any colour.

Run from the repository root: python tools/make_pixel_projectiles.py
"""
import glob
import os
import re

from PIL import Image

PACKS = os.path.join('..', '3rd party assets')
BEAT = os.path.join(PACKS, "Beat 'em Up Combat Effects – 2D Pixel Art VFX Pack")
BULLETS = os.path.join(PACKS, 'vfx', '500 Bullet 24x24 Free', 'Bullet 24x24 Free Part 1A.png')
OUT = os.path.join('assets', 'vfx', 'projectile', 'pixel')
BANDS = 4
BULLET_SIZE = 24
BULLET_FRAMES = 8

# Output name -> Beat 'em Up pack number ('' for the first pack) and effect number.
BEAT_EFFECTS = {
  'crescent': (' 2', 40),
  'orb': (' 4', 20),
  'crystal': (' 4', 21),
  'fire_swirl': (' 4', 26),
  'blob': (' 4', 15),
}
# Output name -> row and first column of an eight-frame loop in the bullet sheet.
BULLET_EFFECTS = {
  'swirl': (0, 0),
  'twin_hooks': (2, 0),
  'spinning_ring': (1, 16),
}


def beat_frames(pack: str, number: int) -> list:
  pattern = re.compile(r'Effect \(%d\)\s*(\d+)\.png$' % number)
  paths = []
  for path in glob.glob(os.path.join(BEAT + pack, 'PNG', '*.png')):
    match = pattern.search(os.path.basename(path))
    if match:
      paths.append((int(match.group(1)), path))
  return [Image.open(path).convert('RGBA') for _, path in sorted(paths)]


def bullet_frames(row: int, column: int) -> list:
  sheet = Image.open(BULLETS).convert('RGBA')
  frames = []
  for i in range(BULLET_FRAMES):
    x = (column + i) * BULLET_SIZE
    y = row * BULLET_SIZE
    frames.append(sheet.crop((x, y, x + BULLET_SIZE, y + BULLET_SIZE)))
  return frames


# Crop every frame to the box that holds all of them, so the animation stays centred.
def crop_to_union(frames: list) -> list:
  box = None
  for frame in frames:
    b = frame.getbbox()
    if b:
      box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
  return [frame.crop(box) for frame in frames]


def brightness(colour: tuple) -> float:
  return 0.2126 * colour[0] + 0.7152 * colour[1] + 0.0722 * colour[2]


def make_sheet(frames: list) -> Image.Image:
  frames = crop_to_union(frames)
  colours = set()
  for frame in frames:
    colours |= {p[:3] for p in frame.get_flattened_data() if p[3] > 0}
  ranked = sorted(colours, key=brightness)
  last = max(len(ranked) - 1, 1)
  band_of = {c: round(i * (BANDS - 1) / last) for i, c in enumerate(ranked)}
  width, height = frames[0].size
  sheet = Image.new('RGBA', (width * len(frames), height * BANDS), (0, 0, 0, 0))
  for f, frame in enumerate(frames):
    for y in range(height):
      for x in range(width):
        p = frame.getpixel((x, y))
        if p[3] > 0:
          sheet.putpixel((f * width + x, band_of[p[:3]] * height + y), (255, 255, 255, p[3]))
  return sheet


def main() -> None:
  os.makedirs(OUT, exist_ok=True)
  for name, (pack, number) in BEAT_EFFECTS.items():
    frames = beat_frames(pack, number)
    make_sheet(frames).save(os.path.join(OUT, name + '.png'))
    print(name, len(frames), 'frames')
  for name, (row, column) in BULLET_EFFECTS.items():
    make_sheet(bullet_frames(row, column)).save(os.path.join(OUT, name + '.png'))
    print(name, BULLET_FRAMES, 'frames')


main()
