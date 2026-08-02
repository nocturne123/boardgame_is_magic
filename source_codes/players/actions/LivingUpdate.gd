class_name LivingUpdate extends BaseAction

## 伤害链最后一环：根据当前 HP 判定存活状态。
## HP > 0：无操作（存活）。
## HP <= 0 且有收藏品 → 晕厥（Fainted）：弃 1 个收藏品，
##   通过恢复链（HealEntry → HealExecute → CrystalMarkTrigger）恢复体力上限一半，
##   设 immune_from_attack = true（到下回合开始前免伤）。
## HP <= 0 且无收藏品 → 淘汰（Dead）。
var _living_result: String = ""

func take_action():
    _living_result = ""
    if player.health > 0:
        return

    var collection_items: Array = player.get_all_collection_items()
    if collection_items.is_empty():
        player.living_state = player.LivingState.Dead
        _living_result = "阵亡"
        return

    # --- 晕厥（苏醒）---
    player.living_state = player.LivingState.Fainted
    _living_result = "昏迷"

    # 弃 1 个收藏品：优先从 Collection 槽弃，其次从功能槽弃
    var card_to_discard: CardData = collection_items[0] as CardData
    var slot: int = player.get_slot_of_card(card_to_discard)
    if slot >= 0:
        var removed: CardData = player._remove_from_slot(slot as Player.EquipmentSlotType, 0)
        if removed and removed.has_method("on_unequip"):
            removed.on_unequip(player, slot)
        if player.card_manager:
            player.card_manager.receive_into_discard(removed)

    # 到下回合开始前免伤
    player.immune_from_attack = true

    # 通过恢复链恢复体力：HealEntry → HealExecute → CrystalMarkTrigger
    var heal_amount: int = ceili(player.max_health / 2.0)
    var tree = player.get_node_or_null("ActionTree")
    if tree and tree.get("heal_entry") != null:
        tree.heal_entry.heal_amount = heal_amount
        # R14 保护：嵌套链会覆盖 _current_chain_action，跑完后恢复外层链状态
        var saved: BaseAction = tree._current_chain_action
        tree.chain_of_actions(tree.heal_entry)
        tree._current_chain_action = saved

func reset_property():
    _living_result = ""


func _get_action_info() -> String:
    if _living_result.is_empty():
        return ""
    return "%s %s" % [player.player_name, _living_result]
