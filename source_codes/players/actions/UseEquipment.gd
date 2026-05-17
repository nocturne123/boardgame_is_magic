class_name UseEquipment extends BaseAction

## UseCard 的子节点：处理装备牌（Weapon / Armor / Element）。
## 参数由 UseCard.inform_next_action() 注入。

var card: CardData = null
var target: Player = null

func take_action() -> void:
    if card == null:
        return

    var eq := card as BaseEquipment
    var equipment_blocked: bool = false

    # 检查栏位是否被收藏品占用
    if player.is_slot_occupied_by_collection(eq.get_equipment_slot_type()):
        equipment_blocked = true
    else:
        # 正常装备：execute() 内部处理装备逻辑 + 设置 replaced_old_card
        card.execute(player, target, player.card_manager)

    # 从手牌移除
    player.remove_card_from_hand(card)

    if equipment_blocked:
        # 被收藏品挡住 → 打入的牌进弃牌堆
        if player.card_manager:
            player.card_manager.receive_into_discard(card)
    else:
        # 装备成功，处理被替换的旧牌
        var old_card: CardData = eq.replaced_old_card
        if old_card != null:
            if player.is_collection_item(old_card.identity):
                player._add_to_slot(Player.EquipmentSlotType.Collection, old_card)
            elif player.card_manager:
                player.card_manager.receive_into_discard(old_card)

func reset_property() -> void:
    card = null
    target = null


func _get_action_info() -> String:
    if card == null:
        return ""
    return "%s 装备了 [%s]" % [player.player_name, card.nice_name]
