extends RefCounted
## One chip on the felt.
##   "bet"  - a one-spin betting chip from this table's stack. Winners return to the stack.
##   others - permanent chips bought in the shop (see Content.CHIPS). They never leave the felt.

var id: int = 0
var kind: String = "bet"
var bet: String = "S0"
var value: int = 1


func _init(id_in: int = 0, kind_in: String = "bet", bet_in: String = "S0", value_in: int = 1) -> void:
	id = id_in
	kind = kind_in
	bet = bet_in
	value = value_in


func copy():
	return get_script().new(id, kind, bet, value)


func is_bet() -> bool:
	return kind == "bet"


func describe() -> String:
	return "%s x%d on %s" % [kind, value, bet]
