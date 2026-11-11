class_name ObstacleDef
extends RefCounted
## A prop that blocks movement. Boxes rotate by rot_deg with local axes
## world = (lx*cos - lz*sin, lx*sin + lz*cos) (X right, Z down on screen).

enum Shape { CIRCLE, BOX }

var id: StringName
var shape: int
var x: float
var z: float
var radius: float
var size_x: float
var size_z: float
var rot_deg: float
var visual: StringName


## True when (px, pz) is inside the obstacle grown by `inflate` meters.
func contains(px: float, pz: float, inflate: float) -> bool:
	var dx: float = px - x
	var dz: float = pz - z
	if shape == Shape.CIRCLE:
		var r: float = radius + inflate
		return dx * dx + dz * dz <= r * r
	var a: float = deg_to_rad(rot_deg)
	var c: float = cos(a)
	var s: float = sin(a)
	var lx: float = dx * c + dz * s
	var lz: float = -dx * s + dz * c
	return absf(lx) <= size_x * 0.5 + inflate and absf(lz) <= size_z * 0.5 + inflate
