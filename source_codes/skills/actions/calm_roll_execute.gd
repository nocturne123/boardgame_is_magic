class_name CalmRollExecute extends BaseAction

## 冷静掷骰：替换 RollDiceExecute。
## 陆马种族技能判定不生效（正常掷一次）。
## 其他情况掷两次，暂停等 HUD 让玩家选择。

var roll1: int = 0
var roll2: int = 0
var chosen: int = 0

func take_action():
    var entry = _find_roll_entry()
    if entry == null:
        return
    # 陆马种族技能判定不生效
    if entry.purpose == "earth_pony_strength":
        entry.dice_result = randi_range(1, 6)
        return
    # 掷两次
    roll1 = randi_range(1, 6)
    roll2 = randi_range(1, 6)
    # 暂停等 HUD 让玩家选择
    waiting = true

func inform_next_action():
    var entry = _find_roll_entry()
    if entry and chosen > 0:
        entry.dice_result = chosen

func reset_property():
    roll1 = 0
    roll2 = 0
    chosen = 0


func _get_action_info() -> String:
    if chosen > 0:
        return "%s 冷静选择了骰子 %d" % [player.player_name, chosen]
    return ""

func _find_roll_entry() -> BaseAction:
    var tree = get_parent() as ActionTree
    return tree.get_node_or_null("RollDiceEntry")
