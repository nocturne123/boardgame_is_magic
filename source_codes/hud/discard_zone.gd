class_name DiscardZone
extends PanelContainer

## 弃置区 HUD — 拖拽装备到此区域卸下。
## 闲置时隐藏在屏幕右侧外，装备槽开始拖拽时由 EquipmentBar 控制滑入/滑出。
## 收藏品拖入会被 Action 拒绝，由 EquipmentBar 调用 shake() 做抖动反馈。

signal card_discard_requested(source_slot: EquipmentSlot)

var _slide_tween: Tween

# ---- 外观参数 ----
const ZONE_WIDTH: float = 140.0
const ZONE_HEIGHT: float = 120.0
const HIDDEN_OFFSET: float = 200.0


func _ready() -> void:
    custom_minimum_size = Vector2(ZONE_WIDTH, ZONE_HEIGHT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 50
    _build_ui()
    # 初始隐藏在屏幕右侧外
    position = Vector2(get_viewport().get_visible_rect().size.x + HIDDEN_OFFSET, 0)
    modulate.a = 0.0

func _build_ui() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.35, 0.08, 0.08, 0.85)
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.7, 0.2, 0.2, 0.6)
    style.set_corner_radius_all(8)
    add_theme_stylebox_override("panel", style)

    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 6)
    add_child(vbox)

    var icon := Label.new()
    icon.text = "🗑"
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 28)
    vbox.add_child(icon)

    var label := Label.new()
    label.text = "弃置装备"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
    vbox.add_child(label)


# ---- 滑入/滑出 (由 EquipmentBar 控制) ----

func slide_in() -> void:
    if _slide_tween and _slide_tween.is_valid():
        _slide_tween.kill()
    var target_x := get_viewport().get_visible_rect().size.x - ZONE_WIDTH - 16
    var target_y := get_viewport().get_visible_rect().size.y * 0.65 - ZONE_HEIGHT / 2
    _slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    _slide_tween.set_parallel(true)
    _slide_tween.tween_property(self, "position:x", target_x, 0.2)
    _slide_tween.tween_property(self, "position:y", target_y, 0.2)
    _slide_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func slide_out() -> void:
    if _slide_tween and _slide_tween.is_valid():
        _slide_tween.kill()
    var target_x := get_viewport().get_visible_rect().size.x + HIDDEN_OFFSET
    _slide_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
    _slide_tween.set_parallel(true)
    _slide_tween.tween_property(self, "position:x", target_x, 0.15)
    _slide_tween.tween_property(self, "modulate:a", 0.0, 0.15)


# ---- 抖动动画（收藏品被拒绝时由 EquipmentBar 调用）----

func shake() -> void:
    var orig_x := position.x
    var t := create_tween()
    for i in range(4):
        var dir := 1.0 if i % 2 == 0 else -1.0
        t.tween_property(self, "position:x", orig_x + dir * 8.0, 0.07)
    t.tween_property(self, "position:x", orig_x, 0.07)

    # 边框闪红
    var flash := create_tween()
    flash.tween_callback(_apply_highlight.bind(Color(1.0, 0.2, 0.2, 0.9), 3))
    flash.tween_interval(0.4)
    flash.tween_callback(_apply_highlight.bind(Color(0.7, 0.2, 0.2, 0.6), 2))


func _apply_highlight(border_color: Color, border_width: int) -> void:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.35, 0.08, 0.08, 0.85)
    s.border_width_left = border_width
    s.border_width_right = border_width
    s.border_width_top = border_width
    s.border_width_bottom = border_width
    s.border_color = border_color
    s.set_corner_radius_all(8)
    add_theme_stylebox_override("panel", s)


# ---- 拖拽接收 ----

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
    if data == null or not data is Dictionary:
        return false
    return data.has("source_slot") and data.has("card")

func _drop_data(_pos: Vector2, data: Variant) -> void:
    if data == null or not data is Dictionary:
        return
    var src_slot: EquipmentSlot = data.get("source_slot", null)
    if src_slot == null:
        return
    card_discard_requested.emit(src_slot)
