class_name StealCard extends Baseplay

## 偷牌：优先偷取目标一张手牌；若无手牌则弃置目标一件装备（武器 > 防具 > 元素）。
## 两者皆无时取消使用（卡牌保留在手牌中）。
## 手牌移除和弃牌由 UseCard 统一后处理，此处只做偷取逻辑。

func format_description() -> String:
    return "选择：偷取目标一张手牌，或弃置目标一张装备牌"

func resolve(_source: Player, _target: Player) -> Variant:
    return {
        "type": "steal_card_choice",
        "source": _source,
        "target": _target,
    }

func execute(_source: Player, target: Player, _card_manager: CardManager) -> bool:
    if target.get_hand_size() > 0:
        # 通过容器方法偷手牌（R4：容器操作走 Player 方法，自动发信号）
        var stolen: CardData = target.hand[target.hand.size() - 1]
        target.remove_card_from_hand(stolen)
        _source.add_card_to_hand(stolen)
        return true
    for slot in [Player.EquipmentSlotType.Weapon, Player.EquipmentSlotType.Armor, Player.EquipmentSlotType.Element]:
        var arr: Array = target.get_equipment_in_slot(slot)
        if not arr.is_empty():
            # 收藏品装备不可被偷，跳过此栏位
            var is_collection_slot: bool = false
            for cd in arr:
                if target.is_collection_item(cd.identity):
                    is_collection_slot = true
                    break
            if is_collection_slot:
                continue
            var stolen_equip: CardData = arr.pop_back() as CardData
            stolen_equip.on_unequip(target, slot)
            target.equipment[slot] = arr
            # 被偷装备进目标弃牌堆（规则：弃掉他一个装备），并刷新装备栏 UI
            if target.card_manager:
                target.card_manager.receive_into_discard(stolen_equip)
            target.equipment_changed.emit(slot)
            return true
    return false
