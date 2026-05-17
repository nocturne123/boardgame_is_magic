class_name BaseAttack extends Baseplay

## 参数化的攻击牌基类。
## 子类只需在 _init() 中设置 damage_type 和 ability_name。
## 派生类：PhysicalAttack、MagicAttack、MentalAttack
@export var damage_type: Damage.DamageType = Damage.DamageType.Physical
@export var ability_name: String = "physical_ability"

func format_description() -> String:
    match damage_type:
        Damage.DamageType.Physical:
            return "物理攻击"
        Damage.DamageType.Magic:
            return "魔法攻击"
        Damage.DamageType.Mental:
            return "心理攻击"
    return "攻击"

func resolve(source: Player, target: Player) -> Variant:
    var dmg: Damage = Damage.new()
    dmg.type = damage_type
    dmg.num = int(source.get(ability_name))

    # 消费攻击方的下次攻击增益（Gem 宝石等 buff）
    if damage_type == Damage.DamageType.Mental:
        if source.next_mental_bonus != 0:
            dmg.num += source.next_mental_bonus
            source.next_mental_bonus = 0
        if source.next_mental_ignore_armor:
            dmg.ignore_armor = true
            source.next_mental_ignore_armor = false

    return dmg
