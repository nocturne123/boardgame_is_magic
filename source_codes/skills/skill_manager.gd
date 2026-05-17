class_name SkillManager extends Node

## 技能库管理节点。加载 skill_database.json，提供查询和创建。

@export_file("*.json") var skill_database_path: String = ""

var _skill_templates: Dictionary = {}  # id → SkillData (模板)

func _ready() -> void:
    if not skill_database_path.is_empty():
        load_database(skill_database_path)

func load_database(path: String) -> void:
    _skill_templates.clear()
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("SkillManager: 无法打开技能库: %s" % path)
        return
    var text := file.get_as_text()
    var parsed = JSON.parse_string(text)
    if not parsed is Array:
        push_error("SkillManager: 技能库格式错误")
        return
    for entry in parsed:
        var skill := _create_skill_from_json(entry)
        if skill:
            _skill_templates[skill.id] = skill

func _create_skill_from_json(data: Dictionary) -> SkillData:
    var script_path: String = data.get("script_path", "")
    var skill: SkillData
    if script_path.is_empty():
        skill = SkillData.new()
    else:
        var scr = load(script_path)
        if scr == null:
            push_error("SkillManager: 无法加载技能脚本: %s" % script_path)
            return null
        skill = scr.new()
    for key in data.keys():
        if key == "script_path":
            continue
        if skill.get(key) != null or key in ["id", "nice_name", "description",
                "ignore_distance", "range", "cooldown", "max_uses_per_turn", "needs_target"]:
            skill.set(key, data[key])
    return skill

## 返回模板实例（查询用，不要修改）。
func get_skill(id: String) -> SkillData:
    return _skill_templates.get(id, null)

## 创建新实例（挂接到 player 用）。每次调用返回独立实例。
func create_skill(id: String) -> SkillData:
    var template = _skill_templates.get(id, null)
    if template == null:
        push_warning("SkillManager: 技能 '%s' 不存在" % id)
        return null
    var script_path: String = ""
    # 从模板获取脚本路径来创建新实例
    var script = template.get_script()
    if script:
        var new_skill = script.new()
        # 复制所有属性
        for key in template.get_property_list():
            if key.name in ["resource_local_to_scene", "resource_path", "script",
                            "meta", "disabled_changed"]:
                continue
            new_skill.set(key.name, template.get(key.name))
        return new_skill
    return template
