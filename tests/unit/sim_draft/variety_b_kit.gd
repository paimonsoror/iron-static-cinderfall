class_name VarietyBKit
extends RefCounted
## Helpers of the V2-B suites (drafts, directives, modifiers). Content is always the frozen variety fixture
## (WORK_PLAN rule 5); the synthetic directives below exist only inside a ContentSet copy a test builds for itself.
## `draft_world` puts a world in the intermission and opens a draft by hand, so these suites test the draft alone:
## the intermission of the kit is a long breather (PhaseSystem walks SALVAGE, DRAFT and ROUTE only outside the breather;
## the real chain is tested in tests/unit/sim_plan/test_slice_intermission.gd).

static var _next_id: int = 1000


static func next_id() -> int:
	_next_id += 1
	return _next_id


## A synthetic directive; the index is its position once appended to a ContentSet.
static func def(
	id: StringName, rarity: int, max_stacks: int = 99, tags: Array[StringName] = [], ops: Array[OpDef] = []
) -> DirectiveDef:
	var d: DirectiveDef = DirectiveDef.new()
	d.id = id
	d.rarity = rarity
	d.max_stacks = max_stacks
	d.tags = tags
	d.ops = ops
	return d


static func ops_of(op: OpDef) -> Array[OpDef]:
	var out: Array[OpDef] = [op]
	return out


## `d` with one more `requires{}` entry.
static func require(d: DirectiveDef, key: StringName, value: float) -> DirectiveDef:
	d.requires[key] = value
	return d


static func op_add(stat: StringName, value: float) -> OpDef:
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.ADD
	op.target = stat
	op.value = value
	return op


static func op_mul(stat: StringName, value: float) -> OpDef:
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.MUL
	op.target = stat
	op.value = value
	return op


static func op_flag(flag: StringName) -> OpDef:
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.FLAG
	op.target = flag
	op.value = 1.0
	return op


static func op_grant(kind: StringName, n: float, arg: StringName = &"", per_act: float = 0.0) -> OpDef:
	var op: OpDef = OpDef.new()
	op.kind = OpDef.Kind.GRANT
	op.target = kind
	op.value = n
	op.arg = arg
	op.per_act = per_act
	return op


## Appends `d` to the directive list of `c` and returns its index.
static func add_directive(c: ContentSet, d: DirectiveDef) -> int:
	d.index = c.directives.size()
	c.directives.append(d)
	return d.index


## The variety fixture with its directive list replaced by a pool big enough for statistics: 14 commons (c00..c13), 10
## rares (r00..r09), 8 prototypes (p00..p07), 4 corrupted (x00..x03), every one stackable 99 times, no tag, no pity.
static func big_content() -> ContentSet:
	var c: ContentSet = TestContent.variety()
	c.directives.clear()
	for i: int in 14:
		add_directive(c, def(StringName("c%02d" % i), DirectiveDef.Rarity.COMMON))
	for i: int in 10:
		add_directive(c, def(StringName("r%02d" % i), DirectiveDef.Rarity.RARE))
	for i: int in 8:
		add_directive(c, def(StringName("p%02d" % i), DirectiveDef.Rarity.PROTOTYPE))
	for i: int in 4:
		add_directive(c, def(StringName("x%02d" % i), DirectiveDef.Rarity.CORRUPTED))
	return c


## A world on `c` as it is after wave `wave_number` was cleared (wave and act written, nothing else changed).
static func world_after(c: ContentSet, wave_number: int, run_seed: int = 1, act: int = 1) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfig.create(c, run_seed))
	w.wave = wave_number
	w.phase_state.act = act
	return w


## The same, in INTERMISSION with a long breather countdown (nothing is awaited yet, no draft is open).
static func intermission_world(c: ContentSet, wave_number: int = 3, run_seed: int = 1, act: int = 1) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfig.create(c, run_seed))
	w.set_phase(GameState.Id.SPAWNING)
	w.wave = wave_number
	w.phase_state.act = act
	w.set_phase(GameState.Id.CLEARING)
	w.set_phase(GameState.Id.INTERMISSION)
	w.phase_state.breather = true  # the flow of PhaseAwaits stays out of the way: a closed draft does not open the next step
	w.phase_ticks_left = 1000000
	return w


## Sets the DRAFT await and opens a draft, the way PhaseSystem will.
static func open_draft(w: SimWorld) -> void:
	w.phase_state.awaiting = PhaseState.Await.DRAFT
	DraftSystem.open(w)


## An intermission world with a draft already open.
static func draft_world(c: ContentSet, wave_number: int = 3, run_seed: int = 1, act: int = 1) -> SimWorld:
	var w: SimWorld = intermission_world(c, wave_number, run_seed, act)
	open_draft(w)
	return w


static func events_of(w: SimWorld, kind: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e: SimEvent in w.events.peek():
		if e.kind == kind:
			out.append(e)
	return out


## Submits `cmd`, steps once and returns the Reason the sim answered (OK when there was no COMMAND_REJECTED for it).
static func send(w: SimWorld, cmd: SimCommand) -> int:
	var before: int = events_of(w, SimEventKind.Id.COMMAND_REJECTED).size()
	w.submit(cmd)
	w.step()
	var rejected: Array[SimEvent] = events_of(w, SimEventKind.Id.COMMAND_REJECTED)
	if rejected.size() > before and rejected[rejected.size() - 1].a == cmd.command_id:
		return rejected[rejected.size() - 1].b
	return Reason.Id.OK


## The offer the world would make as offer number `n` (0-based), without opening a draft: the pure roll.
static func offer_n(w: SimWorld, n: int) -> PackedInt32Array:
	w.draft.offer_ordinal = n + 1
	return DraftSystem.generate_offer(w)


## The ids of an offer, in slot order.
static func ids(c: ContentSet, offer: PackedInt32Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for index: int in offer:
		out.append(c.directives[index].id if index >= 0 else &"")
	return out


## How many of the first `count` offers (0-based ordinals) hold the directive `index`.
static func offers_with(w: SimWorld, index: int, count: int) -> int:
	var n: int = 0
	for ordinal: int in count:
		if offer_n(w, ordinal).has(index):
			n += 1
	return n
