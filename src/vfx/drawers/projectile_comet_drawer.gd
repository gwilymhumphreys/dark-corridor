class_name ProjectileCometDrawer
extends EffectDrawer
## A comet drawn for a delivery in flight (docs/systems/vfx_driver.md): a soft glowing head with a
## tail that trails back along the direction of travel. The tail grows out from the head just after
## launch, so it never reaches back past the firing item. The images are from Kenney's Particle
## Pack, as white shapes tinted with the delivery's colour: `trace_01` for the tail and `star_05` for
## the head's glow (assets/vfx/projectile/), and the round blob (assets/vfx/status/blob.png) for the
## head's solid middle.
##
## TRIAL: one of the looks being tried for projectiles. `VfxDriver.comet_projectiles` switches
## between this and the placeholder disc.

const TAIL: Texture2D = preload('res://assets/vfx/projectile/tail.png')
const GLOW: Texture2D = preload('res://assets/vfx/projectile/glow.png')
const BLOB: Texture2D = preload('res://assets/vfx/status/blob.png')

const TAIL_PEAK: float = 0.652        # how far along the tail image, from its faded end, its brightest point is
const TAIL_LENGTH: float = 110.0      # pixels from the tail's faded end to its bright end
const TAIL_WIDTH: float = 56.0        # pixels across the tail image; its bright line is about a seventh of this
const TAIL_GROW: float = 0.08         # render-time seconds the tail takes to grow to full length after launch
const HEAD_SIZE: float = 14.0         # pixels across the head's solid middle, half the old disc
const GLOW_SIZE: float = 64.0         # pixels across the soft glow image; the visible glow is about a third of this
const GLOW_STRENGTH: float = 0.8      # how strongly the glow shows
const CORE_SIZE: float = 0.5          # the head's paler middle, as a fraction of the head
const BLOB_SOLID: float = 0.5         # the fraction of the blob image's width that is solid; the rest is its soft edge
const CORE_LIFT: float = 0.45         # how much paler than the delivery's colour the head's middle is


## Draw the comet at `point`, its tail trailing behind `direction`. `age` is render-time seconds
## since launch.
func draw_flight(canvas: CanvasItem, delivery: Delivery, point: Vector2, direction: Vector2, age: float) -> void:
  var heading: Vector2 = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
  var length: float = TAIL_LENGTH * clampf(age / TAIL_GROW, 0.0, 1.0)
  canvas.draw_set_transform(point, heading.angle(), Vector2.ONE)
  if length > 0.0:
    # The tail image's brightest point sits on the head; the short faded part beyond it lies under the head's glow.
    var behind: float = length
    var ahead: float = length * (1.0 - TAIL_PEAK) / TAIL_PEAK
    var tail: Rect2 = Rect2(-behind, -TAIL_WIDTH * 0.5, behind + ahead, TAIL_WIDTH)
    # Drawn twice: once is too faint against the dark corridor.
    canvas.draw_texture_rect(TAIL, tail, false, delivery.color)
    canvas.draw_texture_rect(TAIL, tail, false, delivery.color)
  draw_centred(canvas, GLOW, GLOW_SIZE, faded(delivery.color, GLOW_STRENGTH))
  draw_centred(canvas, BLOB, HEAD_SIZE / BLOB_SOLID, delivery.color)
  draw_centred(canvas, BLOB, HEAD_SIZE * CORE_SIZE / BLOB_SOLID, delivery.color.lightened(CORE_LIFT))
  canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func draw_effect(canvas: CanvasItem, delivery: Delivery, point: Vector2, age: float) -> void:
  draw_flight(canvas, delivery, point, Vector2.RIGHT, age)
