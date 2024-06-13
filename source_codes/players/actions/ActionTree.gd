class_name ActionTree extends Node

#默认动作
@onready var DecreaseHealth =  $DecreaseHealth
@onready var ReceiveDamage = $ReceiveDamage
@onready var LivingUpdate = $LivingUpdate
@onready var DrawCard = $DrawCard
@onready var TurnStart = $TurnStart
@onready var DiscardCard = $DiscardCard
@onready var UseCard = $UseCard


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
		
#添加默认链条
func make_default_chain():
	ReceiveDamage.next_action = DecreaseHealth
	DecreaseHealth.next_action = LivingUpdate
	TurnStart.next_action = DrawCard
	
	
func _ready():
	make_default_chain()
