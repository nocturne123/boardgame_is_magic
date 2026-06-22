class_name HandFan
extends Control

## 三国杀式手牌扇形区域。
## - 所有牌底边对齐同一水平线，靠旋转形成扇形放射
## - 中间牌 0°，两侧牌向外倾斜，仿佛从同一持牌点散开
## - 悬停时：弹起 + 回正 + 放大
## - 选中时：保持弹起状态

signal card_clicked(card_sprite: CardSprite)
signal card_hovered(card_sprite: CardSprite)

# ---- 扇形布局参数 ----
## 相邻牌中心点的水平间距。值越小重叠越多、扇形越紧密。
const CARD_STEP: float = 60.0
## 最外侧牌的最大旋转角度（度）。角度越大扇形越开。
const MAX_FAN_DEG: float = 14.0

# ---- 交互参数 ----
const HOVER_LIFT: float = 20.0        ## 悬停时向上弹起像素
const HOVER_SCALE: float = 1.16       ## 悬停时缩放倍率
const ELEVATED_Z: int = 100

# ---- 动画时长 ----
const ANIM_DURATION_HOVER: float = 0.12
const ANIM_DURATION_RETURN: float = 0.15

var _cards: Array[CardSprite] = []
var _hovered: CardSprite = null
var _layout_pending: bool = false

@onready var _card_w: float = 100.0
@onready var _card_h: float = 140.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 公共 API
# ============================================================

func add_card(cs: CardSprite) -> void:
    if _cards.is_empty():
        _card_w = cs.custom_minimum_size.x
        _card_h = max(_card_h, cs.custom_minimum_size.y)
    # 旋转锚点：底部中心（牌围绕底部旋转，形成扇形放射）
    cs.pivot_offset = Vector2(_card_w / 2.0, _card_h)
    cs.mouse_entered.connect(_on_entered.bind(cs))
    cs.mouse_exited.connect(_on_exited.bind(cs))
    cs.card_clicked.connect(_on_clicked)
    add_child(cs)
    _cards.append(cs)
    _try_layout()


func remove_card(cs: CardSprite) -> void:
    if not is_instance_valid(cs):
        return
    var idx := _cards.find(cs)
    if idx >= 0:
        _cards.remove_at(idx)
        if cs == _hovered:
            _hovered = null
    cs.queue_free()
    _try_layout()


func clear_cards() -> void:
    for cs in _cards:
        if is_instance_valid(cs):
            cs.queue_free()
    _cards.clear()
    _hovered = null


func get_count() -> int:
    return _cards.size()


func return_card(cs: CardSprite) -> void:
    if not is_instance_valid(cs):
        return
    cs.is_selected = false
    cs.set_selected(false)
    var idx := _cards.find(cs)
    if idx < 0:
        return
    _animate_to_rest(cs, idx)


# ============================================================
# 扇形布局 — 平基线 + 旋转放射
# ============================================================

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _try_layout()


func _try_layout() -> void:
    var count := _cards.size()
    if count == 0:
        custom_minimum_size = Vector2(_card_w, _card_h + HOVER_LIFT + 4)
        return

    var avail: float = size.x
    if avail <= 0:
        var p := get_parent()
        if p is Control:
            avail = p.size.x
    if avail <= 0:
        if not _layout_pending:
            _layout_pending = true
            call_deferred("_retry_layout")
        return
    _layout_pending = false

    # 扇形总水平跨度 = (count-1) * step。step 是相邻牌中心距离。
    var fan_span: float = (count - 1) * CARD_STEP
    # 居中起点
    var start_x: float = max(0.0, (avail - fan_span) / 2.0)

    # 每张牌放平基线 y=0（牌底部对齐），靠旋转形成扇形
    for i in range(count):
        _place_card(_cards[i], i, start_x, count)

    # 给容器设最小尺寸：宽度为扇形总宽 + 牌宽（含旋转溢出），高度留 hover lift 空间
    custom_minimum_size = Vector2(
        fan_span + _card_w + 20,
        _card_h + HOVER_LIFT + 4
    )


func _retry_layout() -> void:
    _layout_pending = false
    _try_layout()


func _place_card(cs: CardSprite, index: int, start_x: float, total_count: int) -> void:
    # 水平位置：按 step 均匀排开
    var x: float = start_x + index * CARD_STEP

    # 旋转角度：中心牌 0°，线性过渡到两侧 ±MAX_FAN_DEG
    var rot_deg: float = _fan_rotation(index, total_count)

    # y = 0：所有牌的锚点（底部中心）在同一水平线上
    # 旋转后牌的上半部会自然向外散开，形成扇形
    cs.rotation_degrees = rot_deg
    cs.position = Vector2(x, 0.0)

    # z_index：中心牌最前（最高 z），两侧递减
    var center: float = float(total_count - 1) / 2.0
    cs.z_index = total_count - int(abs(float(index) - center))

    if cs != _hovered and not cs.is_selected:
        cs.scale = Vector2.ONE


## 计算第 index 张牌的扇形旋转角度（度）。
func _fan_rotation(index: int, total_count: int) -> float:
    if total_count <= 1:
        return 0.0
    var t: float = float(index) / float(total_count - 1)  # 0..1
    return lerpf(-MAX_FAN_DEG, MAX_FAN_DEG, t)


# ============================================================
# 交互 — 悬停
# ============================================================

func _on_entered(cs: CardSprite) -> void:
    _hovered = cs
    var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    cs.z_index = ELEVATED_Z
    t.set_parallel(true)
    # 弹起：y 变为 -HOVER_LIFT（向上）+ 回正 0° + 放大
    t.tween_property(cs, "position:y", -HOVER_LIFT, ANIM_DURATION_HOVER)
    t.tween_property(cs, "rotation_degrees", 0.0, ANIM_DURATION_HOVER)
    t.tween_property(cs, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), ANIM_DURATION_HOVER)
    card_hovered.emit(cs)


func _on_exited(cs: CardSprite) -> void:
    if cs == _hovered:
        _hovered = null
    if cs.is_selected:
        return
    var idx := _cards.find(cs)
    if idx < 0:
        return
    _animate_to_rest(cs, idx)


func _animate_to_rest(cs: CardSprite, index: int) -> void:
    if not is_instance_valid(cs):
        return
    var count := _cards.size()
    var avail: float = size.x
    if avail <= 0:
        var p := get_parent()
        if p is Control:
            avail = p.size.x
    var fan_span: float = (count - 1) * CARD_STEP
    var start_x: float = max(0.0, (avail - fan_span) / 2.0)
    var x := start_x + index * CARD_STEP
    var rot_deg := _fan_rotation(index, count)

    var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    t.set_parallel(true)
    t.tween_property(cs, "position", Vector2(x, 0.0), ANIM_DURATION_RETURN)
    t.tween_property(cs, "rotation_degrees", rot_deg, ANIM_DURATION_RETURN)
    t.tween_property(cs, "scale", Vector2.ONE, ANIM_DURATION_RETURN)
    var center: float = float(count - 1) / 2.0
    cs.z_index = count - int(abs(float(index) - center))


# ============================================================
# 交互 — 点击
# ============================================================

func _on_clicked(cs: CardSprite) -> void:
    card_clicked.emit(cs)
