class_name LookActorsFocus
extends RefCounted
## The actor a look-dev camera follows (W3-D; sandbox `--focus=`): the Warden (default), the first living enemy of a kind, or the
## first deployed turret. `resolve` gives where it stands, which way it faces and how tall it is, so the close-up and the
## low perspective cameras of `look_dev_sandbox.gd` can frame any actor like they frame the Warden. Debug only.

var kind: String = "warden"

var _enemy_id: int = 0


## World position of the actor's middle (x, middle height, z), its yaw (the rotation about Y of its root) and its height.
class Pose:
	extends RefCounted
	var at: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var height: float = 1.9


func resolve(layer: ActorLayer, sim: SimWorld) -> Pose:
	var p: Pose = Pose.new()
	if kind == "turret":
		for t: TurretView in layer.turrets:
			if t.is_deployed():
				p.at = t.position + Vector3(0.0, 0.5, 0.0)
				p.yaw = t.upper_yaw()
				p.height = 1.0
				return p
	var pool: EnemyPool = layer.enemy_pool()
	var index: int = Ids.enemy_index(StringName(kind))
	if index >= 0 and pool != null:
		if not pool.by_id.has(_enemy_id) or (pool.by_id[_enemy_id] as EnemyActor).kind != index:
			_enemy_id = _find(pool, sim, index)
		if pool.by_id.has(_enemy_id):
			var actor: EnemyActor = pool.by_id[_enemy_id]
			var def: EnemyDef = Content.db.enemies[index]
			p.at = actor.world_position() + Vector3(0.0, def.visual_height_m * 0.5, 0.0)
			p.yaw = actor.yaw
			p.height = def.visual_height_m
			return p
	var warden: WardenView = layer.warden
	p.at = warden.position + Vector3(0.0, 0.95, 0.0)
	p.yaw = warden.upper_yaw()
	return p


## Hides every pooled enemy except the focused one (the solo view of an enemy).
func hide_others(layer: ActorLayer) -> void:
	var pool: EnemyPool = layer.enemy_pool()
	if pool == null or Ids.enemy_index(StringName(kind)) < 0 or not pool.by_id.has(_enemy_id):
		return
	var keep: EnemyActor = pool.by_id[_enemy_id]
	for node: Node in layer.get_children():
		var root: Node3D = node as Node3D
		if root != null and root.get_child_count() == 1 and root.get_child(0) is MeshInstance3D and String(root.name).contains("_"):
			root.visible = root == keep.root


func is_enemy() -> bool:
	return Ids.enemy_index(StringName(kind)) >= 0


func _find(pool: EnemyPool, sim: SimWorld, index: int) -> int:
	var st: EnemyStore = sim.enemies
	for i: int in st.high_water:
		if st.alive[i] == 1 and st.type[i] == index and pool.by_id.has(st.id[i]):
			return st.id[i]
	return 0
