class_name DiceFailureTrigger extends BaseAction

## 骰子失败触发：检查 RollDiceEntry.dice_result，< 3 则启动自身伤害链。
## 由 TrixieFragilePride 插入到骰子链末端。R14 安全：保存/恢复 _current_chain_action。

var _failed: bool = false

func take_action() -> void:
    var tree: ActionTree = get_parent() as ActionTree
    if tree == null:
        return
    var result: int = tree.roll_dice_entry.dice_result
    if result <= 0:
        return
    if result < 3:
        _failed = true
        var dmg := Damage.new()
        dmg.type = Damage.DamageType.Mental
        dmg.num = 1
        tree.receive_damage.damage = dmg
        # R14 安全：保存外层链状态，内层伤害链跑完后恢复
        var saved := tree._current_chain_action
        tree.chain_of_actions(tree.receive_damage)
        tree._current_chain_action = saved

func reset_property() -> void:
    _failed = false


func _get_action_info() -> String:
    if _failed:
        return "%s 的易碎骄傲触发——受到 1 点心理伤害" % player.player_name
    return ""
