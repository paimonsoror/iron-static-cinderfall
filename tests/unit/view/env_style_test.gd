extends GdUnitTestSuite
## EnvStyle (W3-E): the tier gates of the gritty yard. CURRENT gets nothing, LOW stays cheap and static, MID adds the wet floor and the
## prop shading, HIGH adds bloom and ripples; the look-dev overrides only ever remove effects.

const CUR: int = LookDevStyle.Look.CURRENT
const STY: int = LookDevStyle.Look.STYLISED
const PLUS: int = LookDevStyle.Look.STYLISED_PLUS
const LOW: int = VisualQuality.Tier.LOW
const MID: int = VisualQuality.Tier.MID
const HIGH: int = VisualQuality.Tier.HIGH


func after_test() -> void:
	EnvStyle.set_override("")


func test_current_gets_no_effect_on_any_tier() -> void:
	for fx: StringName in EnvStyle.ALL:
		for tier: int in [LOW, MID, HIGH]:
			assert_bool(EnvStyle.on(fx, CUR, tier)).override_failure_message("%s on CURRENT at tier %d" % [fx, tier]).is_false()


func test_low_keeps_only_the_static_effects() -> void:
	for fx: StringName in [EnvStyle.FLOOR, EnvStyle.PROPS, EnvStyle.REACTOR, EnvStyle.SPILL]:
		assert_bool(EnvStyle.on(fx, STY, LOW)).override_failure_message("%s should be on at LOW" % fx).is_true()
	for fx: StringName in [
		EnvStyle.WET, EnvStyle.PROP_SHADER, EnvStyle.GLOW, EnvStyle.RIPPLES, EnvStyle.FLICKER, EnvStyle.VIGNETTE, EnvStyle.GRADE
	]:
		assert_bool(EnvStyle.on(fx, STY, LOW)).override_failure_message("%s should be off at LOW" % fx).is_false()


func test_mid_adds_the_wet_floor_and_the_prop_shading_but_not_bloom() -> void:
	for fx: StringName in [EnvStyle.WET, EnvStyle.FLICKER, EnvStyle.GRADE]:
		assert_bool(EnvStyle.on(fx, STY, MID)).override_failure_message("%s should be on at MID" % fx).is_true()
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, MID)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.RIPPLES, STY, MID)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.PROP_SHADER, STY, MID)).is_false()  # measured: the prop shader is the one MID cost worth gating
	assert_bool(EnvStyle.on(EnvStyle.VIGNETTE, STY, MID)).is_false()  # the screen-edge pass is a full-screen blend: HIGH only


func test_high_has_everything() -> void:
	for fx: StringName in EnvStyle.ALL:
		assert_bool(EnvStyle.on(fx, STY, HIGH)).override_failure_message("%s should be on at HIGH" % fx).is_true()
		assert_bool(EnvStyle.on(fx, PLUS, HIGH)).is_true()


func test_every_effect_has_a_minimum_tier() -> void:
	for fx: StringName in EnvStyle.ALL:
		assert_bool(EnvStyle.MIN_TIER.has(fx)).override_failure_message("no tier for %s" % fx).is_true()
	assert_int(EnvStyle.MIN_TIER.size()).is_equal(EnvStyle.ALL.size())


func test_override_off_only_and_no() -> void:
	EnvStyle.set_override("off")
	for fx: StringName in EnvStyle.ALL:
		assert_bool(EnvStyle.on(fx, STY, HIGH)).is_false()
	EnvStyle.set_override("only:floor,wet")
	assert_bool(EnvStyle.on(EnvStyle.FLOOR, STY, HIGH)).is_true()
	assert_bool(EnvStyle.on(EnvStyle.WET, STY, HIGH)).is_true()
	assert_bool(EnvStyle.on(EnvStyle.PROPS, STY, HIGH)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.WET, STY, LOW)).is_false()  # the tier gate still applies
	EnvStyle.set_override("no:glow, vignette")
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, HIGH)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.VIGNETTE, STY, HIGH)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.FLOOR, STY, HIGH)).is_true()
	EnvStyle.set_override("garbage")
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, HIGH)).is_true()


func test_overrides_never_switch_on_what_a_tier_forbids() -> void:
	EnvStyle.set_override("only:glow")
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, LOW)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, MID)).is_false()
	assert_bool(EnvStyle.on(EnvStyle.GLOW, STY, HIGH)).is_true()
	assert_bool(EnvStyle.on(EnvStyle.GLOW, CUR, HIGH)).is_false()
