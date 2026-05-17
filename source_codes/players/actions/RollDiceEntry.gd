class_name RollDiceEntry extends BaseAction

## 掷骰入口节点。存储掷骰目的和最终结果。
## 默认链：RollDiceEntry → RollDiceExecute

var purpose: String = ""
var dice_result: int = 0

func take_action():
    pass  # 入口节点，仅存储 purpose 和 dice_result

func inform_next_action():
    if next_action and next_action.get("purpose") != null:
        next_action.purpose = purpose

func reset_property():
    purpose = ""
    dice_result = 0


func _get_action_info() -> String:
    return ""  # 入口节点不输出
