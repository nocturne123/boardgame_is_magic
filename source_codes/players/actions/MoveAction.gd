class_name MoveAction extends BaseAction

var target_cell: Vector2i = Vector2i.ZERO

func take_action() -> void:
    if player == null:
        return
    player.move_to_position(target_cell)
    player.move_chance_in_turn -= 1

func reset_property() -> void:
    target_cell = Vector2i.ZERO


func _get_action_info() -> String:
    return "%s 移动到 (%d, %d)" % [player.player_name, target_cell.x, target_cell.y]
