class_name EditView
extends Control

signal handle_dragged(feature, value_mm, time_ms)
signal drag_ended

const PX_PER_MM := 6.0       # масштаб сетки (квадрат как на реальной плёнке)
const SAMPLE_DT := 5.0       # мс на сэмпл (буфер 4000 мс / 800)
const PAPER_MM_S := 25.0     # мм/с (стандартная скорость)
const GRAB := 46.0           # радиус захвата маркера, px

var samples := PackedFloat32Array()
var lead_name := ""
var qrs_eff_ms := 90.0
var rr_ms := 800.0
var has_p := true
var st_level := 0.0

var _baseline := 0.0
var _handles: Array = []     # {feature, pos:Vector2, value:float}
var _drag := ""

# Режим «линейка»: две вертикальные каретки для измерения интервала/ЧСС/амплитуды.
var measure_mode := false
var cal_a := 0.30            # доли ширины (0..1)
var cal_b := 0.58
var _drag_cal := ""

func _ready() -> void:
    custom_minimum_size = Vector2(0, 270)

func _win_ms() -> float:
    var mm := size.x / PX_PER_MM
    return mm / PAPER_MM_S * 1000.0

func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_rect(Rect2(0, 0, w, h), Color(0.99, 0.97, 0.96))
    var minor := Color(0.93, 0.72, 0.70)
    var major := Color(0.82, 0.44, 0.42)
    var sp := PX_PER_MM
    _baseline = h * 0.58

    # вертикальные линии
    var x := 0.0
    var k := 0
    while x <= w + 0.5:
        var maj := (k % 5 == 0)
        draw_line(Vector2(x, 0), Vector2(x, h), major if maj else minor, 1.4 if maj else 0.7)
        x += sp
        k += 1
    # горизонтальные линии (от изолинии)
    var y := _baseline
    while y <= h + 0.5:
        var kk := int(round((y - _baseline) / sp))
        draw_line(Vector2(0, y), Vector2(w, y), major if kk % 5 == 0 else minor, 1.4 if kk % 5 == 0 else 0.7)
        y += sp
    y = _baseline - sp
    while y >= -0.5:
        var kk2 := int(round((_baseline - y) / sp))
        draw_line(Vector2(0, y), Vector2(w, y), major if kk2 % 5 == 0 else minor, 1.4 if kk2 % 5 == 0 else 0.7)
        y -= sp
    draw_line(Vector2(0, _baseline), Vector2(w, _baseline), Color(0.55, 0.28, 0.28, 0.7), 1.0)

    var n := samples.size()
    if n < 2:
        _draw_labels(w, h)
        return
    var win := _win_ms()
    var nshow := mini(n, maxi(2, int(win / SAMPLE_DT)))
    var pts := PackedVector2Array()
    for i in nshow:
        var px := i / float(maxi(nshow - 1, 1)) * w
        pts.append(Vector2(px, _baseline - samples[i] * PX_PER_MM))
    draw_polyline(pts, Color(0.10, 0.10, 0.13), 1.7, true)

    var f := ThemeDB.fallback_font
    if measure_mode:
        _draw_calipers(w, h, nshow, f)
    else:
        _build_handles(nshow, w)
        for hd in _handles:
            var p: Vector2 = hd["pos"]
            draw_circle(p, 10.0, Color(0.15, 0.45, 0.85, 0.28))
            draw_circle(p, 5.5, Color(0.10, 0.38, 0.78))
            draw_arc(p, 10.0, 0.0, TAU, 22, Color(0.10, 0.38, 0.78), 1.8)
            draw_string(f, Vector2(p.x + 12, p.y - 9), hd["feature"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.10, 0.20, 0.45))

    _draw_labels(w, h)

func _cal_sample(frac: float, nshow: int) -> float:
    var idx := clampi(int(round(frac * float(maxi(nshow - 1, 1)))), 0, samples.size() - 1)
    return samples[idx]

func _draw_calipers(w: float, h: float, nshow: int, f) -> void:
    var xa := cal_a * w
    var xb := cal_b * w
    var col := Color(0.10, 0.45, 0.30)
    draw_rect(Rect2(minf(xa, xb), 0, absf(xb - xa), h), Color(0.15, 0.6, 0.4, 0.10))
    for xc in [xa, xb]:
        draw_line(Vector2(xc, 0), Vector2(xc, h), col, 1.6)
        draw_circle(Vector2(xc, 8), 6.0, col)
    var va := _cal_sample(cal_a, nshow)
    var vb := _cal_sample(cal_b, nshow)
    draw_circle(Vector2(xa, _baseline - va * PX_PER_MM), 4.0, Color(0.85, 0.2, 0.2))
    draw_circle(Vector2(xb, _baseline - vb * PX_PER_MM), 4.0, Color(0.85, 0.2, 0.2))
    var dt := absf(cal_b - cal_a) * _win_ms()
    var hr := 60000.0 / dt if dt > 1.0 else 0.0
    var damp := absf(vb - va)
    var txt := "Δt = %d мс   ·   ЧСС = %d/мин   ·   ΔU = %.1f мм (%.2f мВ)" % [
        int(round(dt)), int(round(hr)), damp, damp * 0.1]
    draw_rect(Rect2(4, h - 44, w - 8, 22), Color(0.1, 0.35, 0.25, 0.14))
    draw_string(f, Vector2(10, h - 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.08, 0.35, 0.22))

