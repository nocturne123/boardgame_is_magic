class_name DrawCard extends BaseAction

#由于手牌、抽牌堆、弃牌堆由card_pile_ui统一管理，这里仅发射信号来通知card_pile_ui
signal player_draw_card

var draw_num = 0
var from_pile = null

func take_action():
	emit_signal("player_draw_card",from_pile,draw_num)
	
func reset_property():
	draw_num = 0
	from_pile = null
