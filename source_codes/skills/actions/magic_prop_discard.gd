class_name MagicPropDiscard extends BaseAction

## 魔术道具弃牌清理节点：接在 UseBaseplay 之后。
## - 攻击链正常走完：检查 generation 匹配 → 弃置暂存卡牌
## - 攻击链被阻断（RangeCheck 失败）：此节点不会执行，卡牌保留手牌中
## - 残留调用（下次攻击时误触发）：generation 不匹配 → 只恢复链，不弃牌

var reserved_card: CardData = null
var restore_target: UseBaseplay = null
var restore_next: BaseAction = null
var _gen: int = 0

func take_action() -> void:
    if player == null:
        # 无 player（测试/异常路径）：只恢复链，不弃牌
        if restore_target:
            restore_target.next_action = restore_next
        queue_free()
        return
    var current_gen: int = player.get_meta("magic_prop_gen", 0)
    if reserved_card != null and _gen == current_gen:
        player.remove_card_from_hand(reserved_card)
        if player.card_manager:
            player.card_manager.receive_into_discard(reserved_card)
        player.set_meta("magic_prop_gen", 0)  # 消费后清零
    # 恢复 UseBaseplay 的原始链
    if restore_target:
        restore_target.next_action = restore_next
    # 本节点是一次性临时节点，执行完自清理（防止 ActionTree 上堆积）
    queue_free()

func reset_property() -> void:
    reserved_card = null
    restore_target = null
    restore_next = null
    _gen = 0


func _get_action_info() -> String:
    return ""