func _draw_labels(_w: float, h: float) -> void:
    var f := ThemeDB.fallback_font
    draw_string(f, Vector2(7, 17), lead_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.10, 0.10, 0.10))
    var hint := "25 мм/с · 10 мм/мВ — тяни каретки-линейки для измерения интервала/ЧСС/амплитуды" if measure_mode \
        else "25 мм/с · 10 мм/мВ — тяни маркеры P/Q/R/S/T/ST: вверх-вниз = амплитуда, влево-вправо = время"
    draw_string(f, Vector2(7, h - 7), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.20, 0.20))

func _build_handles(nshow: int, w: float) -> void:
    _handles.clear()
    var beat_end := mini(nshow, int(rr_ms / SAMPLE_DT))
    if beat_end < 6:
        beat_end = nshow
    var qmarg := maxi(int(qrs_eff_ms / SAMPLE_DT), 6)

    # R — наибольшее по модулю отклонение (центр QRS)
    var qi := 0
    var qv := -1.0
    for i in beat_end:
        var a := absf(samples[i])
        if a > qv:
            qv = a
            qi = i
    _add_handle("R", qi, w, nshow)
    # Q — чуть раньше R; S — чуть позже R (маркеры стоят всегда, можно «вытянуть» зубец)
    _add_handle("Q", clampi(qi - int(qmarg * 0.5), 0, beat_end - 1), w, nshow)
    _add_handle("S", clampi(qi + int(qmarg * 0.5), 0, beat_end - 1), w, nshow)

    # P — положительный горб до QRS (если есть)
    if has_p:
        var pend := maxi(0, qi - qmarg - 2)
        var pi := -1
        var pv := 0.4
        for i in pend:
            if samples[i] > pv:
                pv = samples[i]
                pi = i
        if pi < 0:
            pi = clampi(qi - qmarg - int(qmarg * 0.8), 0, beat_end - 1)  # запасная позиция
        _add_handle("P", pi, w, nshow)

    # T — наибольшее по модулю после QRS
    var tstart := mini(beat_end - 1, qi + qmarg + 3)
    var ti := -1
    var tv := 0.25
    for i in range(tstart, beat_end):
        if absf(samples[i]) > tv:
            tv = absf(samples[i])
            ti = i
    if ti < 0:
        ti = clampi(qi + qmarg * 2, 0, beat_end - 1)
    _add_handle("T", ti, w, nshow)

    # ST / повреждение (инфаркт) — уровень сегмента, маркер у точки J
    var si := mini(beat_end - 1, maxi(0, qi + int(qmarg * 0.65) + 2))
    var sx := si / float(maxi(nshow - 1, 1)) * w
    _handles.append({"feature": "ST", "pos": Vector2(sx, _baseline - st_level * PX_PER_MM), "value": st_level})

func _add_handle(feature: String, idx: int, w: float, nshow: int) -> void:
    if idx < 0 or idx >= samples.size():
        return
    var px := idx / float(maxi(nshow - 1, 1)) * w
    var val := samples[idx]
    _handles.append({"feature": feature, "pos": Vector2(px, _baseline - val * PX_PER_MM), "value": val})

func _gui_input(event: InputEvent) -> void:
    var pos := Vector2.ZERO
    var pressed := false
    var released := false
    var moving := false
    if event is InputEventMouseButton:
        pos = event.position
        pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
        released = (not event.pressed) and event.button_index == MOUSE_BUTTON_LEFT
    elif event is InputEventScreenTouch:
        pos = event.position
        pressed = event.pressed
        released = not event.pressed
    elif event is InputEventMouseMotion:
        pos = event.position
        moving = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
    elif event is InputEventScreenDrag:
        pos = event.position
        moving = true
    else:
        return

    # Режим линейки: тянем ближайшую каретку, параметры не меняем (только измерение).
    if measure_mode:
        var w := maxf(size.x, 1.0)
        if pressed:
            _drag_cal = "a" if absf(pos.x - cal_a * w) <= absf(pos.x - cal_b * w) else "b"
            accept_event()
        elif released:
            _drag_cal = ""
            accept_event()
        elif moving and _drag_cal != "":
            var fr := clampf(pos.x / w, 0.0, 1.0)
            if _drag_cal == "a": cal_a = fr
            else: cal_b = fr
            queue_redraw()
            accept_event()
        return

    if pressed:
        _drag = ""
        var best := GRAB
        for hd in _handles:
            var d: float = pos.distance_to(hd["pos"])
            if d < best:
                best = d
                _drag = hd["feature"]
        if _drag != "":
            accept_event()
    elif released:
        if _drag != "":
            _drag = ""
            drag_ended.emit()
            accept_event()
    elif moving and _drag != "":
        var val_mm := (_baseline - pos.y) / PX_PER_MM       # вертикаль — амплитуда (мВ·10)
        var t_ms := clampf(pos.x / maxf(size.x, 1.0), 0.0, 1.0) * _win_ms()  # горизонталь — время
        handle_dragged.emit(_drag, val_mm, t_ms)
        accept_event()
