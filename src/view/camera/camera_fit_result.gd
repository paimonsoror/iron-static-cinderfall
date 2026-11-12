class_name CameraFitResult
extends RefCounted
## Output of CameraFit.solve: how to place the battle camera.

var ortho_size: float  ## Camera3D.size (KEEP_HEIGHT: vertical extent in meters); for a perspective fit the size with the same scale at the arena centre
var position: Vector3
var basis: Basis
var px_per_meter: float  ## screen pixels per meter on the ground (at the arena centre for a perspective fit)
var fov_deg: float = 0.0  ## > 0: a perspective camera with this vertical field of view; 0: orthographic
