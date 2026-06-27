class_name ECGSheet
extends Control

# Рисует стандартный 12-канальный лист ЭКГ на миллиметровке (3×4 + ритм-полоса)
# для экспорта в PNG. Сетка 25 мм/с · 10 мм/мВ.

var buffers: Array = []
var lead_names: Array = []
var title := ""

const PX_PER_MM := 5.0
const SAMPLE_DT := 5.0      # мс на отсчёт (4000 мс / 800)
const WIN_MS := 2400.0      # окно на ячейку
const ORDER := [0, 3, 6, 9, 1, 4, 7, 10, 2, 5, 8, 11]

func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.985, 0.975))
    var minor := Color(0.95, 0.74, 0.72)
    var major := Color(0.84, 0.46, 0.44)
    var sp := PX_PER_MM
    var x := 0.0
    var k := 0
    while x <= w + 0.5:
        var maj := k % 5 == 0
        draw_line(Vector2(x, 0), Vector2(x, h), major if maj else minor, 1.2 if maj else 0.5)
        x += sp
        k += 1
    var y := 0.0
    k = 0
    while y <= h + 0.5:
        var maj2 := k % 5 == 0
        draw_line(Vector2(0, y), Vector2(w, y), major if maj2 else minor, 1.2 if maj2 else 0.5)
        y += sp
        k += 1

    var f := ThemeDB.fallback_font
    if not title.is_empty():
        draw_string(f, Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.1, 0.1, 0.1))

    if buffers.size() < 12:
        return
    var cols := 4
    var rows := 3
    var top := 40.0
    var cw := w / float(cols)
    var ch := (h - top - 90.0) / float(rows)
    var nshow := int(WIN_MS / SAMPLE_DT)
    for idx in range(12):
        var li: int = ORDER[idx]
        var col := idx % cols
        var row := int(idx / cols)
        var cx := col * cw
        var base := top + row * ch + ch * 0.55
        var buf: PackedFloat32Array = buffers[li]
        var n := mini(nshow, buf.size())
        if n < 2:
            continue
        var pts := PackedVector2Array()
        for i in n:
            var px := cx + 6.0 + i / float(maxi(n - 1, 1)) * (cw - 12.0)
            pts.append(Vector2(px, base - buf[i] * PX_PER_MM))
        draw_polyline(pts, Color(0.08, 0.08, 0.11), 1.6, true)
        if li < lead_names.size():
            draw_string(f, Vector2(cx + 8, top + row * ch + 18), str(lead_names[li]),
                HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.1, 0.15, 0.4))

    # Ритм-полоса (II) внизу — полное окно.
    var ry := h - 60.0
    var rbuf: PackedFloat32Array = buffers[1]
    var rn := rbuf.size()
    if rn >= 2:
        var rpts := PackedVector2Array()
        for i in rn:
            var px2 := 6.0 + i / float(maxi(rn - 1, 1)) * (w - 12.0)
            rpts.append(Vector2(px2, ry - rbuf[i] * PX_PER_MM))
        draw_polyline(rpts, Color(0.08, 0.08, 0.11), 1.6, true)
        draw_string(f, Vector2(8, ry - 36.0), "II (ритм)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.15, 0.4))
    draw_string(f, Vector2(8, h - 6.0), "25 мм/с · 10 мм/мВ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.2, 0.2))
