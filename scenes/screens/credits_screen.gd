extends Control
## Credits / about.

const P := preload("res://scenes/ui/palette.gd")
const Version := preload("res://core/version.gd")

const LINES := [
	["ROULETTER", "A roulette roguelite. The wheel is always fair; the felt is what you build."],
	["BUILT WITH", "Godot Engine (godotengine.org), MIT licence"],
	["FONTS", "Silkscreen by Jason Kottke  -  Press Start 2P by CodeMan38  -  SIL Open Font License"],
	["MUSIC & SOUND", "Synthesised in code at runtime: the lounge band, its Enforcer cousin, every chip and coin"],
	["ART", "Every sprite, portrait and wheel is drawn procedurally in pixels"],
	["THANKS", "To everyone who has ever been almost even with the house"],
]

## Your name for the credits (left blank until you fill it in).
const CREATOR := ""

var main


func setup() -> void:
	P.place(P.label(self, "CREDITS", P.FONT_BIG, P.GOLD), Vector2(16, 8))
	var y := 50
	var lines: Array = LINES.duplicate()
	if CREATOR != "":
		lines.insert(1, ["DESIGN & DIRECTION", CREATOR])
	for l in lines:
		P.place(P.label(self, l[0], P.FONT, P.GOLD), Vector2(32, y))
		var b := P.label(self, l[1], P.FONT_SMALL, P.CREAM)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		P.place(b, Vector2(32, y + 13), Vector2(576, 20))
		y += 36
	P.place(P.label(self, "Version " + Version.label(), P.FONT_SMALL, P.DIM), Vector2(32, y + 4))
	P.place(P.button(self, "Back", func(): main.show_screen("options"), Vector2(80, 22)), Vector2(16, 326))


func refresh() -> void:
	pass
