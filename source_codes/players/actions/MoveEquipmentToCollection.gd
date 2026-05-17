class_name MoveEquipmentToCollection extends BaseAction

## 将装备栏的收藏品移回收藏品展示栏（触发 on_unequip 取消效果）。
## 参数 slot：来源装备栏位（Weapon / Armor / Element）。
## 仅允许收藏品；非收藏品会拒绝。

var slot: int = Player.EquipmentSlotType.Weapon
var card_identity: String = ""

func take_action() -> void:
    if player == null:
        return
    var arr: Array = player.get_equipment_in_slot(slot as Player.EquipmentSlotType)
    if arr.is_empty():
        return
    for cd in arr:
        if not player.is_collection_item(cd.identity):
            continue
        if not card_identity.is_empty() and cd.identity != card_identity:
            continue
        cd.on_unequip(player, slot as Player.EquipmentSlotType)
        player.move_to_collection_slot(cd)
        return

func reset_property() -> void:
    slot = Player.EquipmentSlotType.Weapon
    card_identity = ""


func _get_action_info() -> String:
    return "%s 将收藏品移入展示栏" % player.player_name
