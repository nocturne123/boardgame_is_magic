class_name CardArrow
extends Node2D

## 卡牌目标指向箭头 — 杀戮尖塔风格，增强版。
## - 曲线自适应源/目标相对位置（不总是向右上弯）
## - 箭头尖端脉冲动画
## - 彗尾渐变：近源端粗、近目标端细
## - 菱形箭头发光

var _active: bool = false
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0

# ---- 视觉参数 ----
const CORE_COLOR := Color(1.0, 0.84, 0.0, 0.95)
const GLOW_COLOR := Color(1.0, 0.84, 0.0, 0.2)
const ARROWHEAD_SIZE := 14.0
const ARROWHEAD_WIDTH := 10.0
const CURVE_SEGMENTS := 28
const PULSE_SPEED := 4.0         ## 脉冲频率 (rad/s)
const PULSE_ALPHA_MIN := 0.5     ## 脉冲最低 alpha

var _tween: Tween


# ============================================================
# 公共 API
# ============================================================

func activate(from: Vector2) -> void:
    _start = from
    _end = from
    _active = true
    _pulse_time = 0.0
    visible = true
    set_process(true)
    queue_redraw()


func deactivate() -> void:
    _active = false
    visible = false
    set_process(false)
    if _tween and _tween.is_valid():
        _tween.kill()
    queue_redraw()


func update_target(to: Vector2) -> void:
    _end = to
    queue_redraw()


func animate_to_target(target: Vector2, duration: float = 0.25, on_done: Callable = Callable()) -> void:
    if _tween and _tween.is_valid():
        _tween.kill()
    _tween = create_tween()
    _tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    _tween.tween_method(_anim_step, _end, target, duration)
    _tween.finished.connect(func():
        _end = target
        queue_redraw()
        if on_done.is_valid():
            on_done.call()
    )


# ============================================================
# 帧更新 — 脉冲动画
# ============================================================

func _process(delta: float) -> void:
    if not _active:
        return
    _pulse_time += delta * PULSE_SPEED


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
    if not _active or _start.distance_to(_end) < 8:
        return

    var pts := _build_curve(_start, _end, CURVE_SEGMENTS)
    if pts.size() < 2:
        return

    var pulse_alpha: float = lerpf(PULSE_ALPHA_MIN, 1.0,
        (sin(_pulse_time) + 1.0) / 2.0)

    # 彗尾：多层渐变宽度的半透明线
    _draw_trail(pts, pulse_alpha)

    # 主线
    draw_polyline(pts, CORE_COLOR, 2.0, true)

    # 箭头尖端
    var tip := pts[pts.size() - 1]
    var prev := pts[pts.size() - 2]
    _draw_arrowhead(tip, prev, pulse_alpha)


# ============================================================
# 曲线计算 — 动态弯曲方向
# ============================================================

func _build_curve(from: Vector2, to: Vector2, segments: int) -> PackedVector2Array:
    var mid := (from + to) * 0.5
    var delta := to - from
    var dist: float = delta.length() * 0.35
    # 弯曲方向：总是向上弯（模拟卡片抛出的自然弧线），弯度随距离增大
    var bend_up: float = -max(dist, 50.0)
    # 水平偏移：如果目标在源左边，轻微左弯；反之右弯
    var bend_h: float = delta.x * 0.15
    var ctrl := Vector2(mid.x + bend_h, mid.y + bend_up)

    var pts := PackedVector2Array()
    for i in range(segments + 1):
        var t := float(i) / segments
        pts.append(_quad_bezier(from, ctrl, to, t))
    return pts


func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
    var a := p0.lerp(p1, t)
    var b := p1.lerp(p2, t)
    return a.lerp(b, t)


# ============================================================
# 彗尾绘制 — 渐宽渐暗的多层线
# ============================================================

func _draw_trail(pts: PackedVector2Array, pulse_alpha: float) -> void:
    var trail_layers := 3
    for layer in range(trail_layers):
        var t_val: float = float(layer) / trail_layers
        var width: float = lerpf(7.0, 1.5, t_val)
        var alpha: float = lerpf(0.12, 0.35, t_val) * pulse_alpha
        var color := Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, alpha)
        draw_polyline(pts, color, width, true)


# ============================================================
# 箭头尖端 — 菱形 + 脉冲光晕
# ============================================================

func _draw_arrowhead(tip: Vector2, prev: Vector2, pulse_alpha: float) -> void:
    var dir := (tip - prev).normalized()
    var perp := Vector2(-dir.y, dir.x)

    # 光晕（脉冲）
    var glow_s := ARROWHEAD_SIZE * 1.8
    var glow_pts := PackedVector2Array([
        tip,
        tip - dir * glow_s + perp * glow_s * 0.5,
        tip - dir * glow_s * 0.4,
        tip - dir * glow_s - perp * glow_s * 0.5,
    ])
    var glow_alpha: float = 0.15 * pulse_alpha
    draw_colored_polygon(glow_pts, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, glow_alpha))

    # 主线箭头（菱形）
    var s := ARROWHEAD_SIZE
    var w := ARROWHEAD_WIDTH
    var pts := PackedVector2Array([
        tip,
        tip - dir * s + perp * w * 0.45,
        tip - dir * s * 0.4,
        tip - dir * s - perp * w * 0.45,
    ])
    var arrow_color := Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, CORE_COLOR.a * pulse_alpha)
    draw_colored_polygon(pts, arrow_color)


# ============================================================
# 动画步骤
# ============================================================

func _anim_step(pos: Vector2) -> void:
    _end = pos
    queue_redraw()
