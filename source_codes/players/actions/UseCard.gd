class_name UseCard extends BaseAction


#由于手牌、抽牌堆、弃牌堆由card_pile_ui统一管理，这里仅发射信号来通知card_pile_ui
#使用卡牌后，卡牌进入什么弃牌堆，由card_pile_ui管理，现阶段需要分出普通牌堆和奖励牌堆
signal player_use_card

var card = null
var target = null

func take_action():
	emit_signal("player_discard_card",card,target)
	
func reset_property():
	card = null
	target = null
