class_name BaseArmor extends BaseEquipment

## 防具牌：装备牌的一种，对应装备栏位 Armor。
## 装备时：物理防御 +1，魔法防御 +1。卸下时恢复。

@export var physical_defence_bonus: int = 1
@export var magic_defence_bonus: int = 1

func _init() -> void:
    equipment_slot = "Armor"

func get_equipment_slot_type() -> Player.EquipmentSlotType:
    return Player.EquipmentSlotType.Armor

func on_equip(_player: Player, _slot: int) -> void:
    super(_player, _slot)
    _player.physical_defence += physical_defence_bonus
    _player.magic_defence += magic_defence_bonus

func on_unequip(_player: Player, _slot: int) -> void:
    super(_player, _slot)
    _player.physical_defence -= physical_defence_bonus
    _player.magic_defence -= magic_defence_bonus
