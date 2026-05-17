class_name SkillSlot
extends Control

## 圆形技能槽。显示技能名称，区分主动/被动（实线/虚线描边），失效时半透明。
## 悬停时通过信号通知 HUD 显示技能描述。

signal skill_hovered(skill: SkillData)
signal skill_unhovered()
signal skill_clicked(skill: SkillData)

const SLOT_SIZE: float = 56.0
const BORDER_WIDTH: float = 2.5
const RADIUS: float = SLOT_SIZE / 2.0

# 按技能类别区分描边颜色
const COLOR_SPECIES: Color = Color(0.3, 0.8, 0.4, 1.0)
const COLOR_CHARACTER: Color = Color(1.0, 0.84, 0.0, 1.0)
const COLOR_EQUIPMENT: Color = Color(0.6, 0.4, 0.8, 1.0)

var _skill: SkillData = null
var _name_label: Label


func _ready() -> void:
    custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_label()
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)


func _build_label() -> void:
    _name_label = Label.new()
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    _name_label.add_theme_font_size_override("font_size", 9)
    _name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
    _name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    _name_label.add_theme_constant_override("shadow_offset_x", 1)
    _name_label.add_theme_constant_override("shadow_offset_y", 1)
    _name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_name_label)


# ---- 公共 API ----

func set_skill(skill: SkillData) -> void:
    if _skill and _skill.is_connected("disabled_changed", _on_skill_disabled_changed):
        _skill.disabled_changed.disconnect(_on_skill_disabled_changed)
    _skill = skill
    if _skill:
        _name_label.text = _skill.nice_name
        if not _skill.disabled_changed.is_connected(_on_skill_disabled_changed):
            _skill.disabled_changed.connect(_on_skill_disabled_changed)
    else:
        _name_label.text = ""
    queue_redraw()


func get_skill() -> SkillData:
    return _skill


# ---- 绘制 ----

func _draw() -> void:
    var center := Vector2(RADIUS, RADIUS)

    if _skill == null:
        # 空槽：淡色圆
        draw_circle(center, RADIUS - 1.0, Color(0.08, 0.07, 0.06, 0.5))
        return

    var alpha := 0.35 if _skill.is_disabled() else 1.0
    var border_color := _get_border_color()

    # 背景填充
    draw_circle(center, RADIUS - 1.0, Color(0.12, 0.1, 0.08, alpha * 0.92))

    # 描边：主动=实线，被动=虚线
    var c := Color(border_color.r, border_color.g, border_color.b, alpha)
    if _skill.skill_type == SkillData.SkillType.Active:
        draw_arc(center, RADIUS - BORDER_WIDTH / 2.0, 0.0, TAU, 64, c, BORDER_WIDTH)
    else:
        _draw_dashed_circle(center, RADIUS - BORDER_WIDTH / 2.0, c, BORDER_WIDTH, 12)

    # 主动技能内圈微光
    if _skill.skill_type == SkillData.SkillType.Active and not _skill.is_disabled():
        draw_arc(center, RADIUS - BORDER_WIDTH - 2.0, 0.0, TAU, 32,
                 Color(c.r, c.g, c.b, 0.15), 1.0)


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float, dash_count: int) -> void:
    var angle_step: float = TAU / float(dash_count)
    var dash_angle: float = angle_step * 0.6
    for i in range(dash_count):
        var start: float = float(i) * angle_step
        var end: float = start + dash_angle
        draw_arc(center, radius, start, end, 6, color, width)


func _get_border_color() -> Color:
    match _skill.category:
        SkillData.Category.Species: return COLOR_SPECIES
        SkillData.Category.Character: return COLOR_CHARACTER
        SkillData.Category.Equipment: return COLOR_EQUIPMENT
    return Color(0.5, 0.5, 0.5)


# ---- 交互 ----

func _on_mouse_entered() -> void:
    if _skill:
        skill_hovered.emit(_skill)


func _on_mouse_exited() -> void:
    skill_unhovered.emit()


func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _skill:
            skill_clicked.emit(_skill)


func _on_skill_disabled_changed(_disabled: bool) -> void:
    queue_redraw()
