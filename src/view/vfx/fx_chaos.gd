class_name FxChaos
extends RefCounted
## The chaos effects of the variety milestone in one place (VARIETY_SPEC 10.2, 12.3), so VfxLayer stays small: blasts (`FxBlasts`), chain
## arcs (`FxArcs`), ground telegraphs and the strike column (`FxTelegraph`) and burning pools (`FxPools`). It listens to the new `Events`
## itself between `bind` and `unbind`: `area_blast`, `chain_arc`, `delayed_hit`, `pool_changed`, `event_warned`, `crate_dropped`,
## `crate_secured`, `crate_lost`. Every pool is allocated once in `setup` (at the HIGH size, limited by tier); nothing is created after.
## The simulation never sees any of it: the view only draws what the events say.

var blasts: FxBlasts = FxBlasts.new()
var arcs: FxArcs = FxArcs.new()
var telegraph: FxTelegraph = FxTelegraph.new()
var ground: FxPools = FxPools.new()

var _actors: ActorLayer


func setup(parent: Node3D, content: ContentSet, actors: ActorLayer, sparks: VfxPool, bounds: AABB, rng: RandomNumberGenerator) -> void:
	_actors = actors
	blasts.setup(parent, bounds, sparks, rng)
	arcs.setup(parent, bounds, actors, blasts, rng)
	telegraph.setup(parent, content, bounds)
	ground.setup(parent, bounds)


## Every pooled MultiMesh the VfxLayer must step (the ground pools step themselves in `step`).
func pools() -> Array[VfxPool]:
	var out: Array[VfxPool] = []
	out.append_array(blasts.pools())
	out.append_array(arcs.pools())
	out.append_array(telegraph.pools())
	return out


func bind() -> void:
	unbind()
	Events.area_blast.connect(blasts.blast)
	Events.chain_arc.connect(arcs.arc)
	Events.delayed_hit.connect(telegraph.delayed)
	Events.pool_changed.connect(ground.changed)
	Events.event_warned.connect(telegraph.warned)
	Events.crate_dropped.connect(_on_crate_dropped)
	Events.crate_secured.connect(_on_crate_secured)
	Events.crate_lost.connect(_on_crate_lost)


func unbind() -> void:
	_drop(Events.area_blast, blasts.blast)
	_drop(Events.chain_arc, arcs.arc)
	_drop(Events.delayed_hit, telegraph.delayed)
	_drop(Events.pool_changed, ground.changed)
	_drop(Events.event_warned, telegraph.warned)
	_drop(Events.crate_dropped, _on_crate_dropped)
	_drop(Events.crate_secured, _on_crate_secured)
	_drop(Events.crate_lost, _on_crate_lost)
	ground.clear()
	arcs.forget()


## Once per rendered frame, after the pools stepped.
func step(delta: float, facing: Basis) -> void:
	blasts.flashes.facing = facing
	ground.step(delta)
	blasts.frame_done()
	arcs.frame_done()


func set_quality(tier: int) -> void:
	blasts.set_quality(tier)
	arcs.set_quality(tier)
	ground.set_quality(tier)


func set_reduced(on: bool) -> void:
	blasts.set_reduced(on)
	arcs.set_reduced(on)


func _on_crate_dropped(x: float, z: float) -> void:
	blasts.crate_pulse(Vector3(x, 0.0, z), true)


func _on_crate_secured() -> void:
	var at: Vector3 = _actors.crate.crate_position()
	if at.is_finite():
		blasts.crate_pulse(at, true)


func _on_crate_lost() -> void:
	var at: Vector3 = _actors.crate.crate_position()
	if at.is_finite():
		blasts.crate_pulse(at, false)


func _drop(sig: Signal, handler: Callable) -> void:
	if sig.is_connected(handler):
		sig.disconnect(handler)
