class_name ActorMeshes
extends RefCounted
## Single entry point for the procedural actor meshes (WORK_PLAN 6). Every mesh is built once and cached; an
## authored asset replaces a placeholder by changing the function that returns it (`enemy`, `warden_*`, `turret*`).
## Budgets: skitter 300, hollow warden 400, rusher 400, hulk 900, warden 700 (legs + torso), turret 300 triangles,
## each at most 3 surfaces.

const TRI_BUDGET: Dictionary[StringName, int] = {
	&"skitter": 300,
	&"hollow_warden": 400,
	&"rusher": 400,
	&"siege_hulk": 900,
	&"warden": 700,
	&"turret": 300,
}
const MAX_SURFACES: int = 3

static var _cache: Dictionary[StringName, ArrayMesh] = {}


## The merged mesh of an enemy by id (`Ids.ENEMIES`). Unknown ids give the skitter so nothing is invisible.
static func enemy(enemy_id: StringName) -> ArrayMesh:
	match enemy_id:
		&"hollow_warden":
			return _cached(enemy_id, EnemyMeshes.hollow_warden)
		&"rusher":
			return _cached(enemy_id, EnemyMeshes.rusher)
		&"siege_hulk":
			return _cached(enemy_id, EnemyMeshes.siege_hulk)
	return _cached(&"skitter", EnemyMeshes.skitter)


static func warden_legs() -> ArrayMesh:
	return _cached(&"warden_legs", HeroMeshes.warden_legs)


static func warden_torso() -> ArrayMesh:
	return _cached(&"warden_torso", HeroMeshes.warden_torso)


static func pistol() -> ArrayMesh:
	return _cached(&"pistol", HeroMeshes.pistol)


static func smg() -> ArrayMesh:
	return _cached(&"smg", HeroMeshes.smg)


static func turret_base() -> ArrayMesh:
	return _cached(&"turret_base", HeroMeshes.turret_base)


static func turret_head() -> ArrayMesh:
	return _cached(&"turret_head", HeroMeshes.turret_head)


## The whole turret in one mesh (base plus head at rest).
static func turret() -> ArrayMesh:
	return _cached(&"turret", HeroMeshes.turret)


## Round blob shadow, radius 1 (scaled per instance), in the shared `shadow_blob` material.
static func shadow_disc() -> ArrayMesh:
	return _cached(&"shadow_disc", _build_shadow)


## Unit quad for health bars in the XZ plane (scaled per instance).
static func bar_quad(mat_id: StringName) -> ArrayMesh:
	var key: StringName = StringName("bar_" + String(mat_id))
	if _cache.has(key):
		return _cache[key]
	var m: ArrayMesh = MeshKit.begin().quad(Vector2.ONE, Transform3D.IDENTITY, mat_id).build()
	_cache[key] = m
	return m


static func triangle_count(mesh: Mesh) -> int:
	return VfxMeshes.triangles(mesh)


## Bounding box of a mesh in its own space.
static func bounds(mesh: Mesh) -> AABB:
	return mesh.get_aabb()


static func _cached(key: StringName, builder: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var built: Variant = builder.call()
	var m: ArrayMesh = built
	_cache[key] = m
	return m


static func _build_shadow() -> ArrayMesh:
	return VfxMeshes.disc(1.0, 14, &"shadow_blob")
