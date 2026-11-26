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
var sfx_volume := 1.0           ## 0..1, from Options
var music_volume := 0.6         ## 0..1, from Options
var music: AudioStreamPlayer
var tension_player: AudioStreamPlayer
var tension := 0.0            ## 0..1 target for the tension layer (set by the table)
var _tension_now := 0.0
var _tracks: Dictionary = {}
var current_track := ""

const Music := preload("res://scenes/ui/music.gd")
const SFX_DB := -8.0
const MUSIC_DB := -10.0


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_DB
	add_child(music)
	tension_player = AudioStreamPlayer.new()
	tension_player.volume_db = -80.0
	add_child(tension_player)


## How tight the table is (0 calm .. 1 last ball / payment within reach). Fades smoothly.
func set_tension(level: float) -> void:
	tension = clampf(level, 0.0, 1.0)


func _process(delta: float) -> void:
	if tension_player == null or tension_player.stream == null:
		return
	_tension_now = move_toward(_tension_now, tension, delta * 0.8)
	var lin := _tension_now * music_volume
	tension_player.volume_db = MUSIC_DB + linear_to_db(maxf(0.0001, lin)) if lin > 0.001 else -80.0


## Switch the background loop ("lounge" / "enforcer"), synthesising it the first time.
func play_music(track: String) -> void:
	if track == current_track or music == null:
		return
	current_track = track
	if not _tracks.has(track):
		_tracks[track] = Music.load_track(track)
	music.stream = _tracks[track]
	var tk := track + "_tension"
	if not _tracks.has(tk):
		_tracks[tk] = Music.synth(tk)
	tension_player.stream = _tracks[tk]
	_apply_music_volume()
	if music_volume > 0.0:
		music.play()
		tension_player.play()  # started together so the layer stays in time


## Synthesise a track ahead of time so switching to it later doesn't hitch.
func preload_track(track: String) -> void:
	if not _tracks.has(track):
		_tracks[track] = Music.load_track(track)
	if not _tracks.has(track + "_tension"):
		_tracks[track + "_tension"] = Music.synth(track + "_tension")


func set_volumes(music_v: float, sfx_v: float) -> void:
	music_volume = clampf(music_v, 0.0, 1.0)
	sfx_volume = clampf(sfx_v, 0.0, 1.0)
	_apply_music_volume()
	for pool in _pools.values():
		for p in pool:
			p.volume_db = SFX_DB + linear_to_db(maxf(0.0001, sfx_volume))


func _apply_music_volume() -> void:
	if music == null:
		return
	music.volume_db = MUSIC_DB + linear_to_db(maxf(0.0001, music_volume))
	if music_volume <= 0.0:
		music.stop()
		tension_player.stop()
	elif not music.playing and music.stream != null:
		music.play()
		tension_player.play()


func play(cue: String, pitch: float = 1.0) -> void:
	if muted or sfx_volume <= 0.0:
		return
	if not _pools.has(cue):
		var stream := _load_or_synth(cue)
		var pool := []
		if stream != null:
			for i in range(VOICES):
				var p := AudioStreamPlayer.new()
				p.stream = stream
				p.volume_db = SFX_DB + linear_to_db(maxf(0.0001, sfx_volume))
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
	if cue.begins_with("enforcer:"):
		_enforcer_sting(s, cue.substr(9))
		return _to_wav(s)
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
		"stack":
			# Two chips clacking together, then a rising chirp: a level-up.
			_noise(s, 0.0, 0.02, 0.5)
			_tone(s, 0.0, 0.05, 2400.0, 0.3, "sine")
			_noise(s, 0.06, 0.02, 0.45)
			_tone(s, 0.06, 0.05, 2600.0, 0.3, "sine")
			_tone(s, 0.12, 0.18, 1046.5, 0.25, "square", 1568.0)
		"refund":
			# Chips sliding back to the stack.
			_noise(s, 0.0, 0.08, 0.25)
			_tone(s, 0.0, 0.12, 1600.0, 0.2, "sine", 1000.0)
		"clear_all":
			# A sweep of chips off the felt.
			for i in range(5):
				_noise(s, i * 0.025, 0.03, 0.35 - i * 0.05)
			_tone(s, 0.0, 0.25, 1800.0, 0.18, "sine", 700.0)
		"undo":
			_tone(s, 0.0, 0.06, 1200.0, 0.22, "square")
			_tone(s, 0.05, 0.08, 900.0, 0.18, "square")
		"sting":
			# A brassy two-chord stab for exceptional moments.
			for f in [523.3, 659.3, 784.0]:
				_tone(s, 0.0, 0.18, f, 0.2, "square")
			for f in [698.5, 880.0, 1046.5, 1396.9]:
				_tone(s, 0.16, 0.7, f, 0.18, "square")
			_noise(s, 0.16, 0.12, 0.25)
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


## Every Enforcer gets their own short motif, worked out from their name: a low stab, then
## four notes from a dark scale (minor, phrygian or diminished, also picked by the name).
static func _enforcer_sting(s: Array, who: String) -> void:
	var h: int = absi(who.hash())
	var scales := [[0, 2, 3, 5, 7, 8, 10], [0, 1, 3, 5, 7, 8, 10], [0, 2, 3, 5, 6, 8, 9, 11]]
	var sc: Array = scales[h % scales.size()]
	var root: float = 110.0 * pow(2.0, float((h / 7) % 5) / 12.0)
	var wave := "square"
	# The stab: root + fifth + minor third, low, with a hit of noise.
	for iv in [0, 3, 7]:
		_tone(s, 0.0, 0.32, root * pow(2.0, iv / 12.0), 0.16, wave)
	_noise(s, 0.0, 0.1, 0.35)
	var t := 0.34
	for i in range(4):
		var step: int = sc[(h / int(pow(3, i + 1))) % sc.size()]
		var f: float = root * 2.0 * pow(2.0, step / 12.0)
		var dur: float = [0.12, 0.18, 0.12, 0.45][i]
		_tone(s, t, dur, f, 0.22, "square")
		_tone(s, t, dur, f * 0.5, 0.08, "sine")
		t += dur + 0.02
	_tone(s, t - 0.47, 0.6, root, 0.12, "sine", root * 0.94)


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

