class_name BaseWeapon extends BaseEquipment

## 武器牌：装备牌的一种，对应装备栏位 Weapon。
## 攻击距离：打出攻击牌时，只能指定与此距离内的角色为目标（基于地图格距离）。
@export var attack_range: int = 1:
    set(v):
        attack_range = max(v, 1)  # 攻击范围最小为 1

func _init() -> void:
    equipment_slot = "Weapon"

func get_equipment_slot_type() -> Player.EquipmentSlotType:
    return Player.EquipmentSlotType.Weapon
