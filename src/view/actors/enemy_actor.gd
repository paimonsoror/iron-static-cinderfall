class_name EnemyActor
extends RefCounted
## One pooled enemy view: a Node3D root (ground position and yaw) holding ONE MeshInstance3D (merged mesh, at most
## 3 surfaces) that carries the procedural pose. Hit flash swaps `material_override` for a few frames (ARCH 8).

const FLASH_FRAMES: int = 3
const YAW_RATE: float = 14.0

var kind: int = 0
var enemy_id: int = 0
var active: bool = false
var dying: bool = false
var root: Node3D
var mesh: MeshInstance3D
var gait_t: float = 0.0
var yaw: float = 0.0
var shadow_radius: float = 0.6
var hit_height: float = 0.5  ## height of a hit point above the feet
var bar_height: float = 1.0  ## height of the world health bar above the feet

var _flash_left: int = 0
var _last_step: int = 0
var _fresh: bool = true
var _dying_t: float = 0.0


func setup(parent: Node3D, kind_index: int, mesh_res: ArrayMesh, node_name: String) -> void:
	kind = kind_index
	root = Node3D.new()
	root.name = node_name
	root.visible = false
	mesh = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = mesh_res
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	parent.add_child(root)


## Takes the actor out of the pool at (x, z) facing `face_yaw`.
func acquire(new_id: int, x: float, z: float, face_yaw: float) -> void:
	enemy_id = new_id
	active = true
	dying = false
	_fresh = true
	yaw = face_yaw
	gait_t = float(new_id % 97) * 0.37
	_last_step = ActorMotion.step_index(kind, gait_t)
	_flash_left = 0
	_dying_t = 0.0
	mesh.material_override = null
	mesh.transform = Transform3D.IDENTITY
	root.position = Vector3(x, 0.0, z)
	root.rotation.y = yaw
	root.visible = true


func release() -> void:
	enemy_id = 0
	active = false
	dying = false
	_flash_left = 0
	mesh.material_override = null
	root.visible = false


## Starts the hit flash (the flash material is shown for FLASH_FRAMES updates).
func flash() -> void:
	_flash_left = FLASH_FRAMES


func is_flashing() -> bool:
	return mesh.material_override != null


## High Contrast: brighter optic, rim lit plates and frame, as surface overrides (ActorContrast). Off clears them.
func set_contrast(on: bool) -> void:
	var m: ArrayMesh = mesh.mesh as ArrayMesh
	for s: int in m.get_surface_count():
		var variant: Material = null
		if on:
			variant = ActorContrast.variant_of(m.surface_get_material(s))
		mesh.set_surface_override_material(s, variant)


func world_position() -> Vector3:
	return root.position


## Interpolated position (px, pz), facing vector (fx, fz) and gait `mode` (ActorMotion.Mode). `animate` false keeps
## the previous mesh pose (LOW tier). Returns true when a heavy footfall happened this frame (Siege Hulk walking).
func update(delta: float, px: float, pz: float, fx: float, fz: float, mode: int, animate: bool = true) -> bool:
	root.position = Vector3(px, 0.0, pz)
	if fx != 0.0 or fz != 0.0:
		var target: float = atan2(-fx, -fz)
		if _fresh:
			yaw = target
		else:
			yaw = lerp_angle(yaw, target, 1.0 - exp(-YAW_RATE * delta))
		_fresh = false
	root.rotation.y = yaw
	gait_t += delta
	var step: int = ActorMotion.step_index(kind, gait_t)
	var stepped: bool = false
	if step != _last_step:
		_last_step = step
		stepped = mode == ActorMotion.Mode.MOVE
	if animate:
		mesh.transform = ActorMotion.pose(kind, gait_t, mode)
	_apply_flash()
	return stepped


## Advances the collapse after death; returns true when it is over and the actor can be released.
func update_dying(delta: float) -> bool:
	_dying_t += delta
	mesh.transform = ActorMotion.dying_pose(_dying_t / ActorMotion.HULK_COLLAPSE_S)
	_flash_left = 0
	_apply_flash()
	return _dying_t >= ActorMotion.HULK_COLLAPSE_S


func begin_dying() -> void:
	dying = true
	_dying_t = 0.0


## 0..1 progress of the collapse.
func dying_progress() -> float:
	return clampf(_dying_t / ActorMotion.HULK_COLLAPSE_S, 0.0, 1.0)


func _apply_flash() -> void:
	if _flash_left > 0:
		_flash_left -= 1
		if mesh.material_override == null:
			mesh.material_override = MatLib.mat(&"flash_white")
	elif mesh.material_override != null:
		mesh.material_override = null
