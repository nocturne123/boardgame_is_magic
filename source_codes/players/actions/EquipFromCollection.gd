class_name EquipFromCollection extends BaseAction

## 将收藏品从 Collection 栏位装回武器/防具栏。
## 仅 Weapon / Armor 类型收藏品。效果/恢复类不参与。
## 若目标栏已有装备 → 先卸下（非收藏品 → 弃牌堆，收藏品 → Collection），再装收藏品。

var slot: int = Player.EquipmentSlotType.Weapon
var card_identity: String = ""

func take_action() -> void:
    if player == null:
        return

    # 仅 Weapon 和 Armor
    if slot != Player.EquipmentSlotType.Weapon and slot != Player.EquipmentSlotType.Armor:
        return

    var coll: Array = player.get_equipment_in_slot(Player.EquipmentSlotType.Collection)
    if coll.is_empty():
        return

    # 按 identity 查找指定收藏品；未指定时取第一个（向后兼容）
    var card_to_equip: CardData = null
    for cd in coll:
        if not player.is_collection_item(cd.identity):
            continue
        if card_identity.is_empty() or cd.identity == card_identity:
            card_to_equip = cd
            break

    if card_to_equip == null:
        return

    # 类型安全：收藏品类型必须匹配目标槽位
    var type_matches: bool = false
    match card_to_equip.type:
        "Weapon": type_matches = (slot == Player.EquipmentSlotType.Weapon)
        "Armor":  type_matches = (slot == Player.EquipmentSlotType.Armor)
    if not type_matches:
        return

    # 若目标栏已有装备，先卸下
    var target_arr: Array = player.get_equipment_in_slot(slot as Player.EquipmentSlotType)
    if not target_arr.is_empty():
        var old_card: CardData = player._remove_from_slot(slot as Player.EquipmentSlotType, 0)
        if old_card != null:
            old_card.on_unequip(player, slot)
            if player.is_collection_item(old_card.identity):
                player._add_to_slot(Player.EquipmentSlotType.Collection, old_card)
            elif player.card_manager:
                player.card_manager.receive_into_discard(old_card)

    # 将收藏品移入装备栏
    player.move_from_collection_to_slot(card_to_equip, slot as Player.EquipmentSlotType)
    card_to_equip.on_equip(player, slot)

func reset_property() -> void:
    slot = Player.EquipmentSlotType.Weapon
    card_identity = ""


func _get_action_info() -> String:
    var slot_name := "武器" if slot == Player.EquipmentSlotType.Weapon else "防具"
    return "%s 从收藏栏装备到 %s 栏" % [player.player_name, slot_name]
