class_name DiceFailureTrigger extends BaseAction

## 骰子失败触发：检查 RollDiceEntry.dice_result，< 3 则自伤 1 点心理伤害。
## 由 TrixieFragilePride 插入到骰子链末端。
## R14 合规：不嵌套 chain_of_actions，直接驱动伤害链各节点方法。

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
        # R14 合规：不显式嵌套 chain_of_actions，直接驱动伤害链各节点方法
        # （ReceiveDamage → DecreaseHealth → LivingUpdate，与默认链一致）。
        # 注意：LivingUpdate 晕厥时内部会启动 heal 链（嵌套 chain_of_actions），
        # 会改写 _current_chain_action —— 因此这里保存/恢复外层链状态。
        var saved := tree._current_chain_action
        tree.receive_damage.damage = dmg
        tree.receive_damage.take_action()
        tree.decrease_health.decrease_num = tree.receive_damage.out_put_num
        tree.decrease_health.skip_armor = dmg.ignore_armor
        tree.decrease_health.take_action()
        tree.living_update.take_action()
        tree._current_chain_action = saved

func reset_property() -> void:
    _failed = false


func _get_action_info() -> String:
    if _failed:
        return "%s 的易碎骄傲触发——受到 1 点心理伤害" % player.player_name
    return ""
