class_name StressView
extends Control

var hr_vals: Array = []
var depr_vals: Array = []
var sys_vals: Array = []
var cur_stage: int = 0

func _ready() -> void:
    custom_minimum_size = Vector2(0, 200)

func _draw() -> void:
    var w := size.x
    var h := size.y
    var n := hr_vals.size()
    draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.09, 0.12))
    if n < 2:
        return
    var ml := 10.0
    var mr := 10.0
    var mt := 18.0
    var mb := 18.0
    var pw := w - ml - mr
    var ph := h - mt - mb
    var f := ThemeDB.fallback_font

    # baseline
    draw_line(Vector2(ml, mt + ph), Vector2(ml + pw, mt + ph), Color(0.3, 0.3, 0.35), 1.0)
    # ischemia threshold line for ST (1 mm)
    var y1 := mt + ph * (1.0 - clampf(1.0 / 4.0, 0.0, 1.0))
    draw_line(Vector2(ml, y1), Vector2(ml + pw, y1), Color(0.35, 0.3, 0.3), 1.0)

    # current stage marker
    var cx := ml + pw * float(cur_stage) / float(n - 1)
    draw_line(Vector2(cx, mt), Vector2(cx, mt + ph), Color(0.6, 0.55, 0.2), 1.5)

    var hrcol := Color(1.0, 0.42, 0.36)
    var deprcol := Color(0.4, 0.72, 1.0)
    var syscol := Color(0.45, 0.85, 0.5)
    var hrpts := PackedVector2Array()
    var deprpts := PackedVector2Array()
    var syspts := PackedVector2Array()
    for i in n:
        var x := ml + pw * float(i) / float(n - 1)
        var hy := mt + ph * (1.0 - clampf((float(hr_vals[i]) - 60.0) / 140.0, 0.0, 1.0))
        hrpts.append(Vector2(x, hy))
        var dy := mt + ph * (1.0 - clampf(float(depr_vals[i]) / 4.0, 0.0, 1.0))
        deprpts.append(Vector2(x, dy))
        if i < sys_vals.size():
            var sy := mt + ph * (1.0 - clampf((float(sys_vals[i]) - 80.0) / 140.0, 0.0, 1.0))
            syspts.append(Vector2(x, sy))
    if syspts.size() > 1:
        draw_polyline(syspts, syscol, 2.0)
    if hrpts.size() > 1:
        draw_polyline(hrpts, hrcol, 2.0)
    if deprpts.size() > 1:
        draw_polyline(deprpts, deprcol, 2.0)
    for p in syspts:
        draw_circle(p, 2.5, syscol)
    for p in hrpts:
        draw_circle(p, 2.5, hrcol)
    for p in deprpts:
        draw_circle(p, 2.5, deprcol)

    draw_string(f, Vector2(ml, 13), "ЧСС", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hrcol)
    draw_string(f, Vector2(ml + 42, 13), "САД", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, syscol)
    draw_string(f, Vector2(ml + 84, 13), "депрессия ST (порог 1 мм)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, deprcol)
    draw_string(f, Vector2(ml, mt + ph + 14), "Покой → нагрузка → восстановление", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.62, 0.7))
