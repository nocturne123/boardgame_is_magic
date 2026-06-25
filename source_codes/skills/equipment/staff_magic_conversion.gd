class_name StaffMagicConversion extends SkillData

## 法杖装备技能：所有攻击牌转化为魔法攻击，使用魔法能力计算伤害。
## 纯被动，设 meta "equip_staff_magic"，由 UseBaseplay 读取。

func _init() -> void:
    id = "staff_magic_conversion"
    nice_name = "魔力灌注"
    category = SkillData.Category.Equipment
    skill_type = SkillData.SkillType.Passive
    description = "所有攻击牌转化为魔法攻击，使用魔法能力计算伤害。可开关。"
    ignore_distance = false
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = false

func on_attach(player: Player) -> void:
    if is_disabled():
        return
    player.set_meta("equip_staff_magic", true)

func on_detach(player: Player) -> void:
    player.remove_meta("equip_staff_magic")
    super.on_detach(player)
