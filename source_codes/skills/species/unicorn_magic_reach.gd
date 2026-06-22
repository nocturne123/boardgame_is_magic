class_name UnicornMagicReach extends SkillData

## 魔法触及（独角兽种族技能）：攻击距离 +1。
## 纯被动技能，不修改 ActionTree 链条。
## on_attach 时在 player 上设置 meta "attack_range_bonus"，
## HUD 距离校验和 player_info_panel 读取此值计算实际攻击范围。

func _init() -> void:
	id = "unicorn_magic_reach"
	nice_name = "魔法触及"
	category = SkillData.Category.Species
	skill_type = SkillData.SkillType.Passive
	description = "攻击距离 +1（装备武器的攻击范围额外增加 1 格）"
	ignore_distance = false
	range = -1
	cooldown = 0
	max_uses_per_turn = 0
	needs_target = false

func on_attach(player: Player) -> void:
	if is_disabled():
		return
	player.set_meta("attack_range_bonus", 1)

func on_detach(player: Player) -> void:
	player.remove_meta("attack_range_bonus")
	super.on_detach(player)
