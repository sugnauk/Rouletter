extends RefCounted
## Procedural pixel art: casino chips, item icons, plaques. Everything is drawn with integer
## rects/circles onto any CanvasItem, so it stays crisp at the 640x360 base resolution.

const P := preload("res://scenes/ui/palette.gd")


## A casino chip: rim with edge spots, inner inlay, optional icon or value.
static func chip(ci: CanvasItem, c: Vector2, rad: float, col: Color, kind: String = "", value: int = 0, frozen: bool = false) -> void:
	c = c.round()
	ci.draw_circle(c + Vector2(0, 1), rad, col.darkened(0.55), true, -1.0, false)
	ci.draw_circle(c, rad, col, true, -1.0, false)
	# Edge spots: the stripes every real chip has.
	var spots := 6 if rad >= 5.0 else 4
	for i in range(spots):
		var a := TAU * i / spots + PI / spots
		var p := (c + Vector2(cos(a), sin(a)) * (rad - 1.2)).round()
		var spot: Color = P.CREAM if col.get_luminance() < 0.75 else P.RED
		if kind != "" and kind != "bet":   # items have gold edge spots, money has cream ones
			spot = P.GOLD if col.get_luminance() < 0.6 else P.WOOD_DARK
		ci.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), spot)
	var has_face: bool = kind != "" and kind != "bet" and MINI.has(kind) and rad >= 5.0
	var big: bool = rad >= 9.5   # big chips show their picture at double size
	var inlay: float = rad * (0.74 if big and has_face else 0.66)
	# An item's inlay is dark so its picture reads on any chip colour; a bet's stays light.
	ci.draw_circle(c, inlay, col.darkened(0.6) if has_face else col.darkened(0.18), true, -1.0, false)
	ci.draw_circle(c, inlay, col.lightened(0.35), false, 1.0, false)
	if has_face:
		face(ci, kind, c, 2 if big else 1)
	if frozen:
		ci.draw_line(c - Vector2(rad, rad), c + Vector2(rad, rad), P.CYAN, 1.0, false)
		ci.draw_line(c + Vector2(-rad, rad), c + Vector2(rad, -rad), P.CYAN, 1.0, false)


## Denomination colours like a real casino.
static func denom_color(v: int) -> Color:
	if v >= 25:
		return Color("#2f9e44")
	if v >= 10:
		return Color("#1c7ed6")
	if v >= 5:
		return P.RED
	return P.CREAM


## Lettered tiles for items drawn as a label rather than a picture: [text, colour].
const GLYPHS := {
	"odd_fellow": ["OD", "#e9c46a"], "even_keel": ["EV", "#90e0ef"], "low_roller": ["LO", "#80ed99"],
	"penthouse": ["HI", "#f4a261"], "dozen_watch": ["DZ", "#cdb4db"], "pillar": ["CL", "#a8dadc"],
	"night_owl": ["OW", "#b5838d"], "piggy_bank": ["$", "#ffafcc"], "clover": ["4L", "#38b000"],
	"doorbell": ["DB", "#ffd166"], "prime_time": ["PR", "#e76f51"], "square_deal": ["SQ", "#4cc9f0"],
	"teen_idol": ["13", "#ff8fab"], "fibonacci": ["FB", "#c77dff"], "nickel": ["5", "#adb5bd"],
	"seventh_heaven": ["7", "#ffd166"], "last_digit": ["#", "#8ecae6"], "far_side": ["<>", "#f28482"],
	"seedling": ["SP", "#80ed99"], "golden_goose": ["EG", "#ffd166"], "heart_of_gold": ["<3", "#ef476f"],
	"spare_key": ["KY", "#2ec4b6"],
	"zero_tolerance": ["0!", "#2ec46a"], "bankroll": ["+1", "#90be6d"], "compound_interest": ["%", "#ffd166"],
	"double_down": ["x2", "#f4a261"], "corner_office": ["CO", "#cdb4db"], "big_spender": ["$$", "#57cc99"],
	"patron": ["VP", "#c77dff"], "late_bloomer": ["4+", "#ff8fab"], "veterans": ["L3", "#e9c46a"],
}


