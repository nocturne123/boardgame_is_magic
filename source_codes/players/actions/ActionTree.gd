class_name ActionTree extends Node

#执行动作链
#如果有下一个动作，将信息传递给下一个动作
#如果没有下一个动作，则终止
func chain_of_actions(begin_action):
	if begin_action.next_action != null:
		begin_action.trigger()
		begin_action.imform_next_action()
		begin_action.reset_property()
		chain_of_actions(begin_action.next_action)
	else:
		begin_action.trigger()
