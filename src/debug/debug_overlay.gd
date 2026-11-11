class_name BattleDebugOverlay
extends Node3D
## Debug layers drawn over the yard (handoff P2 gate "visible debug paths", acceptance A05): the flow field as
## arrows, the 64 attack slots (free or taken), stuck enemies, and the spawn regions. Each layer is ONE node (a
## MultiMeshInstance3D or MeshInstance3D, slots a Node3D with two) created when the layer is switched on and freed when
## it is switched off, so a hidden layer costs nothing. Read only on the sim. `--debug-overlay[=all|flow,slots,stuck,spawns]`.

enum Layer { FLOW, SLOTS, STUCK, SPAWNS }

const LAYER_KEYS: Array[String] = ["flow", "slots", "stuck", "spawns"]
const STUCK_CAPACITY: int = 32
const STUCK_HOLD_S: float = 3.0  ## how long an `enemy_stuck` event keeps its marker

var _sim: SimWorld
var _arena: ArenaDef
var _wanted: Dictionary[int, bool] = {}
var _nodes: Dictionary[int, Node3D] = {}
var _recent_stuck: Dictionary[int, float] = {}  ## enemy id -> seconds left
var _slot_free_mm: MultiMesh
var _slot_taken_mm: MultiMesh
var _stuck_mm: MultiMesh


func setup(arena: ArenaDef) -> void:
	name = "BattleDebugOverlay"
	_arena = arena


## `spec`: "all", or a comma list of flow, slots, stuck, spawns. Returns the layers it names.
static func parse_spec(spec: String) -> Array[int]:
	var out: Array[int] = []
	for token: String in spec.to_lower().split(",", false):
		var key: String = token.strip_edges()
		if key == "all":
			return [Layer.FLOW, Layer.SLOTS, Layer.STUCK, Layer.SPAWNS]
		var index: int = LAYER_KEYS.find(key)
		if index >= 0 and not out.has(index):
			out.append(index)
	return out


## Orientation of an arrow (built along +X) that points along the ground direction (dx, dz).
static func arrow_basis(dx: float, dz: float) -> Basis:
	return Basis(Vector3.UP, -atan2(dz, dx))


func apply_spec(spec: String) -> void:
	for layer: int in parse_spec(spec):
		set_layer(layer, true)


func bind(sim: SimWorld) -> void:
	unbind()
	_sim = sim
	Events.enemy_stuck.connect(_on_enemy_stuck)
	for layer: int in _wanted.keys():
		if _wanted[layer]:
			_build(layer)


## Frees every layer node (the requested layers come back on the next bind).
func unbind() -> void:
	if Events.enemy_stuck.is_connected(_on_enemy_stuck):
		Events.enemy_stuck.disconnect(_on_enemy_stuck)
	for layer: int in _nodes.keys():
		_free(layer)
	_recent_stuck.clear()
	_sim = null


func _exit_tree() -> void:
	unbind()


func set_layer(layer: int, on: bool) -> void:
	if layer < 0 or layer >= LAYER_KEYS.size():
		return
	_wanted[layer] = on
	if on and _sim != null and not _nodes.has(layer):
		_build(layer)
	elif not on and _nodes.has(layer):
		_free(layer)


func toggle(layer: int) -> void:
	set_layer(layer, not is_layer_on(layer))


func is_layer_on(layer: int) -> bool:
	return _wanted.get(layer, false)


## The node of a layer that is on and bound, else null.
func layer_node(layer: int) -> Node3D:
	return _nodes.get(layer, null)


func active_layers() -> Array[int]:
	var out: Array[int] = []
	for layer: int in LAYER_KEYS.size():
		if _nodes.has(layer):
			out.append(layer)
	return out


## Enemies currently marked as stuck (state or a recent event); the stuck layer draws one ring each.
func stuck_count() -> int:
	return _stuck_mm.visible_instance_count if _stuck_mm != null and _nodes.has(Layer.STUCK) else 0


func taken_slot_count() -> int:
	return _slot_taken_mm.visible_instance_count if _slot_taken_mm != null and _nodes.has(Layer.SLOTS) else 0


func _process(delta: float) -> void:
	update(delta)


## Refreshes the layers that follow the sim: slot occupancy and stuck markers.
func update(delta: float) -> void:
	if _sim == null:
		return
	for id: int in _recent_stuck.keys():
		_recent_stuck[id] -= delta
		if _recent_stuck[id] <= 0.0:
			_recent_stuck.erase(id)
	if _nodes.has(Layer.SLOTS):
		_update_slots()
	if _nodes.has(Layer.STUCK):
		_update_stuck()


# ---------------------------------------------------------------- building


