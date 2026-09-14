class_name CorridorPieceSource
extends Resource
## Builds the 3D pieces for one section of `Corridor3D` (docs/systems/corridors/corridor_3d.md).
## The corridor code only calls `build_section`, so any source can be swapped in.
##
## Section space: the camera looks down -Z. A section's near edge is at z = 0 and it extends to
## z = -section_length. The corridor is centred on the X and Y axes.

## Length of one section along the corridor, in metres. The OrcPoweredGames kit snaps to a 3m grid.
@export var section_length: float = 3.0
## Inner width and height of the corridor, in metres.
@export var section_width: float = 3.0
@export var section_height: float = 3.0


## A new node holding the pieces for the section at absolute `index`. The caller positions and
## frees it. `index` lets a source vary pieces along the corridor.
func build_section(_index: int) -> Node3D:
  return Node3D.new()
