class_name StrengthRollExecute extends BaseAction

## 蛮力掷骰执行。掷骰，结果>=3 则 strength_bonus=1。

var purpose: String = ""
var dice_result: int = 0
var strength_bonus: int = 0

func take_action():
    dice_result = randi_range(1, 6)
    strength_bonus = 1 if dice_result >= 3 else 0

func inform_next_action():
    if next_action and next_action.get("strength_bonus") != null:
        next_action.strength_bonus = strength_bonus

func reset_property():
    purpose = ""
    dice_result = 0
    strength_bonus = 0


func _get_action_info() -> String:
    if strength_bonus > 0:
        return "%s 蛮力判定成功（骰子 %d）" % [player.player_name, dice_result]
    return "%s 蛮力判定失败（骰子 %d）" % [player.player_name, dice_result]
