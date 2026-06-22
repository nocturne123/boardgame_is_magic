class_name HealExecute extends BaseAction

## 生命恢复链生效节点。
## 实际修改 player.health，上限不超过 max_health。
## heal_amount 由 HealEntry.inform_next_action 注入。

var heal_amount: int = 0
var _actual_healed: int = 0

func take_action():
    if player == null or heal_amount <= 0:
        return
    var before: int = player.health
    player.health = min(player.health + heal_amount, player.max_health)
    _actual_healed = player.health - before

func inform_next_action():
    # 传递实际恢复量（非请求量）给 CrystalMarkTrigger
    if next_action and next_action.get("heal_amount") != null:
        next_action.heal_amount = _actual_healed

func reset_property():
    heal_amount = 0
    _actual_healed = 0


func _get_action_info() -> String:
    if _actual_healed <= 0:
        return ""
    return "%s 恢复了 %d 点体力" % [player.player_name, _actual_healed]
