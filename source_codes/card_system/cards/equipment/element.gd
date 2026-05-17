class_name BaseElement extends BaseEquipment

## 元素牌：装备牌的一种，对应装备栏位 Element。

func _init() -> void:
    equipment_slot = "Element"

func get_equipment_slot_type() -> Player.EquipmentSlotType:
    return Player.EquipmentSlotType.Element
