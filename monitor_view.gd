class_name MonitorView
extends Control

# Бегущий монитор: окно фиксированной длительности проматывается в реальном времени
# (25 мм/с), как на прикроватном мониторе. Раньше рисовались все 20 с разом — комплексы
# сливались. Теперь видно ~3-5 с, читаемо.

const PX_PER_MM := 4.6
const MM_PER_S := 25.0
const SAMPLES_PER_S := 200.0   # буфер 5 мс/сэмпл

var samples := PackedFloat32Array()
var lead_name := ""
var scroll := 0.0

func _process(delta: float) -> void:
    if samples.size() > 1:
        scroll = fposmod(scroll + SAMPLES_PER_S * delta, float(samples.size()))
        queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    var mid := h * 0.5
    draw_rect(Rect2(0, 0, w, h), Color(0.035, 0.06, 0.05))

    var sp := PX_PER_MM
    var minor := Color(0.22, 0.42, 0.30, 0.30)
    var major := Color(0.26, 0.58, 0.38, 0.50)
    var x := 0.0
    var k := 0
    while x <= w + 0.5:
        var maj := k % 5 == 0
        draw_line(Vector2(x, 0), Vector2(x, h), major if maj else minor, 1.2 if maj else 0.6)
        x += sp
        k += 1
    var y := mid
    k = 0
    while y <= h + 0.5:
        var maj2 := k % 5 == 0
        draw_line(Vector2(0, y), Vector2(w, y), major if maj2 else minor, 1.2 if maj2 else 0.6)
        y += sp
        k += 1
    y = mid - sp
    k = 1
    while y >= -0.5:
        var maj3 := k % 5 == 0
        draw_line(Vector2(0, y), Vector2(w, y), major if maj3 else minor, 1.2 if maj3 else 0.6)
        y -= sp
        k += 1

    var n := samples.size()
    if n > 1:
        var nshow := mini(n, maxi(2, int(w / sp / MM_PER_S * SAMPLES_PER_S)))
        var pts := PackedVector2Array()
        pts.resize(nshow)
        for i in nshow:
            var idx := int(fposmod(scroll + i, float(n)))
            pts[i] = Vector2(i / float(nshow - 1) * w, mid - samples[idx] * PX_PER_MM)
        draw_polyline(pts, Color(0.25, 1.0, 0.5, 0.16), 6.0, true)   # свечение
        draw_polyline(pts, Color(0.45, 1.0, 0.58), 2.2, true)        # линия
        draw_circle(pts[nshow - 1], 4.0, Color(0.8, 1.0, 0.85))      # бегунок

    var f := ThemeDB.fallback_font
    draw_rect(Rect2(6, 6, 54, 28), Color(0.0, 0.0, 0.0, 0.45))
    draw_string(f, Vector2(13, 27), lead_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 1.0, 0.72))
    draw_string(f, Vector2(w - 132, h - 8), "25 мм/с · 10 мм/мВ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.72, 0.5))
