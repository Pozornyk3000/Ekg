class_name MonitorView
extends Control

const PX_PER_MM := 4.0

var samples := PackedFloat32Array()
var lead_name := ""
var scroll := 0.0
var speed := 120.0          # сэмплов в секунду

func _process(delta: float) -> void:
    var n := samples.size()
    if n > 1:
        scroll = fposmod(scroll + speed * delta, float(n))
        queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    var mid := h * 0.5
    var grid := Color(0.85, 0.25, 0.25, 0.10)

    for k in range(1, 10):
        var x := w * k / 10.0
        draw_line(Vector2(x, 0), Vector2(x, h), grid, 1.0)
    var step := 5.0 * PX_PER_MM
    var yy := mid
    while yy < h:
        draw_line(Vector2(0, yy), Vector2(w, yy), grid, 1.0)
        yy += step
    yy = mid - step
    while yy > 0.0:
        draw_line(Vector2(0, yy), Vector2(w, yy), grid, 1.0)
        yy -= step

    draw_line(Vector2(0, mid), Vector2(w, mid), Color(0.3, 0.45, 0.3, 0.5), 1.0)

    var n := samples.size()
    if n > 1:
        var pts := PackedVector2Array()
        pts.resize(n)
        for s in n:
            var idx := int(fposmod(float(s) + scroll, float(n)))
            pts[s] = Vector2(s / float(n - 1) * w, mid - samples[idx] * PX_PER_MM)
        draw_polyline(pts, Color(0.3, 1.0, 0.45), 2.0, true)

    draw_string(ThemeDB.fallback_font, Vector2(8, 22), lead_name,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 0.95))
