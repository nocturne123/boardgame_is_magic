class_name UseEffect extends BaseAction

## UseCard 的子节点：处理效果牌（Gem / Recovery 等 BaseEffect 子类）。
## 参数由 UseCard.inform_next_action() 注入。

var card: CardData = null
var target: Player = null
var _blocked_reason: String = ""

func take_action() -> void:
    _blocked_reason = ""
    if card == null:
        return
    # ★ 雪地地形阻止恢复牌
    if card.type == "Recovery":
        var tm = player.get_meta("terrain_manager")
        if tm and tm.has_method("is_recovery_blocked") and tm.is_recovery_blocked(player):
            # 不能静默 return：玩家会以为牌打出去了。记下原因交给战斗日志
            _blocked_reason = "[color=#f06060]雪地：无法打出恢复牌 [%s][/color]" % card.nice_name
            return
    card.execute(player, target, player.card_manager)

    player.remove_card_from_hand(card)

    if player.is_collection_item(card.identity):
        player._add_to_slot(Player.EquipmentSlotType.Collection, card)
    elif player.card_manager:
        player.card_manager.receive_into_discard(card)

func reset_property() -> void:
    card = null
    target = null


func _get_action_info() -> String:
    if not _blocked_reason.is_empty():
        return _blocked_reason
    if card == null:
        return ""
    var target_name := target.player_name if target and target != player else ""
    var target_str := "对 " + target_name + " " if not target_name.is_empty() else ""
    return "%s %s使用了 [%s]" % [player.player_name, target_str, card.nice_name]
