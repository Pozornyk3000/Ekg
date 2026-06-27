class_name MonitorView
extends Control

# Прикроватный монитор с «стирающей» развёрткой: пишущая головка бежит слева направо,
# слева от неё — свежая кривая, справа — прошлый проход, на самой головке — разрыв-бланк.
# Переключаемая скорость 25/50 мм/с.

const PX_PER_MM := 4.6
const SAMPLES_PER_S := 200.0   # буфер 5 мс/сэмпл

var samples := PackedFloat32Array()
var lead_name := ""
var mm_per_s := 25.0
var head := 0.0

func _process(delta: float) -> void:
    if samples.size() > 1:
        head += SAMPLES_PER_S * delta
        queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    var mid := h * 0.5
    draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.06, 0.12))

    var sp := PX_PER_MM
    var minor := Color(0.20, 0.34, 0.60, 0.26)
    var major := Color(0.30, 0.50, 0.85, 0.48)
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
        var nshow := mini(n, maxi(8, int(w * SAMPLES_PER_S / (sp * mm_per_s))))
        var col_head := int(head) % nshow
        var sweep := int(head) / nshow
        var gap := maxi(4, int(nshow * 0.03))
        _draw_seg(0, col_head, nshow, sweep, n, w, mid)              # свежий проход (слева)
        _draw_seg(col_head + gap, nshow - 1, nshow, sweep - 1, n, w, mid)  # прошлый проход (справа)
        var hx := col_head / float(nshow - 1) * w
        draw_line(Vector2(hx, 0), Vector2(hx, h), Color(0.7, 0.9, 1.0, 0.5), 2.0)  # курсор-головка

    var f := ThemeDB.fallback_font
    draw_rect(Rect2(6, 6, 54, 28), Color(0.0, 0.0, 0.0, 0.45))
    draw_string(f, Vector2(13, 27), lead_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 0.85, 1.0))
    draw_string(f, Vector2(w - 150, h - 8), "%d мм/с · 10 мм/мВ" % int(mm_per_s), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.6, 0.85))

func _draw_seg(i0: int, i1: int, nshow: int, sweep: int, n: int, w: float, mid: float) -> void:
    if i1 <= i0:
        return
    var pts := PackedVector2Array()
    for i in range(i0, i1 + 1):
        var src := sweep * nshow + i
        var idx := ((src % n) + n) % n
        pts.append(Vector2(i / float(nshow - 1) * w, mid - samples[idx] * PX_PER_MM))
    if pts.size() < 2:
        return
    draw_polyline(pts, Color(0.25, 0.7, 1.0, 0.16), 6.0, true)
    draw_polyline(pts, Color(0.45, 0.82, 1.0), 2.2, true)
