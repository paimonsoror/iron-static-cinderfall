class_name AudioLoopPad
extends RefCounted
## Makes a looping WAV safe for Godot's mixer. When a looping stream wraps, the mixer's interpolation reads a few frames
## past `loop_end`. With the loop end at the very end of the data that read leaves the buffer: on a phone (hardened
## allocator) it is a SIGSEGV in the audio thread, 16 s into a run, at the second wrap of the 8 s combat drone loop (the
## desktop reads garbage silently). Appending the first frames of the loop behind the loop end makes the read valid and
## keeps the wrap seamless (those frames are exactly what the loop plays next).

const PAD_FRAMES: int = 256  ## frames of the loop start copied behind the loop end


## A looping copy of `wav` for a held voice (AudioHeldVoices): a one-shot sound loops over its whole length, a stream that
## already loops keeps its loop points, and the copy is padded like every loop. The shared source resource is never
## touched. Only 8 and 16 bit PCM can be looped here; any other format comes back as a plain copy that plays once.
static func looped_copy(wav: AudioStreamWAV) -> AudioStreamWAV:
	var copy: AudioStreamWAV = wav.duplicate() as AudioStreamWAV
	var width: int = 2 if copy.format == AudioStreamWAV.FORMAT_16_BITS else (1 if copy.format == AudioStreamWAV.FORMAT_8_BITS else 0)
	if width == 0:
		return copy
	if copy.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = floori(float(copy.data.size()) / float(width * (2 if copy.stereo else 1)))
	@warning_ignore("return_value_discarded")
	pad(copy)
	return copy


## Pads `wav` once. True when data was appended. Only 8 and 16 bit PCM loops are handled (the beds are 16 bit mono);
## a stream that does not loop, or whose data already extends far enough, is left alone.
static func pad(wav: AudioStreamWAV) -> bool:
	if wav == null or wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		return false
	var width: int = 0
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		width = 2
	elif wav.format == AudioStreamWAV.FORMAT_8_BITS:
		width = 1
	if width == 0:
		return false
	var frame_bytes: int = width * (2 if wav.stereo else 1)
	var data: PackedByteArray = wav.data
	var want: int = (wav.loop_end + PAD_FRAMES) * frame_bytes
	var have: int = data.size()
	if have >= want or wav.loop_begin < 0 or (wav.loop_begin + PAD_FRAMES) * frame_bytes > have:
		return false
	var from: int = wav.loop_begin * frame_bytes + (have - wav.loop_end * frame_bytes)
	var count: int = want - have
	data.append_array(data.slice(from, from + count))
	wav.data = data
	return true
