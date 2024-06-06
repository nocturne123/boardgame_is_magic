class_name DecreaseHealth extends BaseAction

#需要的信息，每个节点的信息不一定相同
var decrease_num:int

func take_action():
	player.health -= decrease_num
	
func reset_property():
	decrease_num = 0
