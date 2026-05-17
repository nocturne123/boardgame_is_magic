extends Node

## HUD 布局验证测试
## 确认 hud_battle.tscn 加载后，HUD 各层能获得正确尺寸且不超出窗口。
## 强制设置窗口尺寸为 1152×648，验证右侧面板在窗口范围内。

const HudBattleS = preload("res://source_codes/hud/hud_battle.gd")

var _hud_battle

func _ready() -> void:
    print("=".repeat(60))
    print("  HUD 布局验证测试")
    print("=".repeat(60))

    var scene := load("res://scenes/hud_battle.tscn") as PackedScene
    if scene == null:
        print("[FAIL] 无法加载场景")
        quit(1)
        return

    _hud_battle = scene.instantiate()
    add_child(_hud_battle)

    # 让 deferred 调用有机会触发（需要等待一帧）
    await get_tree().process_frame
    await get_tree().process_frame

    # 强制设置 _hud_container 尺寸为 1152×648（模拟 GUI 窗口）
    var container = _hud_battle.get("_hud_container") as Control
    if container == null:
        print("[FAIL] _hud_container 不存在")
        quit(1)
        return

    container.set_size(Vector2(1152, 648))
    container.set_position(Vector2.ZERO)

    # 等待 layout 传播
    await get_tree().process_frame
    await get_tree().process_frame

    _check_hud_sizes()

    remove_child(_hud_battle)
    _hud_battle.queue_free()
    quit(0)


func _check_hud_sizes() -> void:
    var all_ok := true
    var win_w: float = 1152.0
    var win_h: float = 648.0

    print("  模拟窗口: (%.0f, %.0f)\n" % [win_w, win_h])

    # 1. _hud_container
    var container: Control = _hud_battle.get("_hud_container")
    if container == null:
        print("[FAIL] _hud_container 不存在")
        all_ok = false
    else:
        var s: Vector2 = container.get_size()
        var r: Rect2 = container.get_global_rect()
        print("  _hud_container size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [s.x, s.y, r.position.x, r.position.y, r.size.x, r.size.y])
        if s.x <= 0 or s.y <= 0:
            print("[FAIL] _hud_container 尺寸异常 (<=0)")
            all_ok = false
        elif r.position.x < 0 or r.position.y < 0:
            print("[FAIL] _hud_container 位置为负")
            all_ok = false
        elif r.end.x > win_w or r.end.y > win_h:
            print("[FAIL] _hud_container 超出窗口右/下边缘 (end=%.0f, %.0f)" % [r.end.x, r.end.y])
            all_ok = false
        else:
            print("[PASS] _hud_container 在窗口范围内")

    # 1b. 找到 main_vbox
    var vbox = null
    for child in container.get_children():
        if child is VBoxContainer:
            vbox = child
            break

    if vbox == null:
        print("[FAIL] main_vbox 不存在")
        all_ok = false
    else:
        var vs: Vector2 = vbox.get_size()
        var vr: Rect2 = vbox.get_global_rect()
        print("  main_vbox size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [vs.x, vs.y, vr.position.x, vr.position.y, vr.size.x, vr.size.y])
        if vs.x <= 0 or vs.y <= 0:
            print("[FAIL] main_vbox 尺寸异常")
            all_ok = false
        elif vr.end.x > win_w or vr.end.y > win_h:
            print("[FAIL] main_vbox 超出窗口边缘 (end=%.0f, %.0f)" % [vr.end.x, vr.end.y])
            all_ok = false
        else:
            print("[PASS] main_vbox 在窗口范围内")

    # 2. top_bar
    var top_bar = _hud_battle.get("top_bar")
    if top_bar != null:
        var s: Vector2 = top_bar.get_size()
        var r: Rect2 = top_bar.get_global_rect()
        print("  top_bar size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [s.x, s.y, r.position.x, r.position.y, r.size.x, r.size.y])
        if s.x <= 0:
            print("[FAIL] top_bar width = 0")
            all_ok = false
        elif r.end.x > win_w:
            print("[FAIL] top_bar 超出右边缘 (end.x=%.0f > %.0f)" % [r.end.x, win_w])
            all_ok = false
        else:
            print("[PASS] top_bar 在窗口范围内")

    # 3. left_panel
    var left_panel = _hud_battle.get("left_panel")
    if left_panel != null:
        var s: Vector2 = left_panel.get_size()
        var r: Rect2 = left_panel.get_global_rect()
        print("  left_panel size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [s.x, s.y, r.position.x, r.position.y, r.size.x, r.size.y])
        if s.x <= 0:
            print("[FAIL] left_panel width = 0")
            all_ok = false
        elif r.position.x < 0 or r.end.x > win_w:
            print("[FAIL] left_panel 超出窗口")
            all_ok = false
        else:
            print("[PASS] left_panel 在窗口范围内")

    # 4. card_detail_panel (右侧面板)
    var cd_panel = _hud_battle.get("card_detail_panel")
    if cd_panel != null:
        var s: Vector2 = cd_panel.get_size()
        var r: Rect2 = cd_panel.get_global_rect()
        print("  card_detail_panel size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [s.x, s.y, r.position.x, r.position.y, r.size.x, r.size.y])
        if s.x <= 0 or s.y <= 0:
            print("[FAIL] card_detail_panel 尺寸异常")
            all_ok = false
        elif r.end.x > win_w:
            print("[FAIL] card_detail_panel 超出右边缘 (end.x=%.0f > %.0f)" % [r.end.x, win_w])
            all_ok = false
        else:
            print("[PASS] card_detail_panel 在窗口范围内")

    # 5. log_panel (右侧面板)
    var log_panel = _hud_battle.get("log_panel")
    if log_panel != null:
        var s: Vector2 = log_panel.get_size()
        var r: Rect2 = log_panel.get_global_rect()
        print("  log_panel size=(%.0f, %.0f) rect=(%.0f, %.0f, %.0f, %.0f)" % [s.x, s.y, r.position.x, r.position.y, r.size.x, r.size.y])
        if s.x <= 0 or s.y <= 0:
            print("[FAIL] log_panel 尺寸异常")
            all_ok = false
        elif r.end.x > win_w:
            print("[FAIL] log_panel 超出右边缘 (end.x=%.0f > %.0f)" % [r.end.x, win_w])
            all_ok = false
        else:
            print("[PASS] log_panel 在窗口范围内")

    if all_ok:
        print("\n[HUD] 全部通过 ✓")
    else:
        print("\n[HUD] 存在异常 ✗")


func quit(code: int) -> void:
    get_tree().quit(code)
