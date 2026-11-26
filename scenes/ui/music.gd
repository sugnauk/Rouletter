extends RefCounted
## Procedural lounge music, synthesised once into looping AudioStreamWAVs (no audio files):
##   "lounge"   - a swung ii-V-I-vi in C: walking bass, soft comped chords, brushes, a vibe melody
##   "enforcer" - the same band, darker: minor key, faster, a pedal bass and a stalking riff
## A file at res://audio/music_<track>.ogg (or .wav) replaces the synthesised version.

const RATE := 11025          ## music is mellow; half rate keeps synthesis quick, even on the web

## [root midi, chord intervals] per bar.
const LOUNGE_BARS := [[50, [0, 3, 7, 10]], [55, [0, 4, 7, 10]], [48, [0, 4, 7, 11]], [57, [0, 3, 7, 10]],
	[50, [0, 3, 7, 10]], [55, [0, 4, 7, 10]], [52, [0, 3, 7, 10]], [57, [0, 4, 7, 10]]]
const ENFORCER_BARS := [[45, [0, 3, 7, 10]], [45, [0, 3, 7, 10]], [41, [0, 4, 7, 11]], [40, [0, 4, 7, 10]],
	[45, [0, 3, 7, 10]], [43, [0, 4, 7, 10]], [41, [0, 4, 7, 11]], [40, [0, 4, 7, 10]]]
## Vibraphone melody, one note per beat (midi, 0 = rest), 8 bars x 4 beats.
const LOUNGE_MELODY := [77, 0, 74, 72, 74, 0, 71, 0, 72, 76, 79, 0, 76, 0, 72, 0,
	77, 0, 74, 72, 71, 74, 77, 0, 76, 0, 74, 72, 73, 0, 0, 0]
const ENFORCER_MELODY := [69, 0, 72, 0, 76, 75, 0, 0, 69, 0, 72, 0, 71, 0, 68, 0,
	69, 0, 72, 0, 76, 79, 0, 77, 76, 0, 72, 0, 68, 0, 0, 0]


static func load_track(track: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var path := "res://audio/music_%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			var st = load(path)
			if st is AudioStreamOggVorbis:
				st.loop = true
			return st
	return synth(track)


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func synth(track: String) -> AudioStreamWAV:
	var tense := track == "enforcer"
	var bpm := 112.0 if tense else 92.0
	var beat := 60.0 / bpm
	var bars: Array = ENFORCER_BARS if tense else LOUNGE_BARS
	var melody: Array = ENFORCER_MELODY if tense else LOUNGE_MELODY
	var n := int(bars.size() * 4 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var swing := beat * (2.0 / 3.0)   # the "and" of a swung beat
	for b in range(bars.size()):
		var root: int = bars[b][0]
		var iv: Array = bars[b][1]
		var t0 := b * 4 * beat
		# Bass: walking quarter notes (lounge) or a pulsing pedal (enforcer).
		for q in range(4):
			var note: int = root - 12
			if not tense:
				note = root - 12 + [0, iv[1], iv[2], iv[2] + 2 if q == 3 else iv[1]][q]
				if q == 3:
					var nxt: int = bars[(b + 1) % bars.size()][0] - 12
					note = nxt + (1 if nxt < root - 12 else -1)  # chromatic approach to the next root
			_pluck(s, t0 + q * beat, beat * 0.9, _hz(note), 0.32, 2.0)
			if tense:
				_pluck(s, t0 + q * beat + swing, beat * 0.3, _hz(note), 0.2, 4.0)
		# Comping: soft chord stabs on 2 and the "and" of 3 (lounge), long pads (enforcer).
		var hits := [[beat, beat * 0.45], [2 * beat + swing, beat * 0.5]] if not tense else [[0.0, beat * 3.8]]
		for h in hits:
			for k in iv:
				_pad(s, t0 + h[0], h[1], _hz(root + 12 + k), 0.05 if not tense else 0.04)
		# Brushes on 2 and 4, a ride on every swung "and".
		for q in range(4):
			if q % 2 == 1:
				_hiss(s, t0 + q * beat, 0.12, 0.10, b * 4 + q)
			_hiss(s, t0 + q * beat + swing, 0.05, 0.04, b * 4 + q + 99)
		# Melody: a soft vibraphone (sine + octave shimmer).
		for q in range(4):
			var m: int = melody[(b * 4 + q) % melody.size()]
			if m > 0:
				_vibe(s, t0 + q * beat, beat * 1.4, _hz(m), 0.10)
	# Gentle soft-clip and fade the seam so the loop is click-free.
	for i in range(n):
		s[i] = tanh(s[i] * 1.2) * 0.8
	var fade := int(0.02 * RATE)
	for i in range(fade):
		s[i] *= float(i) / fade
		s[n - 1 - i] *= float(i) / fade
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## A plucked upright-bass-ish tone: sine with a little second harmonic and a fast decay.
static func _pluck(s: PackedFloat32Array, start: float, dur: float, f: float, amp: float, decay: float) -> void:
	var i0 := int(start * RATE)
	var m := mini(int(dur * RATE), s.size() - i0)
	var ph := 0.0
	for i in range(m):
		ph += f / RATE
		var env := exp(-decay * float(i) / RATE) * minf(1.0, i / 30.0)
		s[i0 + i] += (sin(ph * TAU) + 0.3 * sin(ph * TAU * 2.0)) * amp * env


## A soft electric-piano chord voice.
static func _pad(s: PackedFloat32Array, start: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var m := mini(int(dur * RATE), s.size() - i0)
	var ph := 0.0
	for i in range(m):
		ph += f / RATE
		var k := float(i) / m
		var env := minf(1.0, i / 120.0) * (1.0 - k) * (1.0 - k * 0.5)
		s[i0 + i] += (sin(ph * TAU) + 0.25 * sin(ph * TAU * 3.0)) * amp * env


## Vibraphone: a pure tone with a shimmering octave and tremolo.
static func _vibe(s: PackedFloat32Array, start: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var m := mini(int(dur * RATE), s.size() - i0)
	var ph := 0.0
	for i in range(m):
		ph += f / RATE
		var t := float(i) / RATE
		var env := exp(-2.2 * t) * minf(1.0, i / 20.0) * (0.85 + 0.15 * sin(t * TAU * 5.5))
		s[i0 + i] += (sin(ph * TAU) + 0.2 * sin(ph * TAU * 4.0)) * amp * env


## Brushed snare / ride: filtered noise bursts.
static func _hiss(s: PackedFloat32Array, start: float, dur: float, amp: float, seed_in: int) -> void:
	var i0 := int(start * RATE)
	var m := mini(int(dur * RATE), s.size() - i0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in * 7919 + 13
	var prev := 0.0
	for i in range(m):
		var v := rng.randf_range(-1.0, 1.0)
		var hp := v - prev  # crude high-pass so it sounds like brushes, not rumble
		prev = v
		s[i0 + i] += hp * amp * pow(1.0 - float(i) / m, 2.0)
