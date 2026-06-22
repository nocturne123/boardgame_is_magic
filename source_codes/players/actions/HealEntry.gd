class_name HealEntry extends BaseAction

## 生命恢复链入口节点。
## 接收 heal_amount，传递给下游 HealExecute。
## 用法：tree.heal_entry.heal_amount = N; tree.chain_of_actions(tree.heal_entry)

var heal_amount: int = 0

func take_action():
    pass

func inform_next_action():
    if next_action and next_action.get("heal_amount") != null:
        next_action.heal_amount = heal_amount

func reset_property():
    heal_amount = 0


func _get_action_info() -> String:
    return ""  # 入口节点不输出
