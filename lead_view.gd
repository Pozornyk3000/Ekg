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
    draw_rect(Rect2(0, 0, w, h), Color(0.045, 0.07, 0.13) if not highlighted else Color(0.07, 0.11, 0.20))
    var minor := Color(0.20, 0.34, 0.60, 0.20)
    var sp := 5.0 * PX_PER_MM
    var x := sp
    while x < w:
        draw_line(Vector2(x, 0), Vector2(x, h), minor, 0.8)
        x += sp
    var yy := mid
    while yy < h:
        draw_line(Vector2(0, yy), Vector2(w, yy), minor, 0.8)
        yy += sp
    yy = mid - sp
    while yy > 0.0:
        draw_line(Vector2(0, yy), Vector2(w, yy), minor, 0.8)
        yy -= sp
    draw_line(Vector2(0, mid), Vector2(w, mid), Color(0.3, 0.45, 0.7, 0.5), 0.8)

    var n := samples.size()
    if n > 1:
        var pts := PackedVector2Array()
        pts.resize(n)
        for i in n:
            pts[i] = Vector2(i / float(n - 1) * w, mid - samples[i] * PX_PER_MM)
        draw_polyline(pts, Color(0.45, 0.82, 1.0), 1.5, true)

    draw_string(ThemeDB.fallback_font, Vector2(5, 15), lead_name,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.85, 1.0))

    if highlighted:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.65, 1.0, 0.95), false, 2.0)
