class_name ActorLayer
extends Node3D
## Enemies, Warden, turrets. Wave 0 stub: one box per alive enemy, created and freed as enemies come and go
## (no pooling), interpolated between prev and current positions. TODO(W1-F): pooled actors, Warden, turrets.

var _content: ContentSet
var _sim: SimWorld
var _nodes: Dictionary = {}  ## enemy id -> MeshInstance3D
var _meshes: Array[ArrayMesh] = []


func setup(content: ContentSet) -> void:
	_content = content
	var mats: Array[StringName] = [&"steel_grey", &"ceramic", &"steel_red", &"gunmetal"]
	for def: EnemyDef in content.enemies:
		var h: float = def.visual_height_m
		var w: float = def.radius * 1.6
		var mb: MeshBuilder = MeshKit.begin()
		mb.box(Vector3(w, h, w), Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)), mats[def.index])
		mb.box(Vector3(w * 0.5, h * 0.12, w * 0.3), Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.8, -w * 0.5)), &"emit_red")
		_meshes.append(mb.build())


func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim


func unbind() -> void:
	for n: Variant in _nodes.values():
		var mi: MeshInstance3D = n
		mi.queue_free()
	_nodes.clear()
	_sim = null


func render(alpha: float, _delta: float) -> void:
	if _sim == null:
		return
	var st: EnemyStore = _sim.enemies
	var seen: Dictionary = {}
	for i: int in st.high_water:
		if st.alive[i] == 0:
			continue
		var enemy_id: int = st.id[i]
		seen[enemy_id] = true
		var mi: MeshInstance3D = _node_for(enemy_id, st.type[i])
		var px: float = lerpf(st.prev_x[i], st.x[i], alpha)
		var pz: float = lerpf(st.prev_z[i], st.z[i], alpha)
		mi.position = Vector3(px, 0.0, pz)
		mi.rotation.y = atan2(-st.face_x[i], -st.face_z[i])
	for k: Variant in _nodes.keys():
		var key: int = k
		if not seen.has(key):
			var gone: MeshInstance3D = _nodes[key]
			gone.queue_free()
			_nodes.erase(key)


func set_quality(_tier: int) -> void:
	# TODO(W1-F)
	pass


## World position of a live enemy's feet, or Vector3.INF if unknown.
func enemy_world_position(enemy_id: int) -> Vector3:
	if _nodes.has(enemy_id):
		var mi: MeshInstance3D = _nodes[enemy_id]
		return mi.position
	return Vector3.INF


func _node_for(enemy_id: int, type_index: int) -> MeshInstance3D:
	if _nodes.has(enemy_id):
		var existing: MeshInstance3D = _nodes[enemy_id]
		return existing
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _meshes[type_index]
	add_child(mi)
	_nodes[enemy_id] = mi
	return mi
