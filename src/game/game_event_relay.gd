class_name GameEventRelay
extends RefCounted
## Turns SimEvents into the gameplay signals of `Events` (ARCH 6.3 table to 7.1), mapping index payloads to
## StringName ids. Used only by RunController, the sole emitter of these signals.
##
## Not handled here: PHASE_CHANGED (Game mirrors it into the application state machine) and RUN_FINISHED (the
## reward is granted before `run_finished`); RunController takes those two. ENEMY_REACHED_SLOT and SPAWN_QUEUED have
## no Events signal of their own (nothing outside the sim listens), so they are dropped on purpose; the one exception
## is a fused enemy reaching its slot, which becomes `burster_armed` (V3-I).
##
## The sim frees a killed enemy's store slot, and ENEMY_KILLED carries no type, so the relay remembers the type of
## every enemy it saw spawn (enemy id -> type index) until it dies.

## Kinds this class deliberately does not turn into a signal.
## The variety kinds in this list are read through RunApi queries or arrive as another signal (a refused SALVAGE as
## COMMAND_REJECTED, a split as the spawns of the shards, heals as the hp the view reads from the sim).
const NO_SIGNAL: Array[int] = [
	SimEventKind.Id.ENEMY_REACHED_SLOT, SimEventKind.Id.SPAWN_QUEUED, SimEventKind.Id.BOSS_BRIEFED,
	SimEventKind.Id.SALVAGE_RESOLVED, SimEventKind.Id.ENEMY_SPLIT, SimEventKind.Id.ENEMY_HEALED, SimEventKind.Id.CORE_HEALED,
]
const CM: float = 0.01  ## sim events carry radii in centimeters, the signals in meters

## Optional: the world whose events are relayed. With it `draft_offered` carries the offered ids (DraftState.offer);
## without it the list is empty and listeners read RunApi.draft_offer().
var world: SimWorld

var _content: ContentSet
var _types: Dictionary[int, int] = {}  ## enemy id -> type index


func _init(content_set: ContentSet) -> void:
	_content = content_set


## Enemies currently remembered (tests: nothing leaks after kills).
func tracked_count() -> int:
	return _types.size()


## Emits the signal(s) for one event. Returns false for kinds this class does not emit.
func relay(e: SimEvent) -> bool:
	match e.kind:
		SimEventKind.Id.WAVE_STARTED:
			Events.wave_started.emit(e.a)
		SimEventKind.Id.WAVE_CLEARED:
			Events.wave_cleared.emit(e.a)
		SimEventKind.Id.INTERMISSION_STARTED:
			Events.intermission_started.emit(e.a, e.b)
		SimEventKind.Id.ENEMY_SPAWNED:
			_types[e.a] = e.b
			Events.enemy_spawned.emit(e.a, _enemy(e.b))
		SimEventKind.Id.BOSS_SPAWNED:
			Events.boss_spawned.emit(e.a, _enemy(e.b))
		SimEventKind.Id.SHOT_FIRED:
			Events.shot_fired.emit(e.a, e.b)
		SimEventKind.Id.ENEMY_DAMAGED:
			Events.enemy_damaged.emit(e.a, e.f, e.b)
		SimEventKind.Id.ENEMY_KILLED:
			_relay_kill(e)
		SimEventKind.Id.SCRAP_CHANGED:
			Events.scrap_changed.emit(e.a)
		SimEventKind.Id.CORE_HIT:
			Events.core_hit.emit(e.a, _enemy(e.b), e.f, e.g)
		SimEventKind.Id.CORE_CHANGED:
			Events.core_changed.emit(e.f, e.g)
		SimEventKind.Id.SHIELD_CHANGED:
			Events.shield_changed.emit(e.f, e.g)
		SimEventKind.Id.PURCHASE_RESOLVED:
			Events.purchase_resolved.emit(e.a, e.b == Reason.Id.OK, e.b)
		SimEventKind.Id.UPGRADE_LEVEL_CHANGED:
			Events.upgrade_level_changed.emit(_upgrade(e.a), e.b)
		SimEventKind.Id.WEAPON_CHANGED:
			Events.weapon_changed.emit(_weapon(e.a))
		SimEventKind.Id.TURRET_DEPLOYED:
			Events.turret_deployed.emit(e.a)
		SimEventKind.Id.RELOAD_STARTED:
			Events.reload_started.emit(e.a)
		SimEventKind.Id.RELOAD_FINISHED:
			Events.reload_finished.emit()
		SimEventKind.Id.ABILITY_ACTIVATED:
			Events.ability_activated.emit(_ability(e.a))
		SimEventKind.Id.ABILITY_ENDED:
			Events.ability_ended.emit(_ability(e.a))
		SimEventKind.Id.ABILITY_REJECTED:
			Events.ability_rejected.emit(_ability(e.a), e.b)
		SimEventKind.Id.ENEMY_STUNNED:
			Events.enemy_stunned.emit(e.a, e.b)
		SimEventKind.Id.ENEMY_STUCK:
			Events.enemy_stuck.emit(e.a)
		SimEventKind.Id.ENEMY_REACHED_SLOT:
			return _relay_reached_slot(e)
		_:
			return _relay_variety(e)
	return true


