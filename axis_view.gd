class_name AxisView
extends Control

var axis_deg := 60.0
var label := ""

func _draw() -> void:
    var c := size * 0.5
    var rad := minf(size.x, size.y) * 0.5 - 26.0
    if rad < 10.0: return
    var font := ThemeDB.fallback_font

    # окружность
    draw_arc(c, rad, 0.0, TAU, 64, Color(0.5, 0.5, 0.55, 0.5), 1.5)

    # оси отведений (ECG: +угол направлен ВНИЗ, экран y тоже вниз)
    var axes := {"I": 0.0, "II": 60.0, "III": 120.0, "aVF": 90.0, "aVL": -30.0, "aVR": -150.0}
    for nm in axes:
        var ang := deg_to_rad(float(axes[nm]))
        var dir := Vector2(cos(ang), sin(ang))
        draw_line(c - dir * rad, c + dir * rad, Color(0.4, 0.45, 0.5, 0.30), 1.0)
        draw_string(font, c + dir * (rad + 6.0) - Vector2(7, -5), nm,
            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.72, 0.8))

    # стрелка электрической оси
    var aang := deg_to_rad(axis_deg)
    var adir := Vector2(cos(aang), sin(aang))
    var tip := c + adir * rad
    var col := Color(0.3, 1.0, 0.45)
    draw_line(c, tip, col, 3.0)
    var perp := Vector2(-adir.y, adir.x)
    draw_line(tip, tip - adir * 13.0 + perp * 7.0, col, 3.0)
    draw_line(tip, tip - adir * 13.0 - perp * 7.0, col, 3.0)
    draw_circle(c, 3.0, col)

    # подпись
    draw_string(font, Vector2(2.0, size.y - 6.0), label,
        HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.95, 0.9))