## Pixel sprites for items that used to be lettered tiles: 12 rows of 12 characters.
## Colours: see SPRITE_COLOURS ('.' is transparent).
const SPRITES := {
	"ivory_tower": [".....ww.....", "....wwww....", "....wkkw....", "....wwww....", "...wwwwww...", "...wwkkww...", "...wwwwww...", "...wwkkww...", "..wwwwwwww..", "..wwwkkwww..", "..wwwwwwww..", "dddddddddddd"],
	"standing_ovation": ["............", ".y...y...y..", "yyy.yyy.yyy.", ".y...y...y..", "............", "..pp.pp.pp..", ".pppppppppp.", ".pppppppppp.", "..pppppppp..", "..pp.pp.pp..", "..pp.pp.pp..", "............"],
	"house_odds": ["............", "GGGGGGGGGGGG", "GwwGGyyGGwwG", "GwwGGyyGGwwG", "GGGGGGGGGGGG", "GrrGGkkGGrrG", "GrrGGkkGGrrG", "GGGGGGGGGGGG", "....yyyy....", "...y....y...", "...y.yy.y...", "....yyyy...."],
	"odds_maker": ["............", "..yyyyyyyy..", ".yykkkkkkyy.", ".yk.rrrr.ky.", ".yk.r..r.ky.", ".yk.rrrr.ky.", ".yk.r..r.ky.", ".yk.r..r.ky.", ".yykkkkkkyy.", "..yyyyyyyy..", "....G..G....", "...GGGGGG..."],
	"keystone": ["....yyyy....", "...yggggy...", "..yggggggy..", "..ywwwwwwy..", "..yggggggy..", "..ywwwwwwy..", "..yggggggy..", "..ywwwwwwy..", "..yggggggy..", "..yyyyyyyy..", "............", "............"],
	"tall_stack": ["....rrrr....", "....wwww....", "....BBBB....", "....rrrr....", "....wwww....", "....BBBB....", "....rrrr....", "....wwww....", "....BBBB....", "....rrrr....", "...dddddd...", "............"],
	"wind_up": ["............", "....kkkk....", "...k.yy.k...", "..k.y..y.k..", "..k.y.yy.k..", "..k..yy..k..", "...k....k...", "....kkkk....", ".....kk.....", "....kkkk....", "...kk..kk...", "............"],
	"high_rise": [".....y......", ".....k......", "....kkk.....", "....kwk.....", "...kkkkk....", "...kwkwk....", "...kkkkk....", "..kkwkwkk...", "..kkkkkkk...", "..kwkwkwk...", "..kkkkkkk...", "dddddddddddd"],
	"encore": ["............", "..y......y..", "...y....y...", "....yyyy....", "...yGGGGy...", "..yGwwwwGy..", "..yGwwwwGy..", "...yGGGGy...", "....yyyy....", "...y....y...", "..y......y..", "............"],
	"second_wind": ["............", "..cccc......", ".c....c.....", "......c.....", "..ccccc.....", "...........c", "..cccccccccc", "...........c", "..cccccc....", ".c......c...", "..cccccc....", "............"],
	"even_stevens": ["....kkkk....", "..kkrrkkkk..", ".krrrrkkkkk.", ".krrrrkkkkk.", "krrrrrkkkkkk", "krrrrrkwkkkk", "krrrrwkkkkkk", "krrrrrkkkkkk", ".krrrrkkkkk.", ".krrrrkkkkk.", "..kkrrkkkk..", "....kkkk...."],
	"box_office": ["............", "yyyyyyyyyyyy", "yggggggggggy", "yg.kk.kk..gy", ".ygkk.kk.gy.", "..ygggggggy.", "..ygggggggy.", ".yg.yyyy.gy.", "yg..yyyy..gy", "yggggggggggy", "yyyyyyyyyyyy", "............"],
	"coin_purse": ["....bbbb....", "...b....b...", "..bbbbbbbb..", ".bbbbbbbbbb.", ".bbbyyyybbb.", "bbbyykkyybbb", "bbbyykyyybbb", "bbbyykkyybbb", "bbbbyyyybbbb", ".bbbbbbbbbb.", "..bbbbbbbb..", "............"],
	"streak_rider": ["............", "rr..kk..rr..", ".rr..kk..rr.", "..rr..kk..rr", "...rr..kk..r", "....rr..kk..", "....rr..kk..", "...rr..kk..r", "..rr..kk..rr", ".rr..kk..rr.", "rr..kk..rr..", "............"],
	"sals_whistle": ["............", "............", ".......dd...", "..ddddddwd..", ".dwwwwwwwd..", "dwwwwwwwwd..", "dwwkkwwwwd..", "dwwkkwwwwd..", ".dwwwwwwd...", "..dddddd....", "...r........", "..r........."],
	"oros_coin": ["....GGGG....", "..GGyyyyGG..", ".GyyGGGGyyG.", ".GyG....GyG.", "GyG..GG..GyG", "GyG.G..G.GyG", "GyG.G..G.GyG", "GyG..GG..GyG", ".GyG....GyG.", ".GyyGGGGyyG.", "..GGyyyyGG..", "....GGGG...."],
	"accountants_book": ["............", ".bbbbbbbbbb.", ".bwwwwwwwwkb", ".bwkkkkkkwkb", ".bwwwwwwwwkb", ".bwkkkkwwwkb", ".bwwwwwwwwkb", ".bwkkkkkkwkb", ".bwwwwwwyywb", ".bwwwwwwyywb", ".bbbbbbbbbbb", "............"],
	"velvet_rope": ["............", ".y........y.", "yyy......yyy", ".y........y.", ".yvv....vvy.", ".y.vvvvvv.y.", ".y........y.", ".y........y.", ".y........y.", ".y........y.", "yyy......yyy", "yyy......yyy"],
	"klines_watch": ["....dddd....", "...d....d...", "..dddddddd..", ".dkkkkkkkkd.", "dkkkwwwwkkkd", "dkkwwkwwwkkd", "dkkwwkkkwkkd", "dkkwwwwwwkkd", "dkkkwwwwkkkd", ".dkkkkkkkkd.", "..dddddddd..", "............"],
	"conductor": ["..........w.", ".........w..", "........w...", ".......w....", "......w.....", "..gg.w......", ".gyygg......", ".gyyyg......", ".gyyyg......", "..ggg.......", ".....rr.....", "....rrrr...."],
	"relay": ["............", ".cc.........", "cccc........", ".cc..c......", ".....cc.....", "cccccccc....", ".....cc.....", ".....c..cc..", ".......cccc.", "........cc..", "............", "............"],
	"fuse": [".........y..", "........yoy.", ".........o..", "........b...", ".......b....", "......b.....", "...kkkk.....", "..kkkkkk....", ".kkkkkkkk...", ".kkwkkkkk...", ".kkkkkkkk...", "..kkkkkk...."],
	"crowd_pleaser": ["............", ".w..w..w..w.", "www.www.www.", ".w..w..w..w.", "............", ".y.y.y.y.y.y", "............", "rrrrrrrrrrrr", "r..........r", "r.yyyyyyyy.r", "r..........r", "rrrrrrrrrrrr"],
	"purist": ["....wwww....", "..wwwwwwww..", ".wwkkkkkkww.", ".wwk....kww.", "wwk..rr..kww", "wwk.rrrr.kww", "wwk.rrrr.kww", "wwk..rr..kww", ".wwk....kww.", ".wwkkkkkkww.", "..wwwwwwww..", "....wwww...."],
	"high_stakes": ["............", "....rrrr....", "...rwrrwr...", "....rrrr....", "...bbbbbb...", "..bwbbbbwb..", "...bbbbbb...", "..gggggggg..", ".gywggggwyg.", "..gggggggg..", ".rrrrrrrrrr.", "............"],
	"odd_fellow": ["............", ".kkkkkkkkkk.", ".kwwwwwwwwk.", ".kwkkwwwwwk.", ".kwkkwwwwwk.", ".kwwwwkkwwk.", ".kwwwwkkwwk.", ".kwwwwwwkkk.", ".kwwwwwwkkk.", ".kwwwwwwwwk.", ".kkkkkkkkkk.", "............"],
	"even_keel": ["......k.....", "......kw....", "......kww...", "......kwww..", "......kwwww.", "......kwwwww", "......k.....", "bbbbbbbbbbbb", ".bbbbbbbbbb.", "..bbbbbbbb..", ".BBB.BBB.BBB", "BBBBBBBBBBBB"],
	"low_roller": ["....GGGG....", "....GGGG....", "....GGGG....", "....GGGG....", ".GGGGGGGGGG.", "..GGGGGGGG..", "...GGGGGG...", "....GGGG....", ".....GG.....", "............", "wwwwwwwwwwww", "dddddddddddd"],
	"penthouse": ["....yyyy....", "...kyyyyk...", "...kkkkkk...", "..kddddddk..", "..kdydydyk..", "..kddddddk..", "..kdydydyk..", "..kddddddk..", "..kdydydyk..", "..kddddddk..", "..kddkkddk..", "..kkkkkkkk.."],
	"dozen_watch": [".....gg.....", "....g..g....", "...gggggg...", "..gwwwwwwg..", ".gwwwkwwwwg.", ".gwwwkwwwwg.", ".gwwwkkkwwg.", ".gwwwwwwwwg.", ".gwwwwwwwwg.", "..gwwwwwwg..", "...gggggg...", "............"],
	"pillar": ["wwwwwwwwwwww", ".dddddddddd.", "..wwwwwwww..", "..wdwwdwwd..", "..wdwwdwwd..", "..wdwwdwwd..", "..wdwwdwwd..", "..wdwwdwwd..", "..wdwwdwwd..", "..wwwwwwww..", ".dddddddddd.", "wwwwwwwwwwww"],
	"night_owl": [".b........b.", ".bb......bb.", ".bbbbbbbbbb.", "bbwwbbbbwwbb", "bwykwbbwykwb", "bwkkwbbwkkwb", "bbwwbbbbwwbb", ".bbbboobbbb.", ".bbbb..bbbb.", ".bwbwbbwbwb.", "..bbbbbbbb..", "...yy..yy..."],
	"piggy_bank": [".....kk.....", "...pppppp...", "..pppppppppp", ".pppkppppppp", "pppppppppppo", "pppppppppppo", ".ppppppppppp", "..pppppppp..", "..pp....pp..", "..pp....pp..", "............", "............"],
	"clover": ["...GG..GG...", "..GGGGGGGG..", "..GGGGGGGG..", "...GGGGGG...", ".GG..GG..GG.", "GGGGGGGGGGGG", "GGGGGGGGGGGG", ".GG..GG..GG.", "...GGGGGG...", ".....bb.....", "....bb......", "...bb......."],
	"doorbell": [".....yy.....", "....yyyy....", "...yyyyyy...", "..yyyyywyy..", "..yyyyywyy..", "..yyyyyyyy..", "..yyyyyyyy..", ".yyyyyyyyyy.", "yyyyyyyyyyyy", "yyyyyyyyyyyy", ".....bb.....", "............"],
	"prime_time": ["...k....k...", "....k..k....", ".....kk.....", "kkkkkkkkkkkk", "kccccccccdkk", "kcwcccccckrk", "kcccccccckkk", "kccccccccdkk", "kccccccccdkk", "kkkkkkkkkkkk", ".kk......kk.", "............"],
	"square_deal": ["cccccccccccc", "c..........c", "c.........Gc", "c........GGc", "c.......GG.c", "cG.....GG..c", "cGG...GG...c", "c.GG.GG....c", "c..GGG.....c", "c...G......c", "c..........c", "cccccccccccc"],
	"teen_idol": ["....dddd....", "...dwdwdd...", "...ddwdwd...", "...dwdwdd...", "....dddd....", ".....kk.....", ".....pp.....", ".....pp.....", ".....pp.....", ".....pp.....", "....kkkk....", "............"],
	"fibonacci": ["...vvvvvv...", "..v......v..", ".v..vvvv..v.", "v..v....v..v", "v.v..vv..v.v", "v.v.v..v.v.v", "v.v.v.v..v.v", "v.v..v..v..v", "v..v...v...v", ".v..vvv...v.", "..v......v..", "...vvvvvv..."],
	"nickel": ["....dddd....", "..dddddddd..", ".ddwwwwwwdd.", ".dwwkkkkwwd.", "ddwwkwwwwwdd", "ddwwkkkwwwdd", "ddwwwwwkwwdd", "ddwwwwwkwwdd", ".dwwkkkwwwd.", ".ddwwwwwwdd.", "..dddddddd..", "....dddd...."],
	"seventh_heaven": ["...yyyyyy...", "..y......y..", "...yyyyyy...", "............", "...kkkkkk...", ".......kk...", "......kk....", "..www.kkwww.", ".wwwwkkwwwww", "wwwwwkkwwwww", "wwwwwwwwwwww", ".wwwwwwwwww."],
	"last_digit": [".kkkkkkkkkk.", ".kccccccccck", ".kcckkkccck.", ".kcccckccck.", ".kccccccccck", ".kkkkkkkkkk.", ".kwkwkwkwkk.", ".kkkkkkkkkk.", ".kwkwkwkwkk.", ".kkkkkkkkkk.", ".kwkwkwkyyk.", ".kkkkkkkkkk."],
	"far_side": ["....bbbb....", "..bbrrkrbb..", ".bkr....rkb.", ".br......rb.", "br...gg...rb", "bk..gwwg..kb", "br..gwwg..rb", "br...gg...kb", ".bk......rb.", ".brk....krb.", "..bbrrkrbb..", "....bbbb...."],
	"seedling": ["............", "...GG..GG...", "..GGGG.GGGG.", "..GGGGGGGG..", "...GGGGGG...", ".....GG.....", ".....GG.....", ".....GG.....", "...bbbbbb...", "..bbbbbbbb..", "..bbbbbbbb..", "...bbbbbb..."],
	"golden_goose": ["....yyyy....", "...yyyyyy...", "..yyyywyyy..", "..yyywwyyy..", ".yyyyywyyyy.", ".yyyyyyyyyy.", ".yyyyyyyyyy.", ".gyyyyyyyyg.", "..gyyyyyyg..", "..ggyyyygg..", "...gggggg...", "............"],
	"heart_of_gold": ["............", ".ggg....ggg.", "gyyyg..gyyyg", "gywyyggyyyyg", "gywyyyyyyyyg", "gyyyyyyyyyyg", ".gyyyyyyyyg.", "..gyyyyyyg..", "...gyyyyg...", "....gyyg....", ".....gg.....", "............"],
	"spare_key": ["............", "..gggg......", ".gg..gg.....", ".g....g.....", ".g....g.....", ".gg..gg.....", "..ggggggggg.", "......g.g.g.", "......g.g...", "............", "............", "............"],
	"zero_tolerance": ["...GGGGGG...", "..GG....GG..", ".GG......GG.", ".G....rr..G.", "GG...rr...GG", "GG..rr....GG", "GG.rr.....GG", "G.rr.......G", ".rr......GG.", "rr......GG..", "..GGGGGGG...", "............"],
	"bankroll": ["............", "..GGGGGGGG..", ".GwwwwwwwwG.", "GGGGGGGGGGGG", "GGGGrrrGGGGG", "GGGGrrrGGGGG", "GGGGGGGGGGGG", ".GwwwwwwwwG.", "..GGGGGGGG..", "............", "............", "............"],
	"compound_interest": ["...........y", "..........yy", ".........y.y", "..........y.", ".........G..", ".......G.G..", ".....G.G.G..", ".....G.G.G..", "...G.G.G.G..", ".G.G.G.G.G..", ".G.G.G.G.G..", "dddddddddddd"],
	"double_down": ["..rrrrrrrr..", ".rrwrrrrwrr.", ".rrrwwwwrrr.", "..rrrrrrrr..", "..wwwwwwww..", "..rrrrrrrr..", ".rrwrrrrwrr.", ".rrrwwwwrrr.", "..rrrrrrrr..", "..wwwwwwww..", "............", "............"],
	"corner_office": ["GGGGG.GGGGG.", "GwwwG.GwwwG.", "GwwwG.GwwwG.", "GwwwG.GwwwG.", "GGGGGyGGGGG.", ".....yy.....", "GGGGGyGGGGG.", "GwwwG.GwwwG.", "GwwwG.GwwwG.", "GwwwG.GwwwG.", "GGGGG.GGGGG.", "............"],
	"big_spender": ["....bbbb....", ".....bb.....", "....bbbb....", "...bbbbbb...", "..bbbyybbb..", ".bbbyybbbbb.", ".bbbbyybbbb.", ".bbbbbyybbb.", ".bbbbyybbbb.", "..bbbbbbbb..", "...bbbbbb...", "............"],
	"patron": ["............", "...kkkkkk...", "...kkkkkk...", "...kkkkkk...", "...kkkkkk...", "...rrrrrr...", "...kkkkkk...", "kkkkkkkkkkkk", ".kkkkkkkkkk.", "............", "............", "............"],
	"late_bloomer": ["....pppp....", "...pppppp...", "..ppyyyypp..", "..ppyyyypp..", "...pppppp...", "....pppp....", ".....GG.....", "..GG.GG.....", "...GGGG.....", ".....GG.....", ".....GG.....", "....bbbb...."],
	"veterans": ["..rr....rr..", "...rr..rr...", "....rrrr....", ".....rr.....", "....gggg....", "...gyyyyg...", "..gyyyyyyg..", "..gyywwyyg..", "..gyyyyyyg..", "...gyyyyg...", "....gggg....", "............"],
	"outside_connection": ["............", "..gggg......", ".g....g.....", ".g..gggggg..", ".g..g.g...g.", "..gggg.g..g.", ".......g..g.", ".......gggg.", "............", "............", "............", "............"],
	"inside_track": ["rrrrrrrrrrrr", "r..........r", "r.wwwwwwww.r", "r.w......w.r", "r.w.cccc.w.r", "r.w.cccc.w.r", "r.w.cccc.w.r", "r.w......w.r", "r.wwwwwwww.r", "r..........r", "rrrrrrrrrrrr", "............"],
	"colour_coded": ["....rrkk....", "..rrrrkkkk..", ".rrrrrkkkkk.", ".rrrrrkkkkk.", "rrrrrrkkkkkk", "rrrrrrkkkkkk", "rrrrrrkkkkkk", "rrrrrrkkkkkk", ".rrrrrkkkkk.", ".rrrrrkkkkk.", "..rrrrkkkk..", "....rrkk...."],
	"rainy_day": [".....c......", "...BBBBBB...", "..BBBBBBBB..", ".BBBBBBBBBB.", "BBBBBBBBBBBB", ".c...dd..c..", ".....dd.....", ".c...dd..c..", ".....dd.....", ".....dd.....", "...d.dd.....", "....dd......"],
}
const SPRITE_COLOURS := {"k": "#1a1410", "w": "#f4ead5", "g": "#b8862b", "y": "#f2c14e", "r": "#c0392b",
	"G": "#3fae5a", "c": "#5fd3d3", "v": "#b07ad9", "b": "#7a4e2a", "d": "#8a8a8a", "p": "#f4a3c0",
	"o": "#e9894a", "B": "#3f6fd1"}

