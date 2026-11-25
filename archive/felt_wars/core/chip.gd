extends RefCounted
## One chip on the felt. Player chips are bought or placed from inventory; House chips
## are placed by the dealer AI. Every chip except "temp" persists across spins.

enum Side { PLAYER, HOUSE }

var id: int = 0
var side: int = Side.PLAYER
var kind: String = "perm"   ## see Content.CHIPS
var bet: String = "S0"      ## Board bet key
var value: int = 1


func _init(id_in: int = 0, side_in: int = Side.PLAYER, kind_in: String = "perm", bet_in: String = "S0", value_in: int = 1) -> void:
	id = id_in
	side = side_in
	kind = kind_in
	bet = bet_in
	value = value_in


func copy():
	return get_script().new(id, side, kind, bet, value)


func describe() -> String:
	return "%s %s x%d on %s" % ["P" if side == Side.PLAYER else "H", kind, value, bet]
