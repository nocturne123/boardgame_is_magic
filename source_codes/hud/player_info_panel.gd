class_name PlayerInfoPanel
extends PanelContainer

## 显示选中角色的详细信息：HP、护甲、属性、装备、手牌等。

var content_label: RichTextLabel


func _ready() -> void:
    custom_minimum_size = Vector2(220, 0)
    mouse_filter = Control.MOUSE_FILTER_STOP
    gui_input.connect(_on_gui_input)
    _build_ui()


func _build_ui() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.07, 0.06, 0.92)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.25, 0.22, 0.2)
    style.set_corner_radius_all(6)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    add_theme_stylebox_override("panel", style)

    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_FILL
    vbox.size_flags_vertical = Control.SIZE_FILL
    add_child(vbox)

    var title := Label.new()
    title.text = "角色信息"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 14)
    title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
    vbox.add_child(title)

    var sep := HSeparator.new()
    vbox.add_child(sep)

    # 直接用 RichTextLabel，不要包 ScrollContainer。
    # ScrollContainer 限制子控件尺寸为其 minimum_size，RichTextLabel 的
    # get_minimum_size() 始终返回 (1,0)，导致高度为 0 无法渲染。
    content_label = RichTextLabel.new()
    content_label.name = "ContentLabel"
    content_label.bbcode_enabled = true
    content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_label.size_flags_horizontal = Control.SIZE_FILL
    content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_label.add_theme_font_size_override("normal_font_size", 12)
    content_label.add_theme_color_override("default_color", Color(0.85, 0.8, 0.72))
    vbox.add_child(content_label)


func _slot_display_name(slot: Player.EquipmentSlotType) -> String:
    match slot:
        Player.EquipmentSlotType.Weapon:    return "武器"
        Player.EquipmentSlotType.Armor:     return "防具"
        Player.EquipmentSlotType.Element:   return "元素"
        Player.EquipmentSlotType.Collection: return "收藏"
        _:                                 return str(slot)


func _resolve_card_nice_name(p: Player, identity: String) -> String:
    var json: Dictionary = _get_card_json(p, identity)
    if not json.is_empty():
        return json.get("nice_name", identity)
    return identity


func _get_card_json(p: Player, identity: String) -> Dictionary:
    if p == null or p.card_manager == null:
        return {}
    return p.card_manager.get_card_data_by_identity(identity)


func _get_effective_attack_range(p: Player) -> int:
    var r := p.attack_range
    r += p.get_meta("attack_range_bonus", 0)
    var tm = p.get_meta("terrain_manager")
    if tm:
        r += tm.get_attack_range_mod(p)
    return max(r, 1)


func show_player(p: Player) -> void:
    if p == null:
        content_label.text = ""
        return
    var lines: Array[String] = []
    lines.append("[b][color=#f0d060]%s[/color][/b]" % p.player_name)

    var hp_color := "#60f060"
    if p.health <= p.max_health * 0.3:
        hp_color = "#f05050"
    elif p.health <= p.max_health * 0.6:
        hp_color = "#f0c040"
    lines.append("HP: [color=%s]%d / %d[/color]" % [hp_color, p.health, p.max_health])

    lines.append("护甲: %d    速度: %d" % [p.armor, p.speed])
    # 攻击属性
    lines.append("物攻: %d  法攻: %d  心攻: %d" % [p.physical_ability, p.magic_ability, p.mental_ability])
    # 攻击距离（含武器+技能+地形修正）
    var atk_range := _get_effective_attack_range(p)
    var range_color := "#f0d060"
    if atk_range > 1:
        range_color = "#60f060"
    lines.append("攻击距离: [color=%s]%d[/color]" % [range_color, atk_range])
    lines.append("物防: %d  法防: %d  心防: %d" % [p.physical_defence, p.magic_defence, p.mental_defence])

    var state_color := "#60f060"
    var state_text := "存活"
    if p.living_state == Player.LivingState.Dead:
        state_color = "#f05050"
        state_text = "阵亡"
    elif p.living_state == Player.LivingState.Fainted:
        state_color = "#f0a040"
        state_text = "昏迷"
    lines.append("状态: [color=%s]%s[/color]" % [state_color, state_text])
    lines.append("移动次数: %d   攻击次数: %d" % [p.move_chance_in_turn, p.attack_chance_in_turn])

    lines.append("")
    lines.append("[b]手牌 (%d 张)[/b]" % p.get_hand_size())
    for cd in p.get_hand():
        lines.append("  - %s" % cd.nice_name)

    # 装备
    lines.append("")
    lines.append("[b]━━ 装备栏 ━━[/b]")
    for slot in [Player.EquipmentSlotType.Weapon, Player.EquipmentSlotType.Armor, Player.EquipmentSlotType.Element, Player.EquipmentSlotType.Collection]:
        var slot_name: String = _slot_display_name(slot)
        var arr: Array = p.get_equipment_in_slot(slot)
        if arr.is_empty():
            lines.append("  %s: [color=#666]—[/color]" % slot_name)
            continue
        var names: Array[String] = []
        for card in arr:
            var cd: CardData = card as CardData
            names.append(cd.nice_name if cd else "?")
        var line: String = "  %s: %s" % [slot_name, ", ".join(names)]
        if slot == Player.EquipmentSlotType.Weapon:
            if arr.size() > 0:
                line += "  范围: %d" % atk_range
        lines.append(line)

    content_label.text = "\n".join(lines)


func clear() -> void:
    content_label.text = ""


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            accept_event()
