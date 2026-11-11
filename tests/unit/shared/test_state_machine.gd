extends GdUnitTestSuite
## Application state machine (ARCH 4.1): every legal transition, a sample of illegal ones, pause semantics.

const S := GameState.Id

## Every row of the ARCH 4.1 table except PAUSED -> paused_from (tested separately).
const LEGAL: Array = [
	[S.BOOT, S.MENU],
	[S.MENU, S.BRIEFING],
	[S.BRIEFING, S.MENU],
	[S.BRIEFING, S.PREPARING],
	[S.PREPARING, S.SPAWNING],
	[S.PREPARING, S.PAUSED],
	[S.SPAWNING, S.CLEARING],
	[S.SPAWNING, S.DEFEAT],
	[S.SPAWNING, S.PAUSED],
	[S.CLEARING, S.INTERMISSION],
	[S.CLEARING, S.VICTORY],
	[S.CLEARING, S.DEFEAT],
	[S.CLEARING, S.PAUSED],
	[S.INTERMISSION, S.SPAWNING],
	[S.INTERMISSION, S.PAUSED],
	[S.PAUSED, S.PREPARING],
	[S.PAUSED, S.MENU],
	[S.VICTORY, S.PREPARING],
	[S.VICTORY, S.MENU],
	[S.DEFEAT, S.PREPARING],
	[S.DEFEAT, S.MENU],
]

const ILLEGAL: Array = [
	[S.BOOT, S.BRIEFING],
	[S.BOOT, S.PREPARING],
	[S.MENU, S.PREPARING],
	[S.MENU, S.MENU],
	[S.BRIEFING, S.SPAWNING],
	[S.PREPARING, S.CLEARING],
	[S.PREPARING, S.DEFEAT],
	[S.SPAWNING, S.INTERMISSION],
	[S.SPAWNING, S.VICTORY],
	[S.CLEARING, S.SPAWNING],
	[S.INTERMISSION, S.VICTORY],
	[S.INTERMISSION, S.DEFEAT],
	[S.VICTORY, S.DEFEAT],
	[S.VICTORY, S.SPAWNING],
	[S.DEFEAT, S.VICTORY],
	[S.PAUSED, S.PAUSED],
	[S.PAUSED, S.BOOT],
	[S.PAUSED, S.VICTORY],
	[S.MENU, S.PAUSED],
	[S.VICTORY, S.PAUSED],
]


func test_every_legal_transition_is_accepted() -> void:
	for row: Array in LEGAL:
		var from: int = row[0]
		var to: int = row[1]
		assert_bool(GameStateMachine.can_transition(from, to)).is_true()


func test_sample_of_illegal_transitions_is_rejected() -> void:
	for row: Array in ILLEGAL:
		var from: int = row[0]
		var to: int = row[1]
		assert_bool(GameStateMachine.can_transition(from, to)).is_false()


func test_illegal_transition_changes_nothing() -> void:
	var m: GameStateMachine = GameStateMachine.new()
	assert_bool(m.transition(S.PREPARING)).is_false()
	assert_int(m.current).is_equal(S.BOOT)
	assert_int(m.previous).is_equal(S.BOOT)
	assert_int(m.paused_from).is_equal(-1)


func test_full_run_walk_through_the_machine() -> void:
	var m: GameStateMachine = GameStateMachine.new()
	for to: int in [S.MENU, S.BRIEFING, S.PREPARING, S.SPAWNING, S.CLEARING, S.INTERMISSION, S.SPAWNING, S.CLEARING, S.VICTORY, S.MENU]:
		assert_bool(m.transition(to)).is_true()
		assert_int(m.current).is_equal(to)


func test_pause_remembers_state_and_resumes_only_there() -> void:
	var m: GameStateMachine = GameStateMachine.new()
	for to: int in [S.MENU, S.BRIEFING, S.PREPARING, S.SPAWNING, S.PAUSED]:
		assert_bool(m.transition(to)).is_true()
	assert_int(m.paused_from).is_equal(S.SPAWNING)
	assert_bool(m.transition(S.CLEARING)).is_false()
	assert_bool(m.transition(S.INTERMISSION)).is_false()
	assert_int(m.current).is_equal(S.PAUSED)
	assert_bool(m.transition(S.SPAWNING)).is_true()
	assert_int(m.paused_from).is_equal(-1)


func test_pause_can_restart_or_quit() -> void:
	var restart: GameStateMachine = GameStateMachine.new()
	for to: int in [S.MENU, S.BRIEFING, S.PREPARING, S.SPAWNING, S.PAUSED, S.PREPARING]:
		assert_bool(restart.transition(to)).is_true()
	var quit: GameStateMachine = GameStateMachine.new()
	for to: int in [S.MENU, S.BRIEFING, S.PREPARING, S.PAUSED, S.MENU]:
		assert_bool(quit.transition(to)).is_true()


func test_state_predicates() -> void:
	assert_bool(GameState.is_run_phase(S.PREPARING)).is_true()
	assert_bool(GameState.is_run_phase(S.DEFEAT)).is_true()
	assert_bool(GameState.is_run_phase(S.MENU)).is_false()
	assert_bool(GameState.is_run_phase(S.PAUSED)).is_false()
	assert_bool(GameState.is_combat(S.SPAWNING)).is_true()
	assert_bool(GameState.is_combat(S.CLEARING)).is_true()
	assert_bool(GameState.is_combat(S.INTERMISSION)).is_false()
	assert_bool(GameState.is_terminal(S.VICTORY)).is_true()
	assert_bool(GameState.is_terminal(S.DEFEAT)).is_true()
	assert_bool(GameState.is_terminal(S.CLEARING)).is_false()


func test_state_names() -> void:
	assert_str(GameState.name_of(S.BOOT)).is_equal("BOOT")
	assert_str(GameState.name_of(S.PAUSED)).is_equal("PAUSED")
	assert_str(GameState.name_of(99)).is_equal("UNKNOWN")


func test_reason_keys() -> void:
	assert_str(Reason.string_key(Reason.Id.INSUFFICIENT_SCRAP)).is_equal("reason.insufficient_scrap")
	assert_str(Reason.string_key(Reason.Id.OK)).is_equal("reason.ok")
	assert_str(Reason.string_key(Reason.Id.PAUSED)).is_equal("reason.paused")
	assert_int(Reason.KEYS.size()).is_equal(Reason.Id.size())
