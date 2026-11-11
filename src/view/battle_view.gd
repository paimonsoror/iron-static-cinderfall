class_name BattleView
extends Node3D
## Composer of the 3D battle view (ARCH 8). Frozen: owners of the layers change the layers, not this file.
## Read-only with respect to the sim.

var camera_rig: CameraRig
var arena_view: ArenaView
var actor_layer: ActorLayer
var vfx_layer: VfxLayer

var _sim: SimWorld
var _core_key: Vector3 = Vector3(-1.0, -1.0, -1.0)
var _pads: Array[bool] = [false, false]


## Builds everything once.
func setup(content: ContentSet) -> void:
	MatLib.configure(content.tokens)
	arena_view = ArenaView.new()
	arena_view.name = "ArenaView"
	add_child(arena_view)
	arena_view.setup(content.arena, content.tokens)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(content.arena, content.tokens)
	actor_layer = ActorLayer.new()
	actor_layer.name = "ActorLayer"
	add_child(actor_layer)
	actor_layer.setup(content)
	vfx_layer = VfxLayer.new()
	vfx_layer.name = "VfxLayer"
	add_child(vfx_layer)
	vfx_layer.setup(content, camera_rig, actor_layer)


## Resets pools and starts reading this sim.
func bind(sim: SimWorld) -> void:
	_sim = sim
	_core_key = Vector3(-1.0, -1.0, -1.0)
	_pads = [false, false]
	actor_layer.bind(sim)
	vfx_layer.bind(sim)


func unbind() -> void:
	_sim = null
	actor_layer.unbind()
	vfx_layer.unbind()


## Once per frame, after the frame's ticks.
func render(alpha: float, delta: float) -> void:
	if _sim == null:
		return
	_sync_arena()
	actor_layer.render(alpha, delta)
	vfx_layer.render(alpha, delta)


func fit_camera(viewport_size: Vector2, top_px: float, bottom_px: float) -> void:
	camera_rig.fit(viewport_size, top_px, bottom_px)


func world_to_screen(x: float, z: float, height: float = 0.0) -> Vector2:
	return camera_rig.world_to_screen(Vector3(x, height, z))


func set_quality(tier: int) -> void:
	arena_view.set_quality(tier)
	actor_layer.set_quality(tier)
	vfx_layer.set_quality(tier)


func set_reduced_flash(on: bool) -> void:
	vfx_layer.set_reduced_flash(on)
	arena_view.set_reduced_flash(on)


## High-contrast setting (GDD 10.3). Added by the coordinator after Wave 1 so Game and the view can be built in
## parallel in Wave 2; the actor-side look is W2-E's.
func set_high_contrast(on: bool) -> void:
	actor_layer.set_high_contrast(on)


func _sync_arena() -> void:
	var hp_frac: float = _sim.core_hp / maxf(_sim.core_max_hp, 0.001)
	var absorb: float = maxf(_sim.content.abilities[Ids.AB_SHIELD].absorb, 0.001)
	var sh_frac: float = clampf(_sim.shield_hp / absorb, 0.0, 1.0)
	var dead: bool = _sim.core_hp <= 0.0
	var key: Vector3 = Vector3(hp_frac, sh_frac, 1.0 if dead else 0.0)
	if key != _core_key:
		_core_key = key
		arena_view.set_core_state(hp_frac, sh_frac, dead)
	for p: int in _pads.size():
		var on: bool = _sim.turrets.active[p] == 1
		if on != _pads[p]:
			_pads[p] = on
			arena_view.set_pad_state(p, on)