## The kinds of the variety milestone (VARIETY_SPEC 13.2 to 13.4).
func _relay_variety(e: SimEvent) -> bool:
	match e.kind:
		SimEventKind.Id.ACT_STARTED:
			Events.act_started.emit(e.a)
		SimEventKind.Id.DRAFT_OFFERED, SimEventKind.Id.DRAFT_REROLLED:
			Events.draft_offered.emit(_offer_ids())
		SimEventKind.Id.DIRECTIVE_PICKED:
			Events.directive_picked.emit(_directive(e.a), e.b)
		SimEventKind.Id.ROUTE_OFFERED:
			Events.route_offered.emit()
		SimEventKind.Id.ROUTE_PICKED:
			Events.route_picked.emit(e.b)
		SimEventKind.Id.AWAIT_CHANGED:
			Events.await_changed.emit(e.a)
			if e.a == PhaseState.Await.SALVAGE:
				Events.salvage_offered.emit()
		SimEventKind.Id.CRATE_DROPPED:
			Events.crate_dropped.emit(e.f, e.g)
		SimEventKind.Id.CRATE_SECURED:
			Events.crate_secured.emit()
		SimEventKind.Id.CRATE_LOST:
			Events.crate_lost.emit()
		SimEventKind.Id.WEAPON_SWAPPED:
			Events.weapon_swapped.emit(e.a, _weapon(e.b))
		SimEventKind.Id.WEAPON_VENTED:
			Events.weapon_vented.emit(e.a)
		SimEventKind.Id.AREA_BLAST:
			Events.area_blast.emit(e.a, e.f, e.g, float(e.b) * CM)
		SimEventKind.Id.CHAIN_ARC:
			Events.chain_arc.emit(e.a, e.b)
		SimEventKind.Id.DELAYED_HIT_LAUNCHED:
			Events.delayed_hit.emit(e.a, e.f, e.g, e.b)
		SimEventKind.Id.POOL_STARTED:
			Events.pool_changed.emit(e.a, e.f, e.g, float(e.b) * CM, true)
		SimEventKind.Id.POOL_ENDED:
			Events.pool_changed.emit(e.a, e.f, e.g, 0.0, false)
		SimEventKind.Id.ELITE_SPAWNED:
			var type_index: int = _types.get(e.a, -1)
			Events.elite_spawned.emit(e.a, _enemy(type_index), e.b)
		SimEventKind.Id.WARD_CHANGED:
			Events.ward_changed.emit(e.a, clampf(e.f / e.g, 0.0, 1.0) if e.g > 0.0 else 0.0)
		SimEventKind.Id.WARD_BROKEN:
			Events.ward_changed.emit(e.a, 0.0)
		SimEventKind.Id.EVENT_WARNED:
			Events.event_warned.emit(_event(e.a), e.b, e.f, e.g)
		SimEventKind.Id.EVENT_STARTED:
			Events.event_started.emit(_event(e.a))
		SimEventKind.Id.EVENT_ENDED, SimEventKind.Id.EVENT_CANCELLED:
			Events.event_ended.emit(_event(e.a))
		SimEventKind.Id.BOSS_TELEGRAPH:
			Events.boss_telegraph.emit(e.a, e.b)
		SimEventKind.Id.BOSS_PHASE:
			Events.boss_phase.emit(e.a)
		SimEventKind.Id.CHARGES_CHANGED:
			Events.charges_changed.emit(_event(e.a), e.b)
		SimEventKind.Id.COMMAND_REJECTED:
			Events.command_rejected.emit(e.a, e.b)
		_:
			return false
	return true


## The directive ids of the open draft, slot by slot (&"" for a slot that was taken); empty without a bound world.
func _offer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if world != null:
		for index: int in world.draft.offer:
			ids.append(_directive(index))
	return ids


func _directive(index: int) -> StringName:
	return _content.directives[index].id if index >= 0 and index < _content.directives.size() else &""


func _event(index: int) -> StringName:
	return _content.events[index].id if index >= 0 and index < _content.events.size() else &""


## ENEMY_REACHED_SLOT has no signal of its own. An enemy with a fuse (`fuse_s`, the burster) arms on the tick it reaches
## its slot (CoreAttackSystem), which is what `burster_armed` announces. False for every other enemy.
func _relay_reached_slot(e: SimEvent) -> bool:
	var type_index: int = _types.get(e.a, -1)
	if type_index < 0 or type_index >= _content.enemies.size() or _content.enemies[type_index].beh(&"fuse_s") <= 0.0:
		return false
	Events.burster_armed.emit(e.a)
	return true


## enemy_killed, then enemy_died_at (position and Scrap for the effects).
func _relay_kill(e: SimEvent) -> void:
	var type_index: int = _types.get(e.a, -1)
	_types.erase(e.a)
	Events.enemy_killed.emit(e.a, e.b)
	var scrap: int = 0
	if type_index >= 0 and type_index < _content.enemies.size():
		scrap = _content.enemies[type_index].scrap
	Events.enemy_died_at.emit(e.a, _enemy(type_index), e.f, e.g, scrap)


static func _enemy(index: int) -> StringName:
	return Ids.ENEMIES[index] if index >= 0 and index < Ids.ENEMIES.size() else &""


static func _upgrade(index: int) -> StringName:
	return Ids.UPGRADES[index] if index >= 0 and index < Ids.UPGRADES.size() else &""


static func _weapon(index: int) -> StringName:
	return Ids.WEAPONS[index] if index >= 0 and index < Ids.WEAPONS.size() else &""


static func _ability(index: int) -> StringName:
	return Ids.ABILITIES[index] if index >= 0 and index < Ids.ABILITIES.size() else &""
