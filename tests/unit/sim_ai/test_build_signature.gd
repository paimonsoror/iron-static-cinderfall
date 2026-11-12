extends GdUnitTestSuite
## V2-H: the build signature (VARIETY_SPEC 14.2 S11): the primary weapon by damage dealt plus the two tags with the most
## stacks, and the tally of damage per weapon that names the primary weapon.

var w: SimWorld


func before_test() -> void:
	w = VarietyHKit.world()


func _damage(source: int, amount: float) -> SimEvent:
	var e: SimEvent = SimEvent.new()
	e.kind = SimEventKind.Id.ENEMY_DAMAGED
	e.a = 1
	e.b = source
	e.f = amount
	return e


func test_a_fresh_build_is_just_the_pistol() -> void:
	assert_str(BuildSignature.of(w)).is_equal("pistol")


func test_the_two_tags_with_most_stacks_follow_the_weapon() -> void:
	VarietyHKit.hold(w, &"hot_loads", 2)  # bullet x2
	VarietyHKit.hold(w, &"penetrator_cores", 1)  # bullet, gunline
	VarietyHKit.hold(w, &"turret_deploy", 1)  # gunline
	VarietyHKit.hold(w, &"reinforced_cage", 1)  # fortress
	assert_str(BuildSignature.of(w)).is_equal("pistol+bullet+gunline")  # bullet 3, gunline 2, fortress 1


func test_equal_tags_go_by_name() -> void:
	VarietyHKit.hold(w, &"reinforced_cage", 1)  # fortress
	VarietyHKit.hold(w, &"emp_capacitor", 1)  # tempo, arc
	assert_str(BuildSignature.of(w)).is_equal("pistol+arc+fortress")


func test_a_build_with_one_tag_has_a_shorter_signature() -> void:
	VarietyHKit.hold(w, &"reinforced_cage", 2)
	assert_str(BuildSignature.of(w)).is_equal("pistol+fortress")
	assert_array(BuildSignature.top_tags(w)).is_equal(["fortress"])


func test_without_damage_figures_the_primary_weapon_is_the_best_carried() -> void:
	VarietyHKit.carry(w, 1, &"scattergun")
	assert_str(BuildSignature.of(w)).is_equal("scattergun")
	VarietyHKit.carry(w, 0, &"rail_lance")
	assert_str(BuildSignature.of(w)).is_equal("rail_lance")
	VarietyHKit.carry(w, 1, &"arc_projector", 1)
	VarietyHKit.carry(w, 0, &"arc_projector", 2)  # the same tier: the higher level leads
	assert_int(BuildSignature.primary_weapon(w)).is_equal(Ids.WP_ARC_PROJECTOR)


func test_a_weapon_bought_in_the_legacy_shop_counts() -> void:
	w.warden.weapon_index = Ids.WP_SMG  # the legacy SMG upgrade changes the Warden's weapon, not the arsenal stub
	assert_str(BuildSignature.of(w)).is_equal("smg")


func test_the_tally_names_the_weapon_that_dealt_the_most() -> void:
	var tally: WeaponDamageTally = WeaponDamageTally.new()
	w.warden.weapon_index = Ids.WP_PISTOL
	tally.feed(w, [_damage(DamageSource.Id.WARDEN, 100.0)])
	w.warden.weapon_index = Ids.WP_LMG
	tally.feed(w, [_damage(DamageSource.Id.WARDEN, 60.0), _damage(DamageSource.Id.WARDEN, 70.0)])
	assert_int(tally.primary()).is_equal(Ids.WP_LMG)
	assert_float(tally.damage[Ids.WP_PISTOL]).is_equal(100.0)
	assert_float(tally.damage[Ids.WP_LMG]).is_equal(130.0)
	assert_str(BuildSignature.of(w, tally)).is_equal("lmg")


func test_turrets_strikes_and_hazards_are_nobodys_weapon() -> void:
	var tally: WeaponDamageTally = WeaponDamageTally.new()
	tally.feed(
		w,
		[
			_damage(DamageSource.Id.TURRET_0, 500.0), _damage(DamageSource.Id.STRIKE, 500.0), _damage(DamageSource.Id.HAZARD, 500.0),
			_damage(DamageSource.Id.CORE, 500.0),
		]
	)
	assert_int(tally.primary()).is_equal(-1)
	assert_str(BuildSignature.of(w, tally)).is_equal("pistol")  # nothing dealt: the carried weapon stands in


func test_the_off_hand_hits_belong_to_the_holstered_weapon() -> void:
	VarietyHKit.carry(w, 1, &"smg")
	w.arsenal.active = 0
	var tally: WeaponDamageTally = WeaponDamageTally.new()
	tally.feed(w, [_damage(DamageSource.Id.WARDEN_OFFHAND, 40.0)])
	assert_float(tally.damage[Ids.WP_SMG]).is_equal(40.0)


func test_a_tie_goes_to_the_lower_weapon_index() -> void:
	var tally: WeaponDamageTally = WeaponDamageTally.new()
	w.warden.weapon_index = Ids.WP_SMG
	tally.feed(w, [_damage(DamageSource.Id.WARDEN, 50.0)])
	w.warden.weapon_index = Ids.WP_PISTOL
	tally.feed(w, [_damage(DamageSource.Id.WARDEN, 50.0)])
	assert_int(tally.primary()).is_equal(Ids.WP_PISTOL)
