class_name UnequipAction extends BaseAction

## 主动卸下非收藏品装备。
## 参数 slot：要卸下的装备栏位（Weapon / Armor / Element）。
## 若该栏的牌是收藏品 → 拒绝，发射 unequip_blocked 信号。

var slot: int = Player.EquipmentSlotType.Weapon

signal unequip_blocked(reason: String)

func take_action() -> void:
    if player == null:
        return
    var arr: Array = player.get_equipment_in_slot(slot as Player.EquipmentSlotType)
    if arr.is_empty():
        return
    # 收藏品不可主动卸下 → 通知 HUD
    for cd in arr:
        if player.is_collection_item(cd.identity):
            unequip_blocked.emit("收藏品无法弃置")
            return
    var unequipped: CardData = player._remove_from_slot(slot as Player.EquipmentSlotType, 0)
    if unequipped != null:
        unequipped.on_unequip(player, slot)
        if player.card_manager:
            player.card_manager.receive_into_discard(unequipped)

func reset_property() -> void:
    slot = Player.EquipmentSlotType.Weapon


func _get_action_info() -> String:
    var slot_name := ""
    match slot:
        Player.EquipmentSlotType.Weapon:  slot_name = "武器"
        Player.EquipmentSlotType.Armor:   slot_name = "防具"
        Player.EquipmentSlotType.Element: slot_name = "元素"
    return "%s 卸下了 %s 栏的装备" % [player.player_name, slot_name]
