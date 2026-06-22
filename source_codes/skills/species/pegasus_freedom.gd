class_name PegasusFreedom extends SkillData

## 自由翱翔（天马种族技能）：可以主动选择是否受到地形效果。
## 纯被动技能，on_attach 时设 meta "terrain_immune" = true。
## HUD 可通过 set_terrain_enabled 切换开关。

var _terrain_enabled: bool = false  # false=免疫地形(默认), true=受地形影响

func _init() -> void:
    id = "pegasus_freedom"
    nice_name = "自由翱翔"
    category = SkillData.Category.Species
    skill_type = SkillData.SkillType.Passive
    description = "可以主动选择是否受到地形效果。点击技能槽切换开关。"
    ignore_distance = false
    range = -1
    cooldown = 0
    max_uses_per_turn = 0
    needs_target = false

func on_attach(player: Player) -> void:
    if is_disabled():
        return
    _update_terrain_meta(player)

func on_detach(player: Player) -> void:
    player.remove_meta("terrain_immune")
    super.on_detach(player)

## 切换地形影响开关。enabled=true 受地形影响，false=免疫。
func set_terrain_enabled(player: Player, enabled: bool) -> void:
    _terrain_enabled = enabled
    _update_terrain_meta(player)

func is_terrain_enabled() -> bool:
    return _terrain_enabled

func _update_terrain_meta(player: Player) -> void:
    if is_disabled():
        player.remove_meta("terrain_immune")
        return
    # terrain_immune = true 表示免疫（不受地形影响）
    # _terrain_enabled = true 表示要受地形影响 → immune = false
    player.set_meta("terrain_immune", not _terrain_enabled)
