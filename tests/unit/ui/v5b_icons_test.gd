extends GdUnitTestSuite
## V5-B: the six kits have six distinct marks (original SVGs, 128 x 128 like the weapon set), and an Archive kit row shows its own.

const KITS: Array[String] = ["standard", "breacher", "signal", "gunline", "ledger", "gambler"]


func test_every_kit_has_its_own_icon_file_that_loads() -> void:
	var seen: Dictionary[String, bool] = {}
	for kit: String in KITS:
		var path: String = "res://assets/icons/kit_%s.svg" % kit
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
		var tex: Texture2D = load(path) as Texture2D
		assert_object(tex).is_not_null()
		assert_int(tex.get_width()).is_equal(128)
		assert_int(tex.get_height()).is_equal(128)
		var text: String = FileAccess.get_file_as_string(path)
		assert_bool(seen.has(text)).is_false()
		seen[text] = true


func test_an_archive_kit_row_shows_its_own_mark_not_the_core_ring() -> void:
	var cs: ContentSet = Content.db
	var marks: Dictionary[String, bool] = {}
	for def: UnlockDef in cs.unlocks:
		if def.branch != UnlockDef.Branch.KITS:
			continue
		var mark: String = ArchiveRow.mark_icon(def, cs)
		assert_str(mark).is_not_equal("cat_core")
		assert_str(mark).is_equal("kit_%s" % String(def.grants[0]).trim_prefix("k_"))
		assert_bool(marks.has(mark)).is_false()
		marks[mark] = true
	assert_int(marks.size()).is_greater(0)
