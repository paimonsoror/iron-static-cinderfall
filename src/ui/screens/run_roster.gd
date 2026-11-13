class_name RunRoster
extends RefCounted
## What a run of a ContentSet holds, for the briefing and the results screen (V3-I): how many waves, which machines can
## come and which boss stands in which wave. The legacy 5-wave content answers from its scripted waves (the four old
## types); variety content answers from the run definition: the waves of `run.waves`, the machines of the packs and the
## boss pools of the acts those waves use. Read-only helpers over the defs; the plan of one seed is not known here.
## With the full content (V4) the roster is every type of the three acts: the briefing lists them all, weakest first, and scrolls.


## Waves in a run: the wave slots of a generated run, else the scripted waves.
static func wave_count(content: ContentSet) -> int:
	if content == null:
		return 0
	return content.run.waves.size() if content.run != null else content.waves.size()


## The machines a run can field, in content order. Legacy content: the four old types.
static func enemies(content: ContentSet) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	if content == null:
		return out
	if content.run == null:
		return content.enemies.slice(0, Ids.LEGACY_ENEMY_COUNT)
	var used: Dictionary[int, bool] = {}
	var last_act: int = _last_act(content.run)
	for pack: PackDef in content.run.packs:
		if pack.min_act <= last_act:
			for enemy_index: int in pack.group_enemy:
				used[enemy_index] = true
	for boss: BossDef in content.bosses:
		if boss.pool_act <= last_act:
			used[boss.enemy_index] = true
			for enemy_index: int in boss.escort_enemy:
				used[enemy_index] = true
	for def: EnemyDef in content.enemies:
		if used.has(def.index):
			out.append(def)
	return out


## The boss waves whose boss is certain (its act has one boss in the pool): { "enemy": EnemyDef, "wave": int }.
## Legacy content: every boss type, in the last wave.
static func boss_waves(content: ContentSet) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if content == null:
		return out
	if content.run == null:
		for def: EnemyDef in content.enemies:
			if def.is_boss:
				out.append({"enemy": def, "wave": content.waves.size()})
		return out
	for slot: WaveSlotDef in content.run.waves:
		if slot.kind != WaveSlotDef.Kind.BOSS:
			continue
		var pool: Array[BossDef] = []
		for boss: BossDef in content.bosses:
			if boss.pool_act == slot.act:
				pool.append(boss)
		if pool.size() == 1 and pool[0].enemy_index >= 0 and pool[0].enemy_index < content.enemies.size():
			out.append({"enemy": content.enemies[pool[0].enemy_index], "wave": slot.index})
	return out


static func _last_act(run: RunDef) -> int:
	var last: int = 1
	for slot: WaveSlotDef in run.waves:
		last = maxi(last, slot.act)
	return last
