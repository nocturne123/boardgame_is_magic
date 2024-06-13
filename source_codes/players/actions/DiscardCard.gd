class_name DiscardCard extends BaseAction


#由于手牌、抽牌堆、弃牌堆由card_pile_ui统一管理，这里仅发射信号来通知card_pile_ui
signal player_discard_card

var card = null
var to_pile = null

func take_action():
	emit_signal("player_discard_card",to_pile,card)
	
func reset_property():
	card = null
	to_pile = null
