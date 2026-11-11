class_name GameEventRelay
extends RefCounted
## Turns SimEvents into the gameplay signals of `Events` (ARCH 6.3 table to 7.1), mapping index payloads to
## StringName ids. Used only by RunController, the sole emitter of these signals.
##
## Not handled here: PHASE_CHANGED (Game mirrors it into the application state machine) and RUN_FINISHED (the
## reward is granted before `run_finished`); RunController takes those two. ENEMY_REACHED_SLOT and SPAWN_QUEUED have
## no Events signal (nothing outside the sim listens), so they are dropped on purpose.
##
## The sim frees a killed enemy's store slot, and ENEMY_KILLED carries no type, so the relay remembers the type of
## every enemy it saw spawn (enemy id -> type index) until it dies.

## Kinds this class deliberately does not turn into a signal.
const NO_SIGNAL: Array[int] = [SimEventKind.Id.ENEMY_REACHED_SLOT, SimEventKind.Id.SPAWN_QUEUED]

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
		_:
			return false
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
