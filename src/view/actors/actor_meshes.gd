class_name ActorMeshes
extends RefCounted
## Single entry point for the procedural actor meshes (WORK_PLAN 6). Every mesh is built once and cached; an
## authored asset replaces a placeholder by changing the function that returns it (`enemy`, `warden_*`, `turret*`).
## Budgets (the hard-surface looks; CURRENT meshes are far below them): skitter 450, hollow warden 500, rusher 500,
## hulk 1500 (W3-D raised them from 300, 400, 400 and 900), warden 2500 (every body part plus the weapon in hand; W3-C
## raised it from 700 to 2000 because the Warden is a single instance, and to 2500 in v3 for the smooth rounded silhouette),
## turret 600 (base plus head; was 300) triangles, each mesh at most 3 surfaces. The CURRENT look of every actor is unchanged
## (the hash-pinned baseline of `look_dev_meshes_test.gd`); the styled meshes are cached under separate keys.

const TRI_BUDGET: Dictionary[StringName, int] = {
	&"skitter": 450,
	&"hollow_warden": 500,
	&"rusher": 500,
	&"siege_hulk": 1500,
	&"warden": 2500,
	&"turret": 600,
}
const MAX_SURFACES: int = 3
## The body parts of the Warden (one MeshInstance3D each) and the weapons.
const WARDEN_BODY_PARTS: Array[StringName] = [
	&"legs", &"torso", &"arm_ru", &"arm_rf", &"arm_lu", &"arm_lf", &"pack", &"antenna", &"cable"
]
const WARDEN_WEAPONS: Array[StringName] = [&"pistol", &"smg"]

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


## The merged mesh of an enemy in a look (`LookDevStyle.Look`; W3-D). CURRENT, or a rollout that is switched off, gives the old
## mesh (`enemy`); the hard-surface looks share one geometry per enemy, cached under its own key.
static func enemy_look(enemy_id: StringName, look: int) -> ArrayMesh:
	if not LookActorsStyle.enabled(look):
		return enemy(enemy_id)
	match enemy_id:
		&"hollow_warden":
			return _cached(&"styled_hollow_warden", LookActorsHollow.build)
		&"rusher":
			return _cached(&"styled_rusher", LookActorsRusher.build)
		&"siege_hulk":
			return _cached(&"styled_siege_hulk", LookActorsHulk.build)
	return _cached(&"styled_skitter", LookActorsSkitter.build)


## The turret's static `base` or yawing `head` in a look (W3-D); the old meshes for CURRENT.
static func turret_part(part: StringName, look: int) -> ArrayMesh:
	if not LookActorsStyle.enabled(look):
		return turret_base() if part == &"base" else turret_head()
	if part == &"base":
		return _cached(&"styled_turret_base", LookActorsTurret.base)
	return _cached(&"styled_turret_head", LookActorsTurret.head)


static func warden_legs() -> ArrayMesh:
	return _cached(&"warden_legs", HeroMeshes.warden_legs)


static func warden_torso() -> ArrayMesh:
	return _cached(&"warden_torso", HeroMeshes.warden_torso)


static func pistol() -> ArrayMesh:
	return _cached(&"pistol", HeroMeshes.pistol)


static func smg() -> ArrayMesh:
	return _cached(&"smg", HeroMeshes.smg)


## One body part or weapon of the Warden in a look (`LookDevStyle.Look`). CURRENT has only legs, torso, pistol and smg
## (the old meshes); the hard-surface looks share one geometry for STYLISED and STYLISED_PLUS. Null when the look has
## no such part.
static func warden_part(part: StringName, look: int) -> ArrayMesh:
	if look == LookDevStyle.Look.CURRENT:
		match part:
			&"legs":
				return warden_legs()
			&"torso":
				return warden_torso()
			&"pistol":
				return pistol()
			&"smg":
				return smg()
		return null
	var key: StringName = StringName("styled_" + String(part))
	match part:
		&"legs":
			return _cached(key, LookDevWarden.legs)
		&"torso":
			return _cached(key, LookDevWarden.torso)
		&"arm_ru":
			return _cached(key, LookDevGear.arm_upper.bind(1.0))
		&"arm_rf":
			return _cached(key, LookDevGear.arm_fore.bind(1.0))
		&"arm_lu":
			return _cached(key, LookDevGear.arm_upper.bind(-1.0))
		&"arm_lf":
			return _cached(key, LookDevGear.arm_fore.bind(-1.0))
		&"pack":
			return _cached(key, LookDevGear.pack)
		&"antenna":
			return _cached(key, LookDevGear.antenna)
		&"cable":
			return _cached(key, LookDevGear.cable)
		&"pistol":
			return _cached(key, LookDevGear.pistol)
		&"smg":
			return _cached(key, LookDevGear.smg)
	return null


## Triangles of the Warden as drawn in a look with the weapon `weapon` (0 pistol, 1 smg): every body part plus the gun.
static func warden_triangles(look: int, weapon: int) -> int:
	var n: int = 0
	for part: StringName in WARDEN_BODY_PARTS:
		var m: ArrayMesh = warden_part(part, look)
		if m != null:
			n += triangle_count(m)
	var gun: ArrayMesh = warden_part(WARDEN_WEAPONS[clampi(weapon, 0, 1)], look)
	return n + triangle_count(gun)


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
