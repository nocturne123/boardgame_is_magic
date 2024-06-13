class_name TurnStart extends BaseAction

#有大量的动作节点会夹在开始回合和抽牌之间
func take_action():
	#回合数加一
	player.turn_count += 1
	
	#重置玩家动次数和攻击次数
	player.move_chance_in_turn = player.move_chance
	player.attack_chance_in_turn = player.attack_chance

func imform_next_action():
	next_action.draw_num = player.draw_stage_card_number
	
