class_name ReceiveDamage extends BaseAction

var damage:Damage
var out_put_num:int

func take_action():
	var received_damage:int
	match damage.type:
		Damage.DamageType.Physical:
			received_damage = damage.num - player.physical_defence
		Damage.DamageType.Magic:
			received_damage = damage.num - player.magic_defence
		Damage.DamageType.Mental:
			received_damage = damage.num - player.mental_defence
		Damage.DamageType.Real:
			received_damage = damage.num
		
	#防止伤害为负数
	if received_damage < 0:
		received_damage = 0
		
	out_put_num = received_damage
	
func imform_next_action():
	if next_action.get("decrease_num") != null:
		next_action.decrease_num = out_put_num

func reset_property():
	damage = null
	out_put_num = 0
