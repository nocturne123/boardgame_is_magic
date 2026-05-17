class_name RollDice extends BaseAction

## 投掷色子，获得 1-6 的点数。结果存在 dice_result，后续动作可通过 inform_next_action 或直接读取使用。

var dice_result: int = 0

func take_action():
    dice_result = randi_range(1, 6)

func inform_next_action():
    if next_action != null and next_action.get("dice_result") != null:
        next_action.dice_result = dice_result

func reset_property():
    dice_result = 0


func _get_action_info() -> String:
    return "%s 掷出了 %d" % [player.player_name, dice_result]
