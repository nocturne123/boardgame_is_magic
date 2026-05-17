class_name BaseEquipment extends Baseplay

## 装备牌基类。武器牌、防具牌、元素牌继承此类。
## 打出时自动装备到对应栏位（通过 execute 实现）。
## execute() 替换旧装备时，将旧牌存入 replaced_old_card，由 UseCard 决定去向。
## on_equip/on_unequip 自动挂接/卸下 skill_ids 中的技能。子类调 super 继承此行为。

var replaced_old_card: CardData = null

func format_description() -> String:
    return description if description else ""

func resolve(_source: Player, _target: Player) -> Variant:
    return null

## 打出装备牌：从手牌装备到对应栏位。若该栏已有装备，卸下旧的（触发 on_unequip），
## 并将旧牌存入 replaced_old_card 供 UseCard 后处理。
func execute(source: Player, _target: Player, _card_manager: CardManager) -> bool:
    replaced_old_card = null
    var slot := get_equipment_slot_type()
    # 若栏位已有装备，卸下旧的（触发 on_unequip 移除效果 + 卸下技能）
    var existing: Array = source.get_equipment_in_slot(slot)
    if not existing.is_empty():
        replaced_old_card = source._remove_from_slot(slot, 0)
        if replaced_old_card:
            replaced_old_card.on_unequip(source, slot)
    source._add_to_slot(slot, self)
    self.on_equip(source, slot)
    return true

## 装备时：挂接 skill_ids 中的技能。子类应调 super.on_equip() 继承此行为。
func on_equip(player: Player, _slot: int) -> void:
    for sid in skill_ids:
        var sm = _find_skill_manager(player)
        if sm:
            var skill = sm.create_skill(sid)
            if skill:
                player.add_skill(skill)

## 卸下时：卸下 skill_ids 对应的技能。子类应调 super.on_unequip() 继承此行为。
func on_unequip(player: Player, _slot: int) -> void:
    for sid in skill_ids:
        for s in player.skills:
            if s.id == sid:
                player.remove_skill(s)
                break

## 查找 SkillManager 节点（向上遍历场景树）
func _find_skill_manager(player: Player) -> Node:
    var scene = player.get_tree().current_scene
    if scene:
        return scene.get_node_or_null("logic/SkillManager")
    return null

## 返回此装备对应的栏位类型
func get_equipment_slot_type() -> Player.EquipmentSlotType:
    match equipment_slot:
        "Weapon":
            return Player.EquipmentSlotType.Weapon
        "Armor":
            return Player.EquipmentSlotType.Armor
        "Element":
            return Player.EquipmentSlotType.Element
    return Player.EquipmentSlotType.Weapon
