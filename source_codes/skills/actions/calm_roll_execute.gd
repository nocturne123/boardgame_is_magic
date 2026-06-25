class_name CalmRollExecute extends BaseAction

## 冷静掷骰：替换 RollDiceExecute。
## 内部临时恢复标准链 RollDiceEntry → RollDiceExecute，跑两次掷骰，
## 然后暂停等 HUD 让玩家选择。

var roll1: int = 0
var roll2: int = 0
var chosen: int = 0

func take_action():
    var tree = get_parent() as ActionTree
    if tree == null:
        return
    var entry = tree.get_node_or_null("RollDiceEntry")
    if entry == null:
        return

    # 陆马种族技能判定不生效（正常掷一次，不暂停）
    if entry.purpose == "earth_pony_strength":
        _run_standard_roll(tree)
        return

    # 临时恢复标准链，掷两次
    _run_standard_roll(tree)
    roll1 = entry.dice_result
    _run_standard_roll(tree)
    roll2 = entry.dice_result

    # 暂停等 HUD 让玩家选择
    waiting = true

## 执行一次标准掷骰。不嵌套 chain_of_actions——直接调 roll_dice_execute 的方法，
## 避免覆盖 ActionTree._current_chain_action 导致外层链崩溃（R14）。
func _run_standard_roll(tree: ActionTree) -> void:
    tree.roll_dice_execute.take_action()
    tree.roll_dice_entry.dice_result = tree.roll_dice_execute.dice_result

func inform_next_action():
    var tree = get_parent() as ActionTree
    if tree and chosen > 0:
        var entry = tree.get_node_or_null("RollDiceEntry")
        if entry:
            entry.dice_result = chosen

func reset_property():
    roll1 = 0
    roll2 = 0
    chosen = 0


func _get_action_info() -> String:
    if chosen > 0:
        return "%s 冷静选择了骰子 %d（%d / %d）" % [player.player_name, chosen, roll1, roll2]
    return ""
