extends Node
## Autoload "Sfx": named sound cues. A file at res://audio/<cue>.wav or .ogg wins if present;
## otherwise the cue is synthesised in code as a retro chip-tune sound, so the game always has audio.
## play(cue, pitch): pitch lets the scoring count rise note by note.

const RATE := 22050
const VOICES := 4

var _streams: Dictionary = {}
var _pools: Dictionary = {}
var _next: Dictionary = {}
var muted := false


func play(cue: String, pitch: float = 1.0) -> void:
	if muted:
		return
	if not _pools.has(cue):
		var stream := _load_or_synth(cue)
		var pool := []
		if stream != null:
			for i in range(VOICES):
				var p := AudioStreamPlayer.new()
				p.stream = stream
				p.volume_db = -8.0
				add_child(p)
				pool.append(p)
		_pools[cue] = pool
		_next[cue] = 0
	var pool: Array = _pools[cue]
	if pool.is_empty():
		return
	var p: AudioStreamPlayer = pool[_next[cue]]
	_next[cue] = (_next[cue] + 1) % pool.size()
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()


func _load_or_synth(cue: String) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "res://audio/%s.%s" % [cue, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return synth(cue)


## --- Synthesis ------------------------------------------------------------------------

static func synth(cue: String) -> AudioStreamWAV:
	var s := []
	match cue:
		"click":
			_tone(s, 0.0, 0.03, 1400.0, 0.25, "square")
		"chip_place":
			_noise(s, 0.0, 0.02, 0.5)
			_tone(s, 0.0, 0.05, 2400.0, 0.3, "sine")
			_tone(s, 0.02, 0.05, 1800.0, 0.2, "sine")
		"chip_remove":
			_noise(s, 0.0, 0.02, 0.35)
			_tone(s, 0.0, 0.05, 1300.0, 0.25, "sine")
		"spin":
			# The ball ticking over the frets, slowing down.
			var tt := 0.0
			var gap := 0.03
			while tt < 1.8:
				_noise(s, tt, 0.008, 0.35)
				_tone(s, tt, 0.012, 3200.0, 0.15, "square")
				tt += gap
				gap *= 1.045
		"ball_drop":
			for i in range(3):
				_noise(s, i * 0.07, 0.02, 0.45 - i * 0.1)
				_tone(s, i * 0.07, 0.03, 2600.0 - i * 300.0, 0.2, "sine")
		"win":
			_tone(s, 0.0, 0.25, 1318.5, 0.35, "sine")
			_tone(s, 0.03, 0.3, 1975.5, 0.25, "sine")
		"big_win":
			var notes := [523.3, 659.3, 784.0, 1046.5, 1318.5]
			for i in range(notes.size()):
				_tone(s, i * 0.07, 0.3, notes[i], 0.28, "square")
		"mult":
			_tone(s, 0.0, 0.12, 440.0, 0.3, "square")
			_tone(s, 0.0, 0.12, 880.0, 0.2, "square")
			_noise(s, 0.0, 0.05, 0.3)
		"lose":
			_tone(s, 0.0, 0.14, 180.0, 0.35, "square", 120.0)
		"cash":
			_tone(s, 0.0, 0.1, 2093.0, 0.3, "sine")
			_tone(s, 0.06, 0.18, 2637.0, 0.3, "sine")
		"buy":
			_noise(s, 0.0, 0.05, 0.4)
			_tone(s, 0.04, 0.12, 1568.0, 0.3, "square")
			_tone(s, 0.1, 0.25, 2093.0, 0.3, "sine")
		"clear":
			var fan := [523.3, 659.3, 784.0, 659.3, 784.0, 1046.5]
			for i in range(fan.size()):
				_tone(s, i * 0.09, 0.22 if i < fan.size() - 1 else 0.6, fan[i], 0.3, "square")
		"jackpot":
			# A rising run, a held chord and a shower of high sparkles.
			var run := [523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0, 2093.0]
			for i in range(run.size()):
				_tone(s, i * 0.05, 0.25, run[i], 0.24, "square")
			for f in [1046.5, 1318.5, 1568.0]:
				_tone(s, 0.4, 0.9, f, 0.18, "square")
			for i in range(10):
				_tone(s, 0.45 + i * 0.07, 0.08, 2600.0 + (i % 3) * 400.0, 0.12, "sine")
		"feat":
			# A bright two-bell chime.
			_tone(s, 0.0, 0.5, 1568.0, 0.3, "sine")
			_tone(s, 0.0, 0.5, 3136.0, 0.1, "sine")
			_tone(s, 0.12, 0.7, 2093.0, 0.3, "sine")
			_tone(s, 0.12, 0.7, 4186.0, 0.08, "sine")
		"near":
			# So close: a falling slide.
			_tone(s, 0.0, 0.35, 660.0, 0.28, "square", 330.0)
		"unlock":
			var up := [392.0, 523.3, 659.3, 784.0, 1046.5]
			for i in range(up.size()):
				_tone(s, i * 0.06, 0.2 if i < up.size() - 1 else 0.7, up[i], 0.28, "square")
			_noise(s, 0.3, 0.2, 0.2)
		"bust":
			var down := [392.0, 349.2, 311.1, 233.1]
			for i in range(down.size()):
				_tone(s, i * 0.16, 0.3 if i < 3 else 0.7, down[i], 0.3, "square")
		_:
			return null
	return _to_wav(s)


static func _ensure(s: Array, n: int) -> void:
	while s.size() < n:
		s.append(0.0)


static func _tone(s: Array, start: float, dur: float, freq: float, amp: float, wave: String, end_freq: float = -1.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	_ensure(s, i0 + n)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / n
		var f := freq if end_freq < 0.0 else lerpf(freq, end_freq, k)
		phase += f / RATE
		var v := sin(phase * TAU) if wave == "sine" else (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.6
		var env := minf(1.0, i / 60.0) * pow(1.0 - k, 2.0)
		s[i0 + i] += v * amp * env


static func _noise(s: Array, start: float, dur: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	_ensure(s, i0 + n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start * 1000) + 17
	for i in range(n):
		s[i0 + i] += rng.randf_range(-1.0, 1.0) * amp * pow(1.0 - float(i) / n, 3.0)


static func _to_wav(s: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in range(s.size()):
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

