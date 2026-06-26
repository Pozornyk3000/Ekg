class_name LeadView
extends Control

const PX_PER_MM := 2.2

var samples := PackedFloat32Array()
var lead_name := ""
var highlighted := false

func _draw() -> void:
    var w := size.x
    var h := size.y
    var mid := h * 0.5
    var grid := Color(0.85, 0.25, 0.25, 0.08)
    for k in range(1, 8):
        draw_line(Vector2(w * k / 8.0, 0), Vector2(w * k / 8.0, h), grid, 1.0)
    draw_line(Vector2(0, mid), Vector2(w, mid), Color(0.3, 0.45, 0.3, 0.4), 1.0)

    var n := samples.size()
    if n > 1:
        var pts := PackedVector2Array()
        pts.resize(n)
        for i in n:
            pts[i] = Vector2(i / float(n - 1) * w, mid - samples[i] * PX_PER_MM)
        draw_polyline(pts, Color(0.3, 1.0, 0.45), 1.2, true)

    draw_string(ThemeDB.fallback_font, Vector2(4, 14), lead_name,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))

    if highlighted:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 1.0, 0.45, 0.9), false, 2.0)
