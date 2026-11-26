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
## The victory theme: the lounge band in a bright major key, brisk, with a rising horn line.
const VICTORY_BARS := [[48, [0, 4, 7, 11]], [53, [0, 4, 7, 11]], [50, [0, 3, 7, 10]], [55, [0, 4, 7, 10]],
	[48, [0, 4, 7, 11]], [57, [0, 3, 7, 10]], [53, [0, 4, 7, 11]], [55, [0, 4, 7, 10]]]
const VICTORY_MELODY := [72, 76, 79, 0, 84, 0, 79, 76, 77, 81, 84, 0, 83, 0, 79, 0,
	76, 79, 84, 0, 88, 0, 84, 81, 81, 84, 89, 0, 86, 0, 0, 0]
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


## The tension layer: a heartbeat kick and a ticking clock, in time with `base` ("lounge" or
## "enforcer") and the same length, so it can be faded in on top while the table gets tight.
static func synth_tension(base: String) -> AudioStreamWAV:
	var tense := base == "enforcer"
	var victory := base == "victory"
	var bpm := 112.0 if tense else (124.0 if victory else 92.0)
	var beat := 60.0 / bpm
	var bars: Array = ENFORCER_BARS if tense else (VICTORY_BARS if victory else LOUNGE_BARS)
	var n := int(bars.size() * 4 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for q in range(bars.size() * 4):
		var t0 := q * beat
		# Heartbeat: a low double thump on every beat.
		_pluck(s, t0, 0.18, 55.0, 0.5, 14.0)
		_pluck(s, t0 + 0.16, 0.14, 52.0, 0.32, 16.0)
		# Clock: a dry tick on every eighth.
		for k in range(2):
			var tt := t0 + k * beat / 2.0
			_vibe(s, tt, 0.04, 2600.0 if k == 0 else 2100.0, 0.05)
		# A rising pedal note across each bar, for unease.
		if q % 4 == 0:
			var root: int = bars[(q / 4) % bars.size()][0]
			_pad(s, t0, beat * 4.0, _hz(root + 13), 0.035)
	return _finish(s)


static func synth(track: String) -> AudioStreamWAV:
	if track.ends_with("_tension"):
		return synth_tension(track.trim_suffix("_tension"))
	var tense := track == "enforcer"
	var victory := track == "victory"
	var bpm := 112.0 if tense else (124.0 if victory else 92.0)
	var beat := 60.0 / bpm
	var bars: Array = ENFORCER_BARS if tense else (VICTORY_BARS if victory else LOUNGE_BARS)
	var melody: Array = ENFORCER_MELODY if tense else (VICTORY_MELODY if victory else LOUNGE_MELODY)
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
				if victory:   # a horn doubling the tune an octave down
					_pad(s, t0 + q * beat, beat * 0.9, _hz(m - 12), 0.06)
	return _finish(s)


## Soft-clip, fade the loop seam and pack into a looping 16-bit WAV.
static func _finish(s: PackedFloat32Array) -> AudioStreamWAV:
	var n := s.size()
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
