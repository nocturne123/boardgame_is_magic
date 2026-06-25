class_name UseBaseplay extends BaseAction

## UseCard 的子节点：处理普通卡牌（Attack / Steal 等）。
## 参数由 UseCard.inform_next_action() 注入。
## strength_bonus 由蛮力掷骰节点注入（0=无加成，1=伤害+1）。

var card: CardData = null
var target: Player = null
var strength_bonus: int = 0

func take_action() -> void:
    if card == null:
        return

    var handled: bool = card.execute(player, target, player.card_manager)
    if not handled:
        # fallback：攻击牌走 resolve → Damage，通过目标 ActionTree 的伤害链
        var result: Variant = card.resolve(player, target)
        if result is Damage:
            # 法杖魔力灌注：攻击牌转化为魔法攻击
            if player.has_meta("equip_staff_magic") and player.get_meta("equip_staff_magic"):
                if card is BaseAttack:
                    (result as Damage).type = Damage.DamageType.Magic
                    (result as Damage).num = int(player.magic_ability)
            # 蛮力加成
            if strength_bonus > 0:
                (result as Damage).num += strength_bonus
            # ★ 全局效果：攻击端伤害修正（入戏太深等）
            var event_mgr = player.get_meta("event_manager")
            if event_mgr:
                (result as Damage).num += event_mgr.get_outgoing_damage_modifiers(player, (result as Damage).type)
            var target_tree := target.get_node_or_null("ActionTree")
            if target_tree != null and target_tree.get("receive_damage") != null:
                target_tree.receive_damage.damage = result as Damage
                target_tree.chain_of_actions(target_tree.receive_damage)

    player.remove_card_from_hand(card)

    if player.is_collection_item(card.identity):
        player._add_to_slot(Player.EquipmentSlotType.Collection, card)
    elif player.card_manager:
        player.card_manager.receive_into_discard(card)

    # 攻击牌递减攻击次数
    if card.type == "Attack":
        player.attack_chance_in_turn -= 1
        # 派对大炮：攻击后恢复判定
        if player.has_meta("party_cannon_enabled") and player.get_meta("party_cannon_enabled"):
            var tree := player.get_node_or_null("ActionTree")
            if tree:
                var recovery := tree.get_node_or_null("PartyCannonRecovery")
                if recovery:
                    recovery.player = player
                    next_action = recovery

func reset_property() -> void:
    card = null
    target = null
    strength_bonus = 0


func _get_action_info() -> String:
    if card == null:
        return ""
    var target_name := target.player_name if target else "?"
    return "%s 对 %s 使用了 [%s]" % [player.player_name, target_name, card.nice_name]
