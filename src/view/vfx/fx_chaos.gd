class_name FxChaos
extends RefCounted
## The chaos effects of the variety milestone in one place (VARIETY_SPEC 10.2, 12.3), so VfxLayer stays small. V2-F: blasts (`FxBlasts`), chain
## arcs (`FxArcs`), ground telegraphs and the strike column (`FxTelegraph`) and burning pools (`FxPools`). V4-X: beams (`FxBeams`), things in
## the air (`FxLobs`), rings and tethers that follow enemies (`FxZones`), boss telegraphs (`FxBoss`), the Deadfall Strike's beacon and aftermath
## (`FxStrike`), the Static Front overlay (`FxStatic`), scorch marks, embers, shake and the ghost swarm (`FxCosmetic`), and the props of the
## events: the fuel drums (`DrumView`) and the freight car (`FreightView`). It listens to the `Events` of the variety milestone between `bind`
## and `unbind`, routes each to the modules that care and reads the sim (read only) for what has no event (wards, beams, drums, the lock of a
## static front). Every pool is allocated once in `setup` (at the HIGH size, limited by tier); nothing is created after. The simulation never
## sees any of it: the view only draws what the events and the state say. The quality tier, Reduced Flash and High Contrast live in the
## shared `FxContext`; High Contrast is picked up from the actor layer each frame (the BattleView forwards that switch to it only).

var blasts: FxBlasts = FxBlasts.new()
var arcs: FxArcs = FxArcs.new()
var telegraph: FxTelegraph = FxTelegraph.new()
var ground: FxPools = FxPools.new()
var beams: FxBeams = FxBeams.new()
var lobs: FxLobs = FxLobs.new()
var zones: FxZones = FxZones.new()
var boss: FxBoss = FxBoss.new()
var strike: FxStrike = FxStrike.new()
var cosmetic: FxCosmetic = FxCosmetic.new()
var overlay: FxStatic = FxStatic.new()
var drums: DrumView = DrumView.new()
var freight: FreightView = FreightView.new()
var ctx: FxContext = FxContext.new()

var _actors: ActorLayer


func setup(parent: Node3D, content: ContentSet, rig: CameraRig, actors: ActorLayer, sparks: VfxPool, bounds: AABB, rng: RandomNumberGenerator) -> void:
	_actors = actors
	ctx.setup(content, rig, actors, rng)
	blasts.setup(parent, bounds, sparks, rng)
	blasts.scale = ctx.scale
	arcs.setup(parent, bounds, actors, blasts, rng)
	telegraph.setup(parent, content, bounds)
	ground.setup(parent, bounds)
	beams.setup(parent, bounds, sparks, ctx)
	lobs.setup(parent, bounds, ctx)
	zones.setup(parent, bounds, ctx)
	boss.setup(parent, bounds, ctx, telegraph)
	strike.setup(parent, bounds, sparks, ctx)
	cosmetic.setup(parent, bounds, ctx)
	overlay.setup(content.tokens.color(&"chorus_red"))
	parent.add_child(overlay)
	drums.setup(content.arena, bounds)
	parent.add_child(drums)
	freight.setup(content, rng)
	freight.sparks = sparks
	parent.add_child(freight)


## Every pooled MultiMesh the VfxLayer must step (the ground pools and the follow pools step themselves in `step`).
func pools() -> Array[VfxPool]:
	var out: Array[VfxPool] = []
	out.append_array(blasts.pools())
	out.append_array(arcs.pools())
	out.append_array(telegraph.pools())
	out.append_array(beams.pools())
	out.append_array(lobs.pools())
	out.append_array(boss.pools())
	out.append_array(strike.pools())
	out.append_array(cosmetic.pools())
	return out


func bind(sim: SimWorld) -> void:
	unbind()
	ctx.sim = sim
	Events.area_blast.connect(_on_blast)
	Events.chain_arc.connect(arcs.arc)
	Events.delayed_hit.connect(_on_delayed)
	Events.pool_changed.connect(ground.changed)
	Events.event_warned.connect(_on_warned)
	Events.event_started.connect(_on_started)
	Events.event_ended.connect(overlay.ended)
	Events.crate_dropped.connect(_on_crate_dropped)
	Events.crate_secured.connect(_on_crate_secured)
	Events.crate_lost.connect(_on_crate_lost)
	zones.bind()
	boss.bind()


