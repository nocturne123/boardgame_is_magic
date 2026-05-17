class_name StrengthRollEntry extends BaseAction

## 蛮力掷骰入口。传递 purpose 给下游。

var purpose: String = "earth_pony_strength"

func take_action():
    pass

func inform_next_action():
    if next_action and next_action.get("purpose") != null:
        next_action.purpose = purpose

func reset_property():
    purpose = "earth_pony_strength"


func _get_action_info() -> String:
    return ""  # 入口节点不输出