## 5x5 felt-size pictures: the face of every chip and the badge of every felt upgrade, so each
## placed item reads at a glance (a smaller echo of its 12x12 icon). Colours: SPRITE_COLOURS.
const MINI := {
	"perm": ["..y..", "..y..", "yyyyy", "..y..", "..y.."],
	"magnet": ["w...w", "r...r", "r...r", "rrrrr", ".rrr."],
	"compounding": ["..G..", ".GGG.", "G.G.G", "..G..", "..G.."],
	"croupier": ["..b..", "..b..", "..b..", "ddddd", "d.d.d"],
	"wildcard_zero": [".ccc.", "c...c", "c.y.c", "c...c", ".ccc."],
	"mint": [".yyy.", "yykyy", "yyyyy", "yykyy", ".yyy."],
	"respin": [".ccc.", "c...c", "c..cc", "c...c", ".cc.."],
	"ledger": ["bbbbb", "bwwwb", "bkkwb", "bwwwb", "bbbbb"],
	"collector": [".....", "rrrrr", "wwwww", "yyyyy", "....."],
	"bridge": [".....", "ww.ww", "wwyww", "ww.ww", "....."],
	"mirror": ["cc.ww", "cc.ww", "cc.ww", ".....", "..b.."],
	"porch_light": ["..b..", ".yyy.", "yyyyy", ".yyy.", "..b.."],
	"black_cat": ["d...d", "ddddd", "dydyd", "ddddd", ".ddd."],
	"penny": [".ooo.", "ooboo", "ooboo", "ooboo", ".ooo."],
	"snowball": ["w.w.w", ".www.", "wwcww", ".www.", "w.w.w"],
	"street_light": [".ddd.", ".dyd.", "..d..", "..d..", ".ddd."],
	"red_herring": [".....", ".rr.r", "rwrrr", ".rr.r", "....."],
	"jar": [".bbb.", "c...c", "cyyyc", "cyyyc", "ccccc"],
	"hedge": [".....", "G.G.G", "GGGGG", "GGGGG", "bbbbb"],
	"wheel_spoke": [".www.", "w.w.w", "wwyww", "w.w.w", ".www."],
	"echo": ["ccccc", "c...c", "c.c.c", "c...c", "ccccc"],
	"ace": ["wwwww", "wwkww", "wkkkw", "wwkww", "wwwww"],
	"tip_jar": ["..G..", ".bbb.", "c.y.c", "cyyyc", "ccccc"],
	"green_thumb": ["GG.GG", ".GGG.", "..G..", "..G..", ".bbb."],
	"signpost": [".yyyy", "..b..", "yyyy.", "..b..", "..b.."],
	"sentinel": ["GGGGG", "GwwwG", "GwGwG", ".GwG.", "..G.."],
	"crown": [".....", "y.y.y", "yyyyy", "yrcry", "yyyyy"],
	"even_stevens": [".rdd.", "rrddd", "rrddd", "rrddd", ".rdd."],
	"box_office": [".....", "yyyyy", "yk.ky", "yyyyy", "....."],
	"coin_purse": ["..b..", ".bbb.", "bbybb", "bbybb", ".bbb."],
	"streak_rider": ["r.r.r", ".w.w.", "r.r.r", ".w.w.", "r.r.r"],
	"odds_maker": ["yyyyy", "yrrry", "yr.ry", "yrrry", "yyyyy"],
	"keystone": ["yyyyy", "ywwwy", ".ygy.", ".ywy.", "..y.."],
	"tall_stack": [".rrr.", ".www.", ".BBB.", ".rrr.", ".www."],
	"wind_up": [".ddd.", "d.y.d", ".ddd.", "..d..", ".ddd."],
	"ivory_tower": ["..w..", ".www.", ".wkw.", ".www.", "wwwww"],
	"odd_fellow": ["wwwww", "wkwww", "wwkww", "wwwkw", "wwwww"],
	"even_keel": ["..w..", "..ww.", "..www", "bbbbb", ".bbb."],
	"low_roller": ["..G..", "..G..", "GGGGG", ".GGG.", "..G.."],
	"penthouse": ["..y..", ".ddd.", ".dyd.", ".ddd.", ".dyd."],
	"dozen_watch": [".ggg.", "gwkwg", "gwkkg", "gwwwg", ".ggg."],
	"pillar": ["wwwww", ".w.w.", ".w.w.", ".w.w.", "wwwww"],
	"night_owl": ["b...b", "bbbbb", "ykbky", "bbobb", ".bbb."],
	"piggy_bank": [".pp..", "ppppp", "pkppp", "ppppo", "p..p."],
	"clover": [".G.G.", "GGGGG", ".GGG.", "..b..", ".b..."],
	"doorbell": ["..y..", ".yyy.", ".yyy.", "yyyyy", "..b.."],
	"prime_time": ["d...d", ".d.d.", "ccccc", "cwccc", "ccccc"],
	"square_deal": ["ccccc", "c..Gc", "G.G.c", "cG..c", "ccccc"],
	"teen_idol": [".ddd.", ".ddd.", "..d..", "..p..", ".ppp."],
	"fibonacci": ["vvvvv", "v...v", "v.v.v", "v.vvv", "v...."],
	"nickel": [".ddd.", "dwwwd", "dwddd", "dddwd", ".ddd."],
	"seventh_heaven": ["yyyyy", "...y.", "..y..", ".y...", ".y..."],
	"last_digit": [".c.c.", "ccccc", ".c.c.", "ccccc", ".c.c."],
	"far_side": [".bbb.", "b...r", "b.G.b", "r...b", ".bbb."],
	"seedling": [".G.G.", "..G..", "..G..", ".bbb.", ".bbb."],
	"golden_goose": [".yyy.", "yywyy", "yyyyy", "yyyyy", ".ggg."],
	"heart_of_gold": ["yy.yy", "yyyyy", "yyyyy", ".yyy.", "..y.."],
	"spare_key": [".....", "gg...", "g.ggg", "gg.gg", "....."],
	"conductor": ["....w", "...w.", "..w..", ".yy..", "yyy.."],
	"relay": ["cc...", "..c..", "ccccc", "..c..", "...cc"],
	"fuse": ["...y.", "..o..", ".ddd.", "ddddd", ".ddd."],
	"kingmaker": ["..y..", ".yyy.", "..y..", ".yyy.", "yyyyy"],
	"gilded": [".....", ".yyy.", "yyyyy", "yywyy", "yyyyy"],
	"hot": ["..r..", ".rr..", ".ryr.", "ryyyr", ".rrr."],
	"link": [".....", "cc.cc", "c.c.c", "cc.cc", "....."],
	"double_felt": ["GGG..", "G.GGG", "GGG.G", "..G.G", "..GGG"],
	"pinned": [".vvv.", ".vvv.", "..v..", "..d..", "..d.."],
	"diamond": ["..c..", ".ccc.", "ccwcc", ".ccc.", "..c.."],
	"magnetized": ["GGGGG", "GrGrG", "GrGrG", "GrrrG", "GGGGG"],
	"twin_square": ["rr.rr", "rr.rr", "..y..", "rr.rr", "rr.rr"],
	"spoke": ["y.y.y", ".yyy.", "yy.yy", ".yyy.", "y.y.y"],
	"gold_trim": ["yyyyy", "yGGGy", "yGGGy", "yGGGy", "yyyyy"],
	"fat_box": ["vvvvv", "vyyyv", "vyyyv", "vyyyv", "vvvvv"],
	"repeat_box": ["vvvvv", "vwvwv", "vvvvv", "vwvwv", "vvvvv"],
	"lucky_colour": ["..y..", "rr.dd", "rr.dd", "rr.dd", "....."],
	"lamp": [".yyy.", "yyyyy", "..b..", "..b..", ".bbb."],
	"silk": ["vpvpv", "vpvpv", "vpvpv", "vpvpv", "vpvpv"],
	"sweet_spot": ["rrrrr", "ryyyr", "rywyr", "ryyyr", "rrrrr"],
	"cornerstone": ["y...y", ".GGG.", ".GGG.", ".GGG.", "y...y"],
}


