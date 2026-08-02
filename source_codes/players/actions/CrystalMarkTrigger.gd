class_name CrystalMarkTrigger extends BaseAction

## 水晶洗礼印记触发节点。
## 恢复链最后一环：检查目标是否有水晶洗礼印记，
## 有则移除所有印记，造成等量真实伤害。
## heal_amount 由 HealExecute.inform_next_action 注入（实际恢复量）。

var heal_amount: int = 0
var _triggered: bool = false

func take_action():
    _triggered = false
    if player == null or heal_amount <= 0:
        return
    if not player.has_meta("crystal_marks"):
        return
    var count: int = player.get_meta("crystal_marks")
    if count <= 0:
        return
    # 移除所有印记
    player.remove_meta("crystal_marks")
    _triggered = true
    # 发起真实伤害链：ReceiveDamage → DecreaseHealth → LivingUpdate
    var dmg: Damage = Damage.new()
    dmg.type = Damage.DamageType.Real
    dmg.num = heal_amount
    var tree = player.get_node_or_null("ActionTree")
    if tree and tree.get("receive_damage") != null:
        tree.receive_damage.damage = dmg
        # R14 保护：嵌套链会覆盖 _current_chain_action，跑完后恢复外层链状态
        var saved: BaseAction = tree._current_chain_action
        tree.chain_of_actions(tree.receive_damage)
        tree._current_chain_action = saved

func reset_property():
    heal_amount = 0
    _triggered = false


func _get_action_info() -> String:
    if not _triggered:
        return ""
    return "%s 水晶洗礼印记触发，受到 %d 点真实伤害" % [player.player_name, heal_amount]
