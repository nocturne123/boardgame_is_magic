class_name ReceiveDamage extends BaseAction

var damage:Damage
var out_put_num:int

func take_action():
    # 苏醒免伤：到下回合开始前不受伤害
    if player.immune_from_attack:
        out_put_num = 0
        return

    var received_damage:int
    match damage.type:
        Damage.DamageType.Physical:
            received_damage = damage.num - player.physical_defence
        Damage.DamageType.Magic:
            received_damage = damage.num - player.magic_defence
        Damage.DamageType.Mental:
            received_damage = damage.num - player.mental_defence
            # 宝石 buff：额外伤害 + 护甲穿透（由 BaseAttack.resolve 在创建 Damage 时消费，注入 damage.num / damage.ignore_armor）
        Damage.DamageType.Real:
            received_damage = damage.num
        
    #防止伤害为负数
    if received_damage < 0:
        received_damage = 0
        
    out_put_num = received_damage
    
func inform_next_action():
    if next_action.get("decrease_num") != null:
        next_action.decrease_num = out_put_num
    if next_action.get("skip_armor") != null:
        next_action.skip_armor = damage.ignore_armor if damage else false

func reset_property():
    damage = null
    out_put_num = 0


func _get_action_info() -> String:
    if damage == null:
        return ""
    var type_str := ""
    match damage.type:
        Damage.DamageType.Physical: type_str = "物理"
        Damage.DamageType.Magic:    type_str = "魔法"
        Damage.DamageType.Mental:   type_str = "精神"
        Damage.DamageType.Real:     type_str = "真实"
    return "%s 受到 %d 点%s伤害" % [player.player_name, damage.num, type_str]
