class_name CameraFitResult
extends RefCounted
## Output of CameraFit.solve: how to place the orthographic camera.

var ortho_size: float  ## Camera3D.size (KEEP_HEIGHT: vertical extent in meters)
var position: Vector3
var basis: Basis
var px_per_meter: float
