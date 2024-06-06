class_name LivingUpdate extends BaseAction


# Called when the node enters the scene tree for the first time.
func take_action():
	if player.health <= 0:
		player.living_state = player.LivingState.Dead