func unbind() -> void:
	_drop(Events.area_blast, _on_blast)
	_drop(Events.chain_arc, arcs.arc)
	_drop(Events.delayed_hit, _on_delayed)
	_drop(Events.pool_changed, ground.changed)
	_drop(Events.event_warned, _on_warned)
	_drop(Events.event_started, _on_started)
	_drop(Events.event_ended, overlay.ended)
	_drop(Events.crate_dropped, _on_crate_dropped)
	_drop(Events.crate_secured, _on_crate_secured)
	_drop(Events.crate_lost, _on_crate_lost)
	zones.unbind()
	boss.unbind()
	beams.unbind()
	strike.unbind()
	cosmetic.clear()
	overlay.clear()
	drums.clear()
	freight.clear()
	ground.clear()
	arcs.forget()
	ctx.sim = null


## Once per rendered frame, after the pools stepped.
func step(delta: float, facing: Basis) -> void:
	if _actors != null and _actors.is_high_contrast() != ctx.contrast:
		set_contrast(_actors.is_high_contrast())
	ctx.scale.update(ctx.rig)
	blasts.flashes.facing = facing
	blasts.flashes_cyan.facing = facing
	lobs.face(facing)
	ground.step(delta)
	zones.step()
	beams.step()
	boss.step(delta)
	strike.step(delta)
	cosmetic.step(delta, facing)
	freight.step(delta, ctx.tier)
	var sim: SimWorld = ctx.sim
	drums.refresh(sim)
	overlay.step(delta, sim.events_state.ability_lock_ticks if sim != null else 0)
	blasts.frame_done()
	arcs.frame_done()


func set_quality(tier: int) -> void:
	ctx.tier = VisualQuality.from_setting(tier)
	blasts.set_quality(tier)
	arcs.set_quality(tier)
	ground.set_quality(tier)
	beams.set_quality(tier)
	lobs.set_quality(tier)
	zones.set_quality(tier)
	cosmetic.set_quality(tier)


func set_reduced(on: bool) -> void:
	ctx.reduced = on
	blasts.set_reduced(on)
	arcs.set_reduced(on)
	beams.set_reduced(on)
	strike.set_reduced(on)
	cosmetic.set_reduced(on)
	overlay.set_reduced(on)


## High Contrast (GDD 10.3): the red outlines, the lane bars, the ward rings and the tether lines are thicker.
func set_contrast(on: bool) -> void:
	ctx.contrast = on
	telegraph.set_contrast(on)
	zones.set_contrast(on)


## Whether a shot of `source` is drawn by a beam (the torch, the lance) instead of a tracer; see `FxBeams.owns_shot`.
func owns_shot(source: int) -> bool:
	return beams.owns_shot(source)


## The Warden's heavy step (a boss footfall): a small shake.
func footfall(weight: float) -> void:
	cosmetic.shake(0.08 * weight)


func _on_blast(kind: int, x: float, z: float, radius: float) -> void:
	blasts.blast(kind, x, z, radius)
	cosmetic.blast(kind, x, z, radius)
	strike.blast(kind, x, z, radius)


func _on_delayed(kind: int, x: float, z: float, ticks: int) -> void:
	telegraph.delayed(kind, x, z, ticks)
	lobs.launched_hit(kind, x, z, ticks)
	strike.delayed(kind, x, z, ticks)


func _on_warned(event_id: StringName, ticks: int, x: float, z: float) -> void:
	telegraph.warned(event_id, ticks, x, z)
	freight.warned(event_id, ticks, x, z)
	overlay.warned(event_id, ticks, x, z)


func _on_started(event_id: StringName) -> void:
	overlay.started(event_id)
	if freight.started(event_id):
		cosmetic.shake(0.5)
	var def: EventDef = ctx.content.event_def(event_id)
	if def != null and def.who == EventDef.Who.WORLD:
		cosmetic.event_started()


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