## A small pixel icon (12x12 at scale 1). `tiny` = draw a 6x6 glyph for inside chips.
static func icon(ci: CanvasItem, id: String, c: Vector2, s: int = 1, tiny: bool = false) -> void:
	c = c.round()
	if tiny:
		_tiny(ci, id, c)
		return
	var o := c - Vector2(6, 6) * s
	var R := func(x: int, y: int, w: int, h: int, col: Color):
		ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), col)
	match id:
		"perm":
			chip(ci, c, 5.5 * s, P.GOLD)
			R.call(5, 4, 2, 4, P.WOOD_DARK)
			R.call(4, 5, 4, 2, P.WOOD_DARK)
		"bet":
			chip(ci, c, 5.5 * s, P.CREAM)
		"magnet":
			R.call(2, 2, 3, 7, P.RED)
			R.call(7, 2, 3, 7, P.RED)
			R.call(2, 8, 8, 3, P.RED)
			R.call(2, 2, 3, 2, P.CREAM)
			R.call(7, 2, 3, 2, P.CREAM)
		"compounding":
			R.call(5, 3, 2, 8, P.GOOD)
			R.call(3, 5, 6, 2, P.GOOD)
			R.call(4, 4, 4, 1, P.GOOD)
			R.call(5, 2, 2, 1, P.GOOD)
			R.call(2, 10, 8, 1, P.GOOD.darkened(0.3))
		"croupier":
			R.call(6, 1, 1, 8, P.WOOD)
			R.call(2, 8, 9, 2, P.LINE)
			for x in [2, 4, 6, 8, 10]:
				R.call(x, 10, 1, 2, P.LINE)
		"wildcard_zero":
			ci.draw_circle(c, 5 * s, Color("#2ec4b6"), false, 2.0 * s, false)
			R.call(5, 0, 2, 2, P.GOLD)
			R.call(5, 10, 2, 2, P.GOLD)
		"mint":
			ci.draw_circle(c, 5.5 * s, P.GOLD, true, -1.0, false)
			ci.draw_circle(c, 4.0 * s, P.GOLD.darkened(0.25), false, 1.0, false)
			R.call(5, 3, 2, 6, P.WOOD_DARK)
			R.call(4, 4, 4, 1, P.WOOD_DARK)
			R.call(4, 7, 4, 1, P.WOOD_DARK)
		"respin":
			ci.draw_arc(c, 4.5 * s, 0.6, TAU - 0.3, 14, P.CYAN, 2.0 * s, false)
			R.call(8, 1, 3, 3, P.CYAN)
		"ledger":
			R.call(2, 1, 8, 10, Color("#8a5a2b"))
			R.call(3, 2, 6, 8, P.CREAM)
			for y in [3, 5, 7]:
				R.call(4, y, 4, 1, P.DIM)
		"collector":
			for i in range(3):
				R.call(2, 8 - i * 3, 8, 2, [P.RED, P.CREAM, P.GOLD][i])
				R.call(2, 10 - i * 3, 8, 1, Color(0, 0, 0, 0.4))
		"gilded":
			R.call(1, 5, 10, 5, P.GOLD)
			R.call(3, 3, 6, 2, P.GOLD.lightened(0.3))
			R.call(2, 6, 2, 1, P.CREAM)
		"hot":
			R.call(4, 2, 4, 9, P.DANGER)
			R.call(2, 5, 8, 6, P.DANGER)
			R.call(4, 6, 4, 5, P.GOLD)
			R.call(5, 8, 2, 3, P.CREAM)
		"link":
			ci.draw_arc(c - Vector2(2.5, 0) * s, 3 * s, 0, TAU, 12, P.CYAN, 1.5 * s, false)
			ci.draw_arc(c + Vector2(2.5, 0) * s, 3 * s, 0, TAU, 12, P.CYAN, 1.5 * s, false)
		"double_felt":
			R.call(1, 4, 6, 6, P.FELT.lightened(0.3))
			R.call(5, 2, 6, 6, P.GOOD)
		"pinned":
			ci.draw_circle(c - Vector2(0, 2) * s, 3.5 * s, P.VIOLET, true, -1.0, false)
			R.call(5, 6, 2, 6, P.LINE)
		"la_partage":
			ci.draw_circle(c, 5 * s, P.CREAM, true, -1.0, false)
			R.call(6, 1, 5, 10, P.PANEL)
			R.call(6, 1, 1, 10, P.GOLD)
		"red_streak":
			for i in range(3):
				R.call(1 + i * 4, 8 - i * 3, 3, 3 + i * 3, P.RED.lightened(0.1 * i))
		"rent_control":
			R.call(2, 5, 8, 6, P.WOOD)
			R.call(3, 3, 6, 2, P.WOOD.lightened(0.2))
			R.call(5, 1, 2, 2, P.WOOD.lightened(0.2))
			R.call(5, 7, 2, 4, P.BLACK)
		"thirteen":
			ci.draw_circle(c, 5.5 * s, P.BLACK, true, -1.0, false)
			R.call(3, 4, 1, 4, P.GOLD)
			R.call(5, 4, 3, 1, P.GOLD)
			R.call(7, 5, 1, 1, P.GOLD)
			R.call(6, 6, 2, 1, P.GOLD)
			R.call(7, 7, 1, 1, P.GOLD)
			R.call(5, 8, 3, 1, P.GOLD)
		"en_prison":
			R.call(1, 1, 10, 10, P.PANEL_HI)
			for x in [2, 5, 8]:
				R.call(x, 1, 2, 10, P.DIM)
		"hot_hand":
			R.call(3, 4, 6, 7, Color("#d9a47a"))
			for x in [3, 5, 7]:
				R.call(x, 1, 2, 4, Color("#d9a47a"))
			R.call(9, 5, 2, 3, Color("#d9a47a"))
			R.call(2, 10, 8, 1, P.DANGER)
		"bridge":
			# Two squares joined across a line.
			R.call(1, 4, 4, 4, P.CREAM)
			R.call(7, 4, 4, 4, P.CREAM)
			R.call(4, 5, 4, 2, P.GOLD)
		"kingmaker":
			# A crown.
			R.call(2, 6, 8, 4, P.GOLD)
			R.call(2, 3, 2, 3, P.GOLD)
			R.call(5, 2, 2, 4, P.GOLD)
			R.call(8, 3, 2, 3, P.GOLD)
			R.call(5, 7, 2, 2, P.RED)
		"cornerstone":
			# A square with its four corners lit.
			R.call(2, 2, 8, 8, P.FELT.lightened(0.2))
			for p in [[1, 1], [9, 1], [1, 9], [9, 9]]:
				R.call(p[0], p[1], 2, 2, P.GOLD)
		"split_decision":
			# A square split down the middle.
			R.call(1, 3, 4, 6, P.RED)
			R.call(7, 3, 4, 6, P.BLACK.lightened(0.3))
			R.call(5, 2, 2, 8, P.GOLD)
		"momentum":
			# Three chevrons speeding up.
			for i in range(3):
				R.call(1 + i * 4, 3, 2, 2, P.CYAN.darkened(0.3 - i * 0.15))
				R.call(2 + i * 4, 5, 2, 2, P.CYAN.darkened(0.3 - i * 0.15))
				R.call(1 + i * 4, 7, 2, 2, P.CYAN.darkened(0.3 - i * 0.15))
		"street_light":
			R.call(5, 2, 2, 9, P.DIM)
			R.call(3, 1, 6, 2, P.DIM)
			R.call(3, 3, 2, 2, P.GOLD)
			R.call(1, 5, 4, 1, Color(P.GOLD, 0.5))
			R.call(3, 10, 6, 1, P.DIM)
		"red_herring":
			R.call(2, 4, 7, 4, P.RED)
			R.call(9, 3, 2, 6, P.RED.darkened(0.2))
			R.call(3, 5, 1, 1, P.CREAM)
		"jar":
			R.call(3, 2, 6, 1, P.WOOD)
			R.call(2, 3, 8, 8, Color("#6fa8c8"))
			R.call(3, 7, 6, 3, P.GOLD)
			R.call(3, 4, 1, 5, Color(1, 1, 1, 0.5))
		"hedge":
			for x in [1, 4, 7]:
				R.call(x, 3, 4, 7, P.GOOD.darkened(0.3))
			R.call(1, 9, 10, 2, P.WOOD)
		"wheel_spoke":
			ci.draw_arc(c, 4.5 * s, 0, TAU, 16, P.CREAM, 1.0 * s, false)
			R.call(5, 1, 2, 10, P.CREAM)
			R.call(1, 5, 10, 2, P.CREAM)
			R.call(5, 5, 2, 2, P.GOLD)
		"echo":
			for i in range(3):
				ci.draw_arc(c, (1.5 + i * 1.8) * s, 0, TAU, 14, Color(P.CYAN, 1.0 - i * 0.3), 1.0 * s, false)
		"ace":
			R.call(2, 1, 8, 10, P.CREAM)
			R.call(5, 3, 2, 2, P.BLACK)
			R.call(4, 5, 4, 2, P.BLACK)
			R.call(5, 7, 2, 2, P.BLACK)
			R.call(3, 2, 1, 1, P.BLACK)
		"tip_jar":
			R.call(3, 4, 6, 7, Color("#6fa8c8"))
			R.call(3, 3, 6, 1, P.WOOD)
			R.call(4, 7, 2, 2, P.GOLD)
			R.call(6, 8, 2, 2, P.GOLD.darkened(0.2))
			R.call(4, 1, 4, 2, P.GOOD)
		"green_thumb":
			R.call(5, 5, 2, 6, P.GOOD.darkened(0.3))
			R.call(2, 3, 4, 3, P.GOOD)
			R.call(6, 2, 4, 3, P.GOOD)
		"signpost":
			R.call(5, 3, 2, 8, P.WOOD)
			R.call(1, 2, 8, 2, P.GOLD.darkened(0.2))
			R.call(4, 5, 7, 2, P.GOLD.darkened(0.4))
		"diamond":
			R.call(5, 1, 2, 2, Color("#9ad7ff"))
			R.call(3, 3, 6, 2, Color("#9ad7ff"))
			R.call(2, 5, 8, 2, Color("#6cb6e8"))
			R.call(4, 7, 4, 2, Color("#4a90c8"))
			R.call(5, 9, 2, 2, Color("#4a90c8"))
		"magnetized":
			R.call(1, 1, 10, 10, P.FELT.lightened(0.2))
			R.call(3, 3, 2, 5, P.RED)
			R.call(7, 3, 2, 5, P.RED)
			R.call(3, 7, 6, 2, P.RED)
		"twin_square":
			R.call(1, 3, 4, 6, P.RED)
			R.call(7, 3, 4, 6, P.RED)
			R.call(5, 5, 2, 2, P.GOLD)
		"spoke":
			R.call(1, 1, 10, 10, P.FELT.lightened(0.2))
			ci.draw_arc(c, 3.5 * s, 0, TAU, 12, P.GOLD, 1.0 * s, false)
			R.call(5, 2, 2, 8, P.GOLD.darkened(0.3))
		"gold_trim":
			R.call(1, 3, 10, 6, P.FELT)
			ci.draw_rect(Rect2(o + Vector2(1, 3) * s, Vector2(10, 6) * s), P.GOLD, false, 1.0 * s)
		"fat_box":
			R.call(1, 2, 10, 8, P.FELT)
			R.call(3, 4, 6, 4, P.GOLD)
		"repeat_box":
			R.call(1, 3, 10, 6, P.FELT)
			R.call(3, 5, 2, 2, P.CREAM)
			R.call(7, 5, 2, 2, P.CREAM)
		"lucky_colour":
			R.call(1, 3, 5, 6, P.RED)
			R.call(6, 3, 5, 6, P.BLACK.lightened(0.3))
			R.call(5, 1, 2, 2, P.GOLD)
		"black_cat":
			# A sitting black cat with gold eyes.
			R.call(3, 4, 6, 7, Color("#141418"))
			R.call(3, 2, 2, 2, Color("#141418"))
			R.call(7, 2, 2, 2, Color("#141418"))
			R.call(4, 5, 1, 1, P.GOLD)
			R.call(7, 5, 1, 1, P.GOLD)
			R.call(9, 8, 2, 1, Color("#141418"))
			R.call(10, 6, 1, 2, Color("#141418"))
		"penny":
			ci.draw_circle(c, 4.5 * s, Color("#b87333"), true, -1.0, false)
			ci.draw_circle(c, 3.0 * s, Color("#d08a4a"), true, -1.0, false)
			R.call(5, 4, 2, 4, Color("#7a4a20"))
		"snowball":
			ci.draw_circle(c + Vector2(0, 1) * s, 4.5 * s, P.CREAM, true, -1.0, false)
			R.call(4, 4, 2, 1, Color.WHITE)
			R.call(3, 9, 6, 1, P.CYAN.darkened(0.3))
		"sentinel":
			# A shield with a zero on it.
			R.call(3, 2, 6, 6, P.GREEN)
			R.call(4, 8, 4, 2, P.GREEN)
			R.call(5, 10, 2, 1, P.GREEN)
			R.call(5, 4, 2, 3, P.CREAM)
			R.call(5, 5, 2, 1, P.GREEN)
		"crown":
			R.call(1, 7, 10, 3, P.GOLD)
			R.call(1, 4, 2, 3, P.GOLD)
			R.call(5, 3, 2, 4, P.GOLD)
			R.call(9, 4, 2, 3, P.GOLD)
			R.call(2, 9, 8, 1, P.CYAN)
		"lamp":
			R.call(4, 1, 4, 1, P.WOOD)
			R.call(3, 2, 6, 4, P.GOLD.lightened(0.2))
			R.call(5, 6, 2, 4, P.WOOD)
			R.call(3, 10, 6, 1, P.WOOD)
			R.call(1, 7, 1, 1, P.GOLD)
			R.call(10, 7, 1, 1, P.GOLD)
		"silk":
			for i in range(4):
				R.call(1 + i * 3, 2 + (i % 2), 2, 8, Color("#c08ad8").lightened(0.1 * i))
		"sweet_spot":
			ci.draw_circle(c, 5 * s, P.RED.lightened(0.2), false, 1.0 * s, false)
			ci.draw_circle(c, 3 * s, P.GOLD, false, 1.0 * s, false)
			R.call(5, 5, 2, 2, P.CREAM)
		"last_call":
			# A clock nearly at midnight.
			ci.draw_circle(c, 5 * s, P.CREAM, true, -1.0, false)
			ci.draw_circle(c, 4 * s, P.PANEL, true, -1.0, false)
			R.call(5, 2, 2, 4, P.CREAM)
			R.call(6, 5, 3, 1, P.RED)
		"comped":
			# A cocktail glass.
			R.call(1, 2, 10, 1, P.CREAM)
			R.call(2, 3, 8, 1, P.CYAN.darkened(0.2))
			R.call(3, 4, 6, 1, P.CYAN.darkened(0.2))
			R.call(4, 5, 4, 1, P.CYAN.darkened(0.2))
			R.call(5, 6, 2, 4, P.CREAM)
			R.call(3, 10, 6, 1, P.CREAM)
			R.call(8, 1, 2, 2, P.RED)
		"insurance":
			# An umbrella.
			R.call(2, 3, 8, 2, P.GOOD)
			R.call(1, 5, 10, 1, P.GOOD)
			R.call(5, 5, 1, 5, P.CREAM)
			R.call(4, 9, 1, 1, P.CREAM)
		"high_society":
			# A top hat.
			R.call(3, 2, 6, 6, Color("#141418"))
			R.call(3, 6, 6, 1, P.RED)
			R.call(1, 8, 10, 2, Color("#141418"))
		"black_tie":
			# A bow tie.
			R.call(1, 4, 4, 4, Color("#141418"))
			R.call(7, 4, 4, 4, Color("#141418"))
			R.call(5, 5, 2, 2, Color("#2a2a33"))
			R.call(2, 5, 1, 1, P.CREAM.darkened(0.4))
		"mirror":
			# A hand mirror: two halves of one number.
			R.call(2, 2, 8, 8, P.CYAN.darkened(0.2))
			R.call(3, 3, 3, 6, P.CREAM)
			R.call(6, 3, 3, 6, P.CYAN.lightened(0.4))
			R.call(5, 10, 2, 2, P.WOOD)
		"porch_light":
			# A lamp casting light to both sides.
			R.call(5, 1, 2, 2, P.WOOD)
			R.call(4, 3, 4, 4, P.GOLD)
			R.call(5, 7, 2, 4, P.WOOD)
			R.call(1, 4, 2, 1, P.GOLD.darkened(0.2))
			R.call(9, 4, 2, 1, P.GOLD.darkened(0.2))
			R.call(1, 6, 2, 1, P.GOLD.darkened(0.4))
			R.call(9, 6, 2, 1, P.GOLD.darkened(0.4))
		"sevens":
			# A gold 7.
			R.call(2, 2, 8, 2, P.GOLD)
			R.call(7, 4, 2, 2, P.GOLD)
			R.call(6, 6, 2, 2, P.GOLD)
			R.call(5, 8, 2, 3, P.GOLD)
		"satin_gloves":
			# A white glove.
			R.call(3, 5, 6, 6, P.CREAM)
			for i in range(4):
				R.call(3 + i * 2 - (1 if i == 0 else 0), 1 + (i % 2), 1 + (1 if i == 0 else 0), 4, P.CREAM)
			R.call(3, 9, 6, 1, P.DIM)
		"loan":
			# A banknote with an IOU stripe.
			R.call(1, 3, 10, 6, P.GOOD.darkened(0.3))
			R.call(2, 4, 8, 4, P.GOOD.darkened(0.1))
			R.call(4, 5, 4, 2, P.WOOD_DARK)
			R.call(1, 9, 10, 1, P.CYAN)
		"dealer_signature":
			R.call(2, 9, 9, 1, P.CREAM)
			for i in range(5):
				R.call(2 + i * 2, 6 - (i % 2) * 2, 2, 2, P.CREAM)
			R.call(9, 1, 2, 6, P.GOLD)
		"call_bets":
			ci.draw_arc(c, 5 * s, -PI, 0, 10, P.GOLD, 2.0 * s, false)
			R.call(5, 5, 2, 6, P.GOLD)
		"reroll":
			# Refresh symbol: an open circular arrow, arrowhead at the top right.
			ci.draw_arc(c, 4 * s, -PI * 0.1, PI * 1.5, 16, P.CREAM, 2.0 * s, false)
			var e := c + Vector2(0, -4) * s
			ci.draw_colored_polygon(PackedVector2Array([e + Vector2(0, -3) * s, e + Vector2(0, 3) * s, e + Vector2(3.5, 0) * s]), P.CREAM)
		"stack":
			for i in range(4):
				R.call(2, 9 - i * 2, 8, 2, [P.CREAM, P.RED, P.CREAM, P.RED][i])
		"cash":
			ci.draw_circle(c, 5.5 * s, P.GOLD, true, -1.0, false)
			R.call(5, 3, 2, 6, P.WOOD_DARK)
		"spin":
			ci.draw_circle(c, 4 * s, P.CREAM, true, -1.0, false)
			ci.draw_circle(c - Vector2(1, 1) * s, 1.5 * s, Color.WHITE, true, -1.0, false)
		_:
			if SPRITES.has(id):
				var rows: Array = SPRITES[id]
				for y in range(12):
					var row: String = rows[y]
					for x in range(12):
						var ch := row[x]
						if ch != ".":
							R.call(x, y, 1, 1, Color(SPRITE_COLOURS[ch]))
			elif GLYPHS.has(id):
				# Lettered tile: a felt square with a short label, framed in the item's colour.
				var g: Array = GLYPHS[id]
				R.call(0, 1, 12, 10, Color(g[1]).darkened(0.55))
				ci.draw_rect(Rect2(o + Vector2(0, 1) * s, Vector2(12, 10) * s), Color(g[1]), false, 1.0)
				var gf := P.font()
				var gs: int = 8 * s
				var gw := gf.get_string_size(g[0], HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
				ci.draw_string(gf, (c + Vector2(-gw / 2.0, 3 * s)).round(), g[0], HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(g[1]).lightened(0.4))
			else:
				ci.draw_circle(c, 5 * s, P.CREAM, true, -1.0, false)


static func _tiny(ci: CanvasItem, id: String, c: Vector2) -> void:
	face(ci, id, c)


## An item's 5x5 felt-size picture (MINI), centred on `c`. Anything without one gets a dot.
static func face(ci: CanvasItem, id: String, c: Vector2, s: int = 1) -> void:
	var o := c.round() - (Vector2(5, 5) if s == 2 else Vector2(2, 2))
	if not MINI.has(id):
		ci.draw_rect(Rect2(o + Vector2(1, 1) * s, Vector2(3, 3) * s), P.CREAM)
		return
	var rows: Array = MINI[id]
	for y in range(5):
		var row: String = rows[y]
		for x in range(5):
			if row[x] != ".":
				ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), Color(SPRITE_COLOURS[row[x]]))


