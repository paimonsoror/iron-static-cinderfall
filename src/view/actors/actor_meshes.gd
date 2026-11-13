class_name ActorMeshes
extends RefCounted
## Single entry point for the procedural actor meshes (WORK_PLAN 6). Every mesh is built once and cached; an
## authored asset replaces a placeholder by changing the function that returns it (`enemy`, `warden_*`, `turret*`).
## Budgets (the hard-surface looks; CURRENT meshes are far below them): skitter 450 (hold50 shows 30 of them), hollow warden 500, rusher 500,
## hulk 1500 (W3-D raised them from 300, 400, 400 and 900), warden 2500 (every body part plus the weapon in hand; W3-C
## raised it from 700 to 2000 because the Warden is a single instance, and to 2500 in v3 for the smooth rounded silhouette),
## turret 600 (base plus head; was 300) triangles, each mesh at most 3 surfaces. The CURRENT look of every actor is unchanged
## (the hash-pinned baseline of `look_dev_meshes_test.gd`); the styled meshes are cached under separate keys.
## V2-F (variety milestone): burster 400, mote 40 (a 40 instance MultiMesh), the arc projector 350 and the crate 200. The Warden's
## 2,500 still holds for the pistol and the SMG; with a 350 triangle weapon in hand the loadout budget is `WARDEN_LOADOUT_BUDGET`
## (body 2,300 plus a weapon, VARIETY_SPEC 12.2).
## V4-R: spitter, borer and jammer 400, splitter, shieldbearer and reclaimer 500, shard 40, ward_pylon 150, every weapon 350 and the
## four new bosses 1,500 each (the Hulk's budget: one boss is alive at a time and each is one pooled node, so the cost is bounded by
## the Hulk's; the spec's 900 was the Hulk's budget before W3-D). The new enemies and bosses have ONE geometry for every look: they
## wear the flat palette in CURRENT and the look's materials in the hard-surface looks, like the new weapons.

const TRI_BUDGET: Dictionary[StringName, int] = {
	&"skitter": 450,
	&"hollow_warden": 500,
	&"rusher": 500,
	&"siege_hulk": 1500,
	&"warden": 2500,
	&"turret": 600,
	&"burster": 400,
	&"mote": 40,
	&"arc_projector": 350,
	&"crate": 200,
	&"spitter": 400,
	&"borer": 400,
	&"jammer": 400,
	&"splitter": 500,
	&"shieldbearer": 500,
	&"reclaimer": 500,
	&"shard": 40,
	&"ward_pylon": 150,
	&"brood_carrier": 1500,
	&"lance_platform": 1500,
	&"aegis_array": 1500,
	&"tremor_rig": 1500,
	&"scattergun": 350,
	&"assault_rifle": 350,
	&"hornet_rack": 350,
	&"lmg": 350,
	&"slag_mortar": 350,
	&"cutting_torch": 350,
	&"rail_lance": 350,
}
const WARDEN_LOADOUT_BUDGET: int = 2650
const MAX_SURFACES: int = 3
## The body parts of the Warden (one MeshInstance3D each) and the weapons.
const WARDEN_BODY_PARTS: Array[StringName] = [
	&"legs", &"torso", &"arm_ru", &"arm_rf", &"arm_lu", &"arm_lf", &"pack", &"antenna", &"cable"
]
const WARDEN_WEAPONS: Array[StringName] = [&"pistol", &"smg"]
## The weapons added by the variety milestone (V2-F: the arc projector; V4-R: the other seven). They have one model for every
## look. `WARDEN_WEAPON_NODES` names the Warden's three weapon MOUNTS (`WeaponMeshes.model_index`): the pistol, the SMG and a third,
## named for the arc projector, that shows the mesh of every other weapon (a weapon change swaps its mesh and its muzzle marker). The
## mount names are pinned by `look_dev_view_test` (the exact set of the Warden's mesh instances), so there is no node per weapon.
const NEW_WEAPONS: Array[StringName] = [
	&"scattergun", &"assault_rifle", &"hornet_rack", &"lmg", &"slag_mortar", &"cutting_torch", &"arc_projector", &"rail_lance",
]
const WARDEN_WEAPON_NODES: Array[StringName] = [&"pistol", &"smg", &"arc_projector"]
## The enemies and bosses V4-R models (one geometry for every look), by `Ids.ENEMIES` id.
const ROSTER: Array[StringName] = [
	&"spitter", &"splitter", &"shard", &"shieldbearer", &"reclaimer", &"jammer", &"borer", &"ward_pylon", &"brood_carrier",
	&"lance_platform", &"aegis_array", &"tremor_rig",
]

static var _cache: Dictionary[StringName, ArrayMesh] = {}


