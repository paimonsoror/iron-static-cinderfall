class_name PuppetEvents
extends RefCounted
## Turns the sim's drained events into `Events` bus signals, the way RunController will (ARCH 7.1). SimPuppet is the
## only caller; the view and the HUD listen to the bus, never to the sim buffer. `kinds` remembers each live
## enemy's type index (ENEMY_KILLED carries no type, `enemy_died_at` needs it).

var kinds: Dictionary[int, int] = {}  ## enemy id -> type index
var counts: Dictionary[int, int] = {}  ## SimEventKind.Id -> how many were forwarded (tests, reports)

var _content: ContentSet
var _relay: GameEventRelay  ## the variety kinds go through the real relay (same mapping as a run)


func _init(content: ContentSet) -> void:
	_content = content
	_relay = GameEventRelay.new(content)


## Forwards every event in `list`; returns how many were forwarded.
func forward(list: Array[SimEvent]) -> int:
	for e: SimEvent in list:
		_one(e)
		counts[e.kind] = counts.get(e.kind, 0) + 1
	return list.size()


func count_of(kind: int) -> int:
	return counts.get(kind, 0)


func _one(e: SimEvent) -> void:
	match e.kind:
		SimEventKind.Id.ENEMY_SPAWNED:
			kinds[e.a] = e.b
			Events.enemy_spawned.emit(e.a, Ids.ENEMIES[e.b])
		SimEventKind.Id.BOSS_SPAWNED:
			Events.boss_spawned.emit(e.a, Ids.ENEMIES[e.b])
		SimEventKind.Id.SHOT_FIRED:
			Events.shot_fired.emit(e.a, e.b)
		SimEventKind.Id.ENEMY_DAMAGED:
			Events.enemy_damaged.emit(e.a, e.f, e.b)
		SimEventKind.Id.ENEMY_KILLED:
			var type_index: int = kinds.get(e.a, 0)
			Events.enemy_killed.emit(e.a, e.b)
			Events.enemy_died_at.emit(e.a, Ids.ENEMIES[type_index], e.f, e.g, _content.enemies[type_index].scrap)
			kinds.erase(e.a)
		SimEventKind.Id.SCRAP_CHANGED:
			Events.scrap_changed.emit(e.a)
		SimEventKind.Id.CORE_HIT:
			Events.core_hit.emit(e.a, Ids.ENEMIES[e.b], e.f, e.g)
		SimEventKind.Id.CORE_CHANGED:
			Events.core_changed.emit(e.f, e.g)
		SimEventKind.Id.SHIELD_CHANGED:
			Events.shield_changed.emit(e.f, e.g)
		SimEventKind.Id.UPGRADE_LEVEL_CHANGED:
			Events.upgrade_level_changed.emit(Ids.UPGRADES[e.a], e.b)
		SimEventKind.Id.WEAPON_CHANGED:
			Events.weapon_changed.emit(Ids.WEAPONS[e.a])
		SimEventKind.Id.TURRET_DEPLOYED:
			Events.turret_deployed.emit(e.a)
		SimEventKind.Id.RELOAD_STARTED:
			Events.reload_started.emit(e.a)
		SimEventKind.Id.RELOAD_FINISHED:
			Events.reload_finished.emit()
		SimEventKind.Id.ABILITY_ACTIVATED:
			Events.ability_activated.emit(Ids.ABILITIES[e.a])
		SimEventKind.Id.ABILITY_ENDED:
			Events.ability_ended.emit(Ids.ABILITIES[e.a])
		SimEventKind.Id.ABILITY_REJECTED:
			Events.ability_rejected.emit(Ids.ABILITIES[e.a], e.b)
		SimEventKind.Id.ENEMY_STUNNED:
			Events.enemy_stunned.emit(e.a, e.b)
		SimEventKind.Id.ENEMY_STUCK:
			Events.enemy_stuck.emit(e.a)
		SimEventKind.Id.ELITE_SPAWNED:
			var elite_type: int = kinds.get(e.a, 0)
			Events.elite_spawned.emit(e.a, Ids.ENEMIES[elite_type], e.b)
		_:
			if e.kind > SimEventKind.Id.RUN_FINISHED:
				var _relayed: bool = _relay.relay(e)
