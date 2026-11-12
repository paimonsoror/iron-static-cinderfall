extends GdUnitTestSuite
## EnvTex (W3-E): the generated floor tile is deterministic (same bytes on every run, a pinned checksum), tileable, and has the
## channels the floor shader reads (grain, cracks, blotches, breakup).

## FNV-1a of the mip 0 bytes (EnvTex.checksum). Changing the generator changes this number on purpose: update it with the textures.
const CHECKSUM: int = 0


func test_size_format_and_mipmaps() -> void:
	var img: Image = EnvTex.image()
	assert_int(img.get_width()).is_equal(EnvTex.SIZE)
	assert_int(img.get_height()).is_equal(EnvTex.SIZE)
	assert_int(img.get_format()).is_equal(Image.FORMAT_RGBA8)
	assert_bool(img.has_mipmaps()).is_true()


func test_two_builds_are_byte_identical() -> void:
	var a: PackedByteArray = EnvTex.image().get_data()
	var b: PackedByteArray = EnvTex.image().get_data()
	assert_bool(a == b).is_true()
	assert_int(EnvTex.checksum()).is_equal(EnvTex.checksum())


func test_checksum_is_pinned() -> void:
	assert_int(EnvTex.checksum()).override_failure_message("EnvTex checksum is %d" % EnvTex.checksum()).is_equal(CHECKSUM)


func test_the_texture_is_shared() -> void:
	assert_object(EnvTex.texture()).is_same(EnvTex.texture())


func test_channels_carry_what_the_shader_reads() -> void:
	var data: PackedByteArray = EnvTex.image().get_data()
	var n: int = EnvTex.SIZE * EnvTex.SIZE
	var grain: float = 0.0
	var cracks: int = 0
	var blotch_min: int = 255
	var blotch_max: int = 0
	var fine_min: int = 255
	var fine_max: int = 0
	for i: int in n:
		grain += float(data[i * 4])
		if data[i * 4 + 1] > 100:
			cracks += 1
		blotch_min = mini(blotch_min, data[i * 4 + 2])
		blotch_max = maxi(blotch_max, data[i * 4 + 2])
		fine_min = mini(fine_min, data[i * 4 + 3])
		fine_max = maxi(fine_max, data[i * 4 + 3])
	assert_float(grain / float(n)).is_between(100.0, 156.0)
	assert_float(float(cracks) / float(n)).is_between(0.01, 0.12)
	assert_int(blotch_max - blotch_min).is_greater(90)
	assert_int(fine_max - fine_min).is_greater(90)


func test_the_noise_channels_wrap_without_a_seam() -> void:
	var data: PackedByteArray = EnvTex.image().get_data()
	var size: int = EnvTex.SIZE
	var worst: int = 0
	for y: int in size:
		var edge: int = absi(int(data[(y * size) * 4 + 2]) - int(data[(y * size + size - 1) * 4 + 2]))
		worst = maxi(worst, edge)
	for x: int in size:
		var edge2: int = absi(int(data[x * 4 + 2]) - int(data[((size - 1) * size + x) * 4 + 2]))
		worst = maxi(worst, edge2)
	assert_int(worst).override_failure_message("blotch jump across the wrap: %d" % worst).is_less(24)
