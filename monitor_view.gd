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
var bg_c := Color(0.03, 0.06, 0.12)
var trace_color := Color(0.45, 0.82, 1.0)
var grid_c := Color(0.30, 0.50, 0.85)
var hr_bpm := 0.0
var alarm := false
var alarm_text := ""
var _rpeaks := {}
var _oneshot := false
var _steady := PackedFloat32Array()

# Заморозка + линейка: пауза развёртки и две каретки для измерения интервала/ЧСС.
var frozen := false
var cal_a := 0.30
var cal_b := 0.55
var _drag_cal := ""

func update_samples(buf: PackedFloat32Array) -> void:
    samples = buf
    _oneshot = false
    _steady = PackedFloat32Array()
    _detect_peaks()
    queue_redraw()

# Проиграть переходную ленту один раз (купирование аритмии), затем перейти на steady.
func play_transition(trans: PackedFloat32Array, steady: PackedFloat32Array) -> void:
    samples = trans
    _steady = steady
    _oneshot = true
    head = 0.0
    _detect_peaks()
    queue_redraw()

func _detect_peaks() -> void:
    _rpeaks.clear()
    var n := samples.size()
    if n < 3:
        return
    var mx := 0.0
    for s in samples:
        mx = maxf(mx, absf(s))
    var thr := maxf(mx * 0.5, 1.0)
    var last := -999
    for i in range(1, n - 1):
        var a := absf(samples[i])
        if a > thr and a >= absf(samples[i - 1]) and a > absf(samples[i + 1]) and i - last > 40:
            _rpeaks[i] = true
            last = i

func _process(delta: float) -> void:
    if frozen:
        return
    if samples.size() > 1:
        head += SAMPLES_PER_S * delta
        if _oneshot and head >= float(samples.size()):
            samples = _steady
            _steady = PackedFloat32Array()
            _oneshot = false
            head = fposmod(head, float(maxi(samples.size(), 1)))
            _detect_peaks()
        queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    var mid := h * 0.5
    draw_rect(Rect2(0, 0, w, h), bg_c)

    var sp := PX_PER_MM
    var minor := Color(grid_c, 0.26)
    var major := Color(grid_c, 0.5)
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
        @warning_ignore("integer_division")
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
    if hr_bpm > 0.0:
        var hb := "%d" % int(round(hr_bpm))
        var fw := f.get_string_size(hb, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
        draw_string(f, Vector2(w - fw - 14, 36), hb, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.45, 1.0, 0.55))
        draw_string(f, Vector2(w - 70, 52), "уд/мин", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.7, 0.5))
    if alarm:
        var puls := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 210.0)
        draw_rect(Rect2(2, 2, w - 4, h - 4), Color(1.0, 0.27, 0.22, puls), false, 4.0)
        var aw := f.get_string_size(alarm_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        draw_string(f, Vector2((w - aw) * 0.5, 22), alarm_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.45, 0.4, 0.6 + 0.4 * puls))

    if frozen:
        var xa := cal_a * w
        var xb := cal_b * w
        var cc := Color(0.55, 1.0, 0.75)
        draw_rect(Rect2(minf(xa, xb), 0, absf(xb - xa), h), Color(cc, 0.10))
        for xc in [xa, xb]:
            draw_line(Vector2(xc, 0), Vector2(xc, h), cc, 1.6)
            draw_circle(Vector2(xc, 9), 6.0, cc)
        var dt := absf(cal_b - cal_a) * w / PX_PER_MM / maxf(mm_per_s, 1.0) * 1000.0
        var bpm := 60000.0 / dt if dt > 1.0 else 0.0
        var txt := "📏  Δt = %d мс   ·   ЧСС = %d/мин" % [int(round(dt)), int(round(bpm))]
        draw_rect(Rect2(6, h - 30, w - 12, 22), Color(0.0, 0.15, 0.1, 0.55))
        draw_string(f, Vector2(12, h - 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, cc)

func _gui_input(event: InputEvent) -> void:
    if not frozen:
        return
    var w := maxf(size.x, 1.0)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _drag_cal = "a" if absf(event.position.x - cal_a * w) <= absf(event.position.x - cal_b * w) else "b"
        else:
            _drag_cal = ""
        accept_event()
    elif event is InputEventScreenTouch:
        _drag_cal = ("a" if absf(event.position.x - cal_a * w) <= absf(event.position.x - cal_b * w) else "b") if event.pressed else ""
        accept_event()
    elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _drag_cal != "":
        var fr := clampf(event.position.x / w, 0.0, 1.0)
        if _drag_cal == "a": cal_a = fr
        else: cal_b = fr
        queue_redraw()
        accept_event()

func _draw_seg(i0: int, i1: int, nshow: int, sweep: int, n: int, w: float, mid: float) -> void:
    if i1 <= i0:
        return
    var pts := PackedVector2Array()
    var dots := PackedVector2Array()
    for i in range(i0, i1 + 1):
        var src := sweep * nshow + i
        var idx := ((src % n) + n) % n
        var pt := Vector2(i / float(nshow - 1) * w, mid - samples[idx] * PX_PER_MM)
        pts.append(pt)
        if _rpeaks.has(idx):
            dots.append(pt)
    if pts.size() < 2:
        return
    draw_polyline(pts, Color(trace_color, 0.16), 6.0, true)
    draw_polyline(pts, trace_color, 2.2, true)
    for d in dots:
        draw_circle(Vector2(d.x, d.y - 10.0), 3.6, Color(1.0, 0.82, 0.3))
