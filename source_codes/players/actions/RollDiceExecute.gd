class_name RollDiceExecute extends BaseAction

## 掷骰执行节点。实际掷骰，结果回传给 RollDiceEntry。

var purpose: String = ""
var dice_result: int = 0

func take_action():
    dice_result = randi_range(1, 6)

func inform_next_action():
    var tree = get_parent() as ActionTree
    if tree == null:
        return
    var entry = tree.get_node_or_null("RollDiceEntry")
    if entry:
        entry.dice_result = dice_result

func reset_property():
    purpose = ""
    dice_result = 0


func _get_action_info() -> String:
    return "%s 掷骰结果：%d" % [player.player_name, dice_result]
