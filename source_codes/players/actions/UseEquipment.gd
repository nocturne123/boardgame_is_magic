class_name UseEquipment extends BaseAction

## UseCard 的子节点：处理装备牌（Weapon / Armor / Element）。
## 参数由 UseCard.inform_next_action() 注入。

var card: CardData = null
var target: Player = null
var _old_card_nice: String = ""
var _new_info: String = ""

func take_action() -> void:
    if card == null:
        return

    var eq := card as BaseEquipment
    var equipment_blocked: bool = false

    # 检查栏位是否被非同类型收藏品占用（同类型装备即使是收藏品也允许替换）
    if player.is_slot_occupied_by_collection(eq.get_equipment_slot_type()):
        var existing: Array = player.get_equipment_in_slot(eq.get_equipment_slot_type())
        if existing.is_empty() or not (existing[0] is BaseEquipment):
            equipment_blocked = true
        elif (existing[0] as BaseEquipment).get_equipment_slot_type() != eq.get_equipment_slot_type():
            equipment_blocked = true

    if equipment_blocked:
        # 被非同类型收藏品挡住 → 打入的牌进弃牌堆
        player.remove_card_from_hand(card)
        if player.card_manager:
            player.card_manager.receive_into_discard(card)
    else:
        # 正常装备：execute() 内部处理装备逻辑 + 设置 replaced_old_card
        card.execute(player, target, player.card_manager)
        player.remove_card_from_hand(card)

        # 装备成功，记录日志信息
        _new_info = _card_info(card)
        var old_card: CardData = eq.replaced_old_card
        if old_card != null:
            _old_card_nice = old_card.nice_name
            if player.is_collection_item(old_card.identity):
                player._add_to_slot(Player.EquipmentSlotType.Collection, old_card)
            elif player.card_manager:
                player.card_manager.receive_into_discard(old_card)

func _card_info(cd: CardData) -> String:
    var s := cd.nice_name
    if cd is BaseWeapon:
        s += "（范围 %d）" % (cd as BaseWeapon).attack_range
    return s

func reset_property() -> void:
    card = null
    target = null
    _old_card_nice = ""
    _new_info = ""


func _get_action_info() -> String:
    if card == null:
        return ""
    if _old_card_nice.is_empty():
        return "%s 装备了 [%s]" % [player.player_name, _new_info]
    return "%s 装备了 [%s]，替换了 [%s]" % [player.player_name, _new_info, _old_card_nice]
