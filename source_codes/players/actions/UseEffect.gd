class_name UseEffect extends BaseAction

## UseCard 的子节点：处理效果牌（Gem / Recovery 等 BaseEffect 子类）。
## 参数由 UseCard.inform_next_action() 注入。

var card: CardData = null
var target: Player = null

func take_action() -> void:
    if card == null:
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
    if card == null:
        return ""
    var target_name := target.player_name if target and target != player else ""
    var target_str := "对 " + target_name + " " if not target_name.is_empty() else ""
    return "%s %s使用了 [%s]" % [player.player_name, target_str, card.nice_name]