## The merged mesh of an enemy by id (`Ids.ENEMIES`). Unknown ids give the skitter so nothing is invisible.
static func enemy(enemy_id: StringName) -> ArrayMesh:
	var roster: Callable = roster_builder(enemy_id)
	if roster.is_valid():
		return _cached(enemy_id, roster)
	match enemy_id:
		&"hollow_warden":
			return _cached(enemy_id, EnemyMeshes.hollow_warden)
		&"rusher":
			return _cached(enemy_id, EnemyMeshes.rusher)
		&"siege_hulk":
			return _cached(enemy_id, EnemyMeshes.siege_hulk)
		&"burster":
			return _cached(enemy_id, EnemyMeshes2.burster)
		&"mote":
			return _cached(enemy_id, EnemyMeshes2.mote)
	return _cached(&"skitter", EnemyMeshes.skitter)


## The merged mesh of an enemy in a look (`LookDevStyle.Look`; W3-D). CURRENT, or a rollout that is switched off, gives the old
## mesh (`enemy`); the hard-surface looks share one geometry per enemy, cached under its own key.
static func enemy_look(enemy_id: StringName, look: int) -> ArrayMesh:
	if roster_builder(enemy_id).is_valid():
		return enemy(enemy_id)
	if not LookActorsStyle.enabled(look):
		return enemy(enemy_id)
	match enemy_id:
		&"hollow_warden":
			return _cached(&"styled_hollow_warden", LookActorsHollow.build)
		&"rusher":
			return _cached(&"styled_rusher", LookActorsRusher.build)
		&"siege_hulk":
			return _cached(&"styled_siege_hulk", LookActorsHulk.build)
		&"burster":
			return _cached(&"styled_burster", LookActorsBurster.build)
		&"mote":
			return _cached(&"styled_mote", LookActorsMote.build)
	return _cached(&"styled_skitter", LookActorsSkitter.build)


## The mesh a MiniSwarm draws for the mini type `enemy_id` in a look: the shard for the shard, the mote for the mote and for any mini
## that has no model of its own, so that a swarm is never 40 copies of a 340 triangle crawler.
static func mini_look(enemy_id: StringName, look: int) -> ArrayMesh:
	if enemy_id == &"shard":
		return enemy_look(&"shard", look)
	return enemy_look(&"mote", look)


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
	if NEW_WEAPONS.has(part):
		return new_weapon(part)
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


## One weapon the variety milestone added (`NEW_WEAPONS`), the same model in every look (there is no old look of a new weapon: in
## CURRENT it simply wears the flat palette). Null for any other id.
static func new_weapon(part: StringName) -> ArrayMesh:
	match part:
		&"scattergun":
			return _cached(part, WeaponMeshes2.scattergun)
		&"assault_rifle":
			return _cached(part, WeaponMeshes2.assault_rifle)
		&"hornet_rack":
			return _cached(part, WeaponMeshes2.hornet_rack)
		&"lmg":
			return _cached(part, WeaponMeshes2.lmg)
		&"slag_mortar":
			return _cached(part, WeaponMeshes3.slag_mortar)
		&"cutting_torch":
			return _cached(part, WeaponMeshes3.cutting_torch)
		&"arc_projector":
			return _cached(&"arc_projector", WeaponMeshes.arc_projector)
		&"rail_lance":
			return _cached(part, WeaponMeshes3.rail_lance)
	return null


## The red ring under an elite (a band and four chevrons, radius 1, in the additive red).
static func elite_ring() -> ArrayMesh:
	return _cached(&"elite_ring", VfxMeshes.elite_ring.bind(&"add_red"))


## The salvage crate prop (`CrateView`), the same for every look.
static func crate() -> ArrayMesh:
	return _cached(&"crate", CrateView.mesh)


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


## The builder of one of the V4-R machines (`ROSTER`); an invalid Callable for any other id (the tests time it).
static func roster_builder(enemy_id: StringName) -> Callable:
	match enemy_id:
		&"spitter":
			return LookActorsSpitter.build
		&"splitter":
			return LookActorsSplitter.build
		&"shard":
			return LookActorsShard.build
		&"shieldbearer":
			return LookActorsShieldbearer.build
		&"reclaimer":
			return LookActorsReclaimer.build
		&"jammer":
			return LookActorsJammer.build
		&"borer":
			return LookActorsBorer.build
		&"ward_pylon":
			return LookActorsPylon.build
		&"brood_carrier":
			return LookActorsBrood.build
		&"lance_platform":
			return LookActorsLance.build
		&"aegis_array":
			return LookActorsAegis.build
		&"tremor_rig":
			return LookActorsTremor.build
	return Callable()


static func _cached(key: StringName, builder: Callable) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var built: Variant = builder.call()
	var m: ArrayMesh = built
	_cache[key] = m
	return m


static func _build_shadow() -> ArrayMesh:
	return VfxMeshes.disc(1.0, 14, &"shadow_blob")