## A brass plaque background.
## A plaque: dark lacquer with a brass hairline and brass corner studs (`dark` = deeper still).
static func plaque(ci: CanvasItem, r: Rect2, dark: bool = false) -> void:
	var base := Color("#100d14") if dark else Color("#1a1520")
	var brass := Color("#a07c42")
	ci.draw_rect(r, Color(0, 0, 0, 0.85))
	ci.draw_rect(r.grow(-1), base)
	ci.draw_rect(r.grow(-1), brass, false, 1.0)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color(1, 0.9, 0.7, 0.08))
	for p in [r.position + Vector2(2, 2), Vector2(r.end.x - 4, r.position.y + 2),
			Vector2(r.position.x + 2, r.end.y - 4), r.end - Vector2(4, 4)]:
		ci.draw_rect(Rect2(p, Vector2(2, 2)), P.GOLD.darkened(0.15))


## Text with a 1px drop shadow.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, centered: bool = false) -> void:
	var p := pos
	if centered:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	p = p.round()
	ci.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Centred neon lettering in the title font with a soft glow. `on` < 1 dims it (flicker).
static func neon(ci: CanvasItem, centre: Vector2, s: String, size: int, col: Color, alpha: float = 1.0, on: float = 1.0) -> void:
	var font := P.title_font()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := (centre - Vector2(w / 2.0, -size / 2.0)).round()
	var lit: Color = col.lerp(col.darkened(0.7), 1.0 - on)
	if on > 0.5:
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			ci.draw_string(font, p + d, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, 0.18 * alpha * on))
	ci.draw_string(font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * alpha))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(lit, alpha))