func _build(layer: int) -> void:
	if _nodes.has(layer) or _sim == null:
		return
	var node: Node3D
	match layer:
		Layer.FLOW:
			node = _build_flow()
		Layer.SLOTS:
			node = _build_slots()
		Layer.STUCK:
			node = _build_stuck()
		_:
			node = _build_spawns()
	node.name = "Debug" + LAYER_KEYS[layer].capitalize()
	add_child(node)
	_nodes[layer] = node


func _free(layer: int) -> void:
	var node: Node3D = _nodes.get(layer, null)
	_nodes.erase(layer)
	if node != null and is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _build_flow() -> MultiMeshInstance3D:
	var flow: FlowField = _sim.nav.flow
	var g: ArenaGrid = flow.grid
	var mm: MultiMesh = OverlayMeshes.multimesh(OverlayMeshes.arrow(0.7), g.cols * g.rows)
	var n: int = 0
	for c: int in g.cols * g.rows:
		if g.blocked[c] == 1 or is_inf(flow.cost[c]):
			continue
		var at: Vector2 = g.cell_center(c)
		var turn: Basis = arrow_basis(flow.dir_x[c], flow.dir_z[c])
		mm.set_instance_transform(n, Transform3D(turn, Vector3(at.x, OverlayMeshes.Y_OVERLAY, at.y)))
		n += 1
	mm.visible_instance_count = n
	return _instance(mm, OverlayMeshes.FLOW_COLOR)


func _build_slots() -> Node3D:
	var root: Node3D = Node3D.new()
	var count: int = _sim.nav.slots.slot_count()
	_slot_free_mm = OverlayMeshes.multimesh(OverlayMeshes.ring(0.2, 0.3), count)
	_slot_taken_mm = OverlayMeshes.multimesh(OverlayMeshes.ring(0.0, 0.26), count)
	var free_node: MultiMeshInstance3D = _instance(_slot_free_mm, OverlayMeshes.SLOT_FREE_COLOR)
	free_node.name = "SlotsFree"
	var taken_node: MultiMeshInstance3D = _instance(_slot_taken_mm, OverlayMeshes.SLOT_TAKEN_COLOR)
	taken_node.name = "SlotsTaken"
	root.add_child(free_node)
	root.add_child(taken_node)
	return root


func _build_stuck() -> MultiMeshInstance3D:
	_stuck_mm = OverlayMeshes.multimesh(OverlayMeshes.ring(0.75, 0.95), STUCK_CAPACITY)
	return _instance(_stuck_mm, OverlayMeshes.STUCK_COLOR)


func _build_spawns() -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = OverlayMeshes.spawn_regions(_arena.spawn_regions)
	mi.material_override = OverlayMeshes.flat_material(OverlayMeshes.SPAWN_COLOR)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _instance(mm: MultiMesh, color: Color) -> MultiMeshInstance3D:
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = OverlayMeshes.flat_material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-60.0, -2.0, -60.0), Vector3(120.0, 8.0, 120.0))
	return node


# ---------------------------------------------------------------- following the sim


func _update_slots() -> void:
	var slots: AttackSlots = _sim.nav.slots
	var free_n: int = 0
	var taken_n: int = 0
	for s: int in slots.slot_count():
		var at: Vector3 = Vector3(slots.pos_x[s], OverlayMeshes.Y_OVERLAY, slots.pos_z[s])
		if slots.occupant(s) != 0:
			_slot_taken_mm.set_instance_transform(taken_n, Transform3D(Basis.IDENTITY, at))
			taken_n += 1
		else:
			_slot_free_mm.set_instance_transform(free_n, Transform3D(Basis.IDENTITY, at))
			free_n += 1
	_slot_free_mm.visible_instance_count = free_n
	_slot_taken_mm.visible_instance_count = taken_n


func _update_stuck() -> void:
	var st: EnemyStore = _sim.enemies
	var nav: NavState = _sim.nav
	var n: int = 0
	for i: int in st.high_water:
		if n >= STUCK_CAPACITY:
			break
		if st.alive[i] == 0:
			continue
		var by_state: bool = nav.track_id[i] == st.id[i] and (nav.grace[i] == 1 or nav.sep_off[i] > 0)
		if by_state or _recent_stuck.has(st.id[i]):
			var at: Vector3 = Vector3(st.x[i], OverlayMeshes.Y_OVERLAY + 0.01, st.z[i])
			_stuck_mm.set_instance_transform(n, Transform3D(Basis.IDENTITY, at))
			n += 1
	_stuck_mm.visible_instance_count = n


func _on_enemy_stuck(enemy_id: int) -> void:
	_recent_stuck[enemy_id] = STUCK_HOLD_S
