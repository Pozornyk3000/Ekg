extends Control

const LEADS := ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]

const DEFAULTS := {
    "hr": 75.0, "p_amp": 1.5, "p_dur": 90.0, "pr": 160.0,
    "q_amp": 1.0, "r_amp": 12.0, "s_amp": 4.0, "qrs_dur": 90.0,
    "st_x": 0.0, "st_y": 0.0, "st_z": 0.0, "qt": 380.0, "t_amp": 4.0,
    "qrs_axis": 60.0, "t_axis": 45.0, "rhythm": "sinus", "bbb": "none", "vt_focus": "lv_lat_mid",
}
const STATE_DEFAULTS := {
    "k": 4.0, "ca": 2.4, "mg": 0.85, "na": 140.0,
    "bp_sys": 120.0, "bp_dia": 80.0,
}
const RHYTHM_NAMES := ["Синусовый", "Фибрилляция предсердий", "Желудочковая тахикардия", "Тахикардия пируэт (Torsades)", "Полная AV-блокада", "ЭКС желудочковый (VVI)", "ЭКС предсердный (AAI)", "ЭКС двухкамерный (DDD)"]
const RHYTHM_VALUES := ["sinus", "afib", "vtach", "torsades", "av3", "pace_vvi", "pace_aai", "pace_ddd"]
const BBB_NAMES := ["Без блокады ножки", "Блокада ЛНПГ", "Блокада ПНПГ"]
const BBB_VALUES := ["none", "lbbb", "rbbb"]
const FOCUS_NAMES := ["ЛЖ боковая", "ЛЖ верхушка", "Перегородка", "ПЖ свободная стенка", "Выносящий тракт ПЖ"]
const FOCUS_VALUES := ["lv_lat_mid", "lv_lat_ap", "sep_mid", "rv_mid", "rv_out"]

# Препараты: d/sd — терапевтическая доза; td/tsd — ДОБАВКА при токсической; trhythm — аритмия при токсичности.
const DRUGS := [
    {"name": "Дигоксин", "d": {"qt": -35.0, "pr": 25.0, "hr": -10.0, "t_amp": -1.5}, "sd": {}, "td": {"pr": 45.0, "hr": -18.0}, "tsd": {}, "trhythm": "av3", "desc": "тер: ↓QT, ↑PR, корытообразная ST. токс: AV-блокада, аритмии"},
    {"name": "Амиодарон (III)", "d": {"qt": 60.0, "hr": -15.0, "qrs_dur": 8.0}, "sd": {}, "td": {"qt": 75.0, "hr": -12.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↑↑QT, брадикардия. токс: ↑↑↑QT — риск Torsades"},
    {"name": "Соталол (III)", "d": {"qt": 55.0, "hr": -18.0}, "sd": {}, "td": {"qt": 80.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↑↑QT, ↓ЧСС. токс: ↑↑↑QT — Torsades"},
    {"name": "Флекаинид (IC)", "d": {"qrs_dur": 35.0, "pr": 20.0, "qt": 15.0}, "sd": {}, "td": {"qrs_dur": 60.0}, "tsd": {}, "trhythm": "vtach", "desc": "тер: ↑↑QRS, ↑PR. токс: очень широкий QRS, ЖТ"},
    {"name": "Хинидин (IA)", "d": {"qt": 45.0, "qrs_dur": 15.0}, "sd": {}, "td": {"qt": 65.0, "qrs_dur": 25.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↑QT, ↑QRS. токс: ↑↑QT — Torsades"},
    {"name": "Лидокаин (IB)", "d": {"qt": -12.0}, "sd": {}, "td": {"qrs_dur": 18.0, "hr": -10.0}, "tsd": {}, "trhythm": "", "desc": "тер: минимум, ↓QT. токс: ↑QRS, ↓ЧСС"},
    {"name": "Бета-блокатор", "d": {"hr": -22.0, "pr": 18.0}, "sd": {}, "td": {"hr": -28.0, "pr": 35.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↓ЧСС, ↑PR. токс: тяжёлая брадикардия"},
    {"name": "Верапамил/Дилтиазем", "d": {"hr": -12.0, "pr": 32.0}, "sd": {}, "td": {"hr": -28.0, "pr": 55.0}, "tsd": {}, "trhythm": "av3", "desc": "тер: ↓ЧСС, ↑↑PR. токс: AV-блокада"},
    {"name": "Атропин", "d": {"hr": 35.0, "pr": -15.0}, "sd": {}, "td": {"hr": 45.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↑↑ЧСС. токс: выраженная тахикардия"},
    {"name": "Адреналин", "d": {"hr": 45.0}, "sd": {}, "td": {"hr": 60.0}, "tsd": {}, "trhythm": "", "desc": "тер: ↑↑↑ЧСС. токс: тахиаритмия"},
    {"name": "Амитриптилин (ТЦА)", "d": {"qrs_dur": 25.0, "qt": 40.0, "hr": 18.0}, "sd": {}, "td": {"qrs_dur": 55.0, "qt": 55.0}, "tsd": {}, "trhythm": "vtach", "desc": "тер: ↑QRS, ↑QT. токс: ↑↑↑QRS, ЖТ"},
    {"name": "Спиронолактон", "d": {}, "sd": {"k": 1.0}, "td": {}, "tsd": {"k": 2.5}, "trhythm": "", "desc": "тер: ↑K. токс: гиперкалиемия — высокие T"},
    {"name": "Фуросемид", "d": {}, "sd": {"k": -1.0, "mg": -0.2}, "td": {}, "tsd": {"k": -1.8, "mg": -0.4}, "trhythm": "", "desc": "тер: ↓K/Mg. токс: гипокалиемия — U, ↑QT"},
]
const DOSE_NAMES := ["Выкл", "Терапевт.", "Токсич."]
const STRESS_STAGES := ["Покой", "Ступень 1", "Ступень 2", "Ступень 3", "Ступень 4", "Пик нагрузки", "Восстановление 1 мин", "Восстановление 3 мин"]
const STENOSIS_NAMES := ["Нет стеноза", "Умеренный стеноз", "Выраженный стеноз"]

const PRESETS := [
    {"name": "Норма", "p": {}, "s": {}},
    {"name": "Инфаркт нижний (STEMI)", "p": {"st_y": 3.0, "q_amp": 3.0}, "s": {}},
    {"name": "Инфаркт передний (STEMI)", "p": {"st_z": -3.0}, "s": {}},
    {"name": "ГЛЖ (гипертрофия ЛЖ)", "p": {"r_amp": 28.0, "s_amp": 14.0, "qrs_axis": -20.0}, "s": {"bp_sys": 185.0}},
    {"name": "Блокада ЛНПГ", "p": {"bbb": "lbbb", "qrs_dur": 150.0, "qrs_axis": -30.0}, "s": {}},
    {"name": "Блокада ПНПГ", "p": {"bbb": "rbbb", "qrs_dur": 140.0}, "s": {}},
    {"name": "AV-блокада 1 ст.", "p": {"pr": 280.0}, "s": {}},
    {"name": "Полная AV-блокада", "p": {"rhythm": "av3"}, "s": {}},
    {"name": "Брадикардия", "p": {"hr": 45.0}, "s": {}},
    {"name": "Синусовая тахикардия", "p": {"hr": 130.0}, "s": {}},
    {"name": "Желудочковая тахикардия", "p": {"rhythm": "vtach", "hr": 180.0}, "s": {}},
    {"name": "Тахикардия пируэт (Torsades)", "p": {"rhythm": "torsades", "hr": 240.0, "qt": 520.0, "p_amp": 0.0}, "s": {"mg": 0.4}},
    {"name": "Кардиостимулятор (VVI)", "p": {"rhythm": "pace_vvi", "hr": 70.0, "p_amp": 0.0}, "s": {}},
    {"name": "Детское сердце", "p": {"rhythm": "sinus", "bbb": "none", "hr": 130.0, "pr": 110.0, "qt": 300.0, "qrs_axis": 100.0, "qrs_dur": 70.0, "r_amp": 10.0}, "s": {}},
    {"name": "Сердце атлета", "p": {"rhythm": "sinus", "bbb": "none", "hr": 48.0, "pr": 205.0, "r_amp": 17.0, "s_amp": 8.0, "qrs_axis": 65.0}, "s": {"bp_sys": 118.0}},
    {"name": "Фибрилляция предсердий", "p": {"rhythm": "afib", "hr": 110.0, "p_amp": 0.0}, "s": {}},
    {"name": "Гиперкалиемия", "p": {}, "s": {"k": 7.0}},
    {"name": "Гипокалиемия", "p": {}, "s": {"k": 2.5}},
    {"name": "Гипокальциемия (long QT)", "p": {}, "s": {"ca": 1.7}},
]

var params := DEFAULTS.duplicate(true)
var state := STATE_DEFAULTS.duplicate(true)
var lead_views: Array = []
var buffers: Array = []
var sliders := {}
var lead_amp := {}
var selected_lead := 1
var _last_eff: Dictionary = {}
var edit_view: EditView
var edit_btn: Button
var edit_mode := false
var _built := false
var _suspend := false

var dx_label: Label
var wb_label: Label
var report_label: Label
var axis_view: AxisView
var analysis_label: Label
var monitor: MonitorView
var preset_opt: OptionButton
var rhythm_opt: OptionButton
var bbb_opt: OptionButton
var lead_opt: OptionButton
var rate_slider: HSlider
var rate_label: Label
var focus_opt: OptionButton
var prob_label: Label
var diff_label: Label
var drug_summary: Label
var active_drugs: Array = []
var drug_opts: Array = []
var stress_age := 50.0
var stress_sten := 0
var stress_stage := 0
var stress_view: StressView
var stress_label: Label
var stress_stage_label: Label
var stress_age_label: Label
var stress_stage_slider: HSlider
var stress_run_btn: Button
var stress_timer: Timer
var stress_running := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 10)
    add_child(margin)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 5)
    margin.add_child(vb)

    dx_label = Label.new()
    dx_label.add_theme_font_size_override("font_size", 22)
    dx_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(dx_label)

    wb_label = Label.new()
    wb_label.add_theme_font_size_override("font_size", 15)
    wb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(wb_label)

    report_label = Label.new()
    report_label.add_theme_font_size_override("font_size", 13)
    report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    report_label.modulate = Color(0.82, 0.87, 0.92)
    vb.add_child(report_label)

    prob_label = Label.new()
    prob_label.add_theme_font_size_override("font_size", 14)
    prob_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(prob_label)

    vb.add_child(HSeparator.new())

    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.add_child(tabs)

    active_drugs.resize(DRUGS.size())
    for i in DRUGS.size():
        active_drugs[i] = 0

    _build_monitor_tab(tabs)
    _build_params_tab(tabs)
    _build_drugs_tab(tabs)
    _build_analysis_tab(tabs)
    _build_stress_tab(tabs)

    _built = true
    _recompute()

func _build_monitor_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(0, "Монитор")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 8)
    sc.add_child(col)

    _mk_label(col, "Патология (пресет):", 14)
    preset_opt = OptionButton.new()
    preset_opt.custom_minimum_size = Vector2(0, 42)
    for p in PRESETS:
        preset_opt.add_item(p["name"])
    preset_opt.item_selected.connect(_apply_preset)
    col.add_child(preset_opt)

    _mk_label(col, "Ритм:", 14)
    rhythm_opt = OptionButton.new()
    rhythm_opt.custom_minimum_size = Vector2(0, 42)
    for n in RHYTHM_NAMES:
        rhythm_opt.add_item(n)
    rhythm_opt.item_selected.connect(_on_rhythm)
    col.add_child(rhythm_opt)

    _mk_label(col, "Блокада ножки:", 14)
    bbb_opt = OptionButton.new()
    bbb_opt.custom_minimum_size = Vector2(0, 42)
    for n in BBB_NAMES:
        bbb_opt.add_item(n)
    bbb_opt.item_selected.connect(_on_bbb)
    col.add_child(bbb_opt)

    _mk_label(col, "Очаг ЖТ/ЖЭ (форма широкого комплекса):", 14)
    focus_opt = OptionButton.new()
    focus_opt.custom_minimum_size = Vector2(0, 42)
    for n in FOCUS_NAMES:
        focus_opt.add_item(n)
    focus_opt.item_selected.connect(_on_focus)
    col.add_child(focus_opt)

    rate_label = Label.new()
    rate_label.add_theme_font_size_override("font_size", 16)
    col.add_child(rate_label)
    rate_slider = HSlider.new()
    rate_slider.min_value = 30
    rate_slider.max_value = 220
    rate_slider.step = 1
    rate_slider.custom_minimum_size = Vector2(0, 40)
    rate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rate_slider.value_changed.connect(_on_rate)
    col.add_child(rate_slider)

    monitor = MonitorView.new()
    monitor.custom_minimum_size = Vector2(0, 150)
    monitor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    monitor.clip_contents = true
    col.add_child(monitor)

    edit_btn = Button.new()
    edit_btn.text = "✏ Редактировать кривую (сетка ЭКГ)"
    edit_btn.custom_minimum_size = Vector2(0, 42)
    edit_btn.pressed.connect(_toggle_edit)
    col.add_child(edit_btn)

    edit_view = EditView.new()
    edit_view.custom_minimum_size = Vector2(0, 270)
    edit_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit_view.clip_contents = true
    edit_view.visible = false
    edit_view.handle_dragged.connect(_on_edit_drag)
    edit_view.drag_ended.connect(_on_edit_release)
    col.add_child(edit_view)

    _mk_label(col, "Отведения — нажми для выбора:", 14)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(grid)
    for i in LEADS.size():
        var lv := LeadView.new()
        lv.lead_name = LEADS[i]
        lv.custom_minimum_size = Vector2(0, 58)
        lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        lv.clip_contents = true
        lv.gui_input.connect(_on_thumb_input.bind(i))
        grid.add_child(lv)
        lead_views.append(lv)

func _build_params_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(1, "Параметры")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 9)
    sc.add_child(col)

    _mk_label(col, "Отведение для правки:", 15)
    lead_opt = OptionButton.new()
    lead_opt.custom_minimum_size = Vector2(0, 42)
    for nm in LEADS:
        lead_opt.add_item(nm)
    lead_opt.item_selected.connect(_on_lead_opt)
    col.add_child(lead_opt)

    _mk_label(col, "— Правка в этом отведении (остальные следуют за вектором; ST → реципрокные) —", 12)
    _add_lead_amp(col, "r_amp", "R", -30, 30, 0.5, "мм")
    _add_lead_amp(col, "t_amp", "T", -20, 20, 0.5, "мм")
    _add_lead_amp(col, "st", "ST", -8, 8, 0.1, "мм")

    col.add_child(HSeparator.new())
    _mk_label(col, "— Общее (одинаково во всех отведениях) —", 12)
    _add_param(col, params, "qrs_axis", "Ось QRS", -120, 180, 5, "°")
    _add_param(col, params, "t_axis", "Ось T", -120, 180, 5, "°")
    _add_param(col, params, "p_amp", "Зубец P", 0, 5, 0.1, "мм")
    _add_param(col, params, "p_dur", "Длительность P", 40, 160, 5, "мс")
    _add_param(col, params, "pr", "Интервал PR", 80, 320, 5, "мс")
    _add_param(col, params, "q_amp", "Зубец Q", 0, 8, 0.1, "мм")
    _add_param(col, params, "s_amp", "Зубец S", 0, 30, 0.5, "мм")
    _add_param(col, params, "qrs_dur", "QRS (база проведения)", 40, 200, 5, "мс")
    _add_param(col, params, "qt", "QT корриг. (база)", 200, 600, 10, "мс")

    col.add_child(HSeparator.new())
    _mk_label(col, "Электролиты и АД", 15)
    _add_param(col, state, "k", "Калий K⁺", 2.0, 9.0, 0.1, "ммоль/л")
    _add_param(col, state, "ca", "Кальций Ca²⁺", 1.5, 3.5, 0.05, "ммоль/л")
    _add_param(col, state, "mg", "Магний Mg²⁺", 0.3, 2.0, 0.05, "ммоль/л")
    _add_param(col, state, "na", "Натрий Na⁺", 120, 160, 1, "ммоль/л")
    _add_param(col, state, "bp_sys", "АД систолическое", 90, 220, 5, "мм рт.ст.")
    _add_param(col, state, "bp_dia", "АД диастолическое", 50, 130, 5, "мм рт.ст.")

    var rm := Button.new()
    rm.text = "Норма морфологии"
    rm.custom_minimum_size = Vector2(0, 44)
    rm.pressed.connect(_reset_keys.bind(DEFAULTS, true))
    col.add_child(rm)
    var rs := Button.new()
    rs.text = "Норма электролитов / АД"
    rs.custom_minimum_size = Vector2(0, 44)
    rs.pressed.connect(_reset_keys.bind(STATE_DEFAULTS, false))
    col.add_child(rs)

func _build_drugs_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(2, "Препараты")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 4)
    sc.add_child(col)

    _mk_label(col, "Доза каждого препарата (эффекты суммируются):", 14)
    for i in DRUGS.size():
        var dr: Dictionary = DRUGS[i]
        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var nm := Label.new()
        nm.text = str(dr["name"])
        nm.add_theme_font_size_override("font_size", 15)
        nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(nm)
        var ob := OptionButton.new()
        ob.custom_minimum_size = Vector2(150, 40)
        for dn in DOSE_NAMES:
            ob.add_item(dn)
        ob.item_selected.connect(_on_drug_dose.bind(i))
        row.add_child(ob)
        drug_opts.append(ob)
        col.add_child(row)
        var dl := Label.new()
        dl.text = "    " + str(dr["desc"])
        dl.add_theme_font_size_override("font_size", 12)
        dl.modulate = Color(0.65, 0.72, 0.8)
        dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        col.add_child(dl)

    var clr := Button.new()
    clr.text = "Очистить все препараты"
    clr.custom_minimum_size = Vector2(0, 42)
    clr.pressed.connect(_clear_drugs)
    col.add_child(clr)

    col.add_child(HSeparator.new())
    drug_summary = Label.new()
    drug_summary.add_theme_font_size_override("font_size", 14)
    drug_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(drug_summary)

func _build_analysis_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(3, "Анализ")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 8)
    sc.add_child(col)

    _mk_label(col, "Дифференциальный диагноз (оценка вероятности):", 15)
    diff_label = Label.new()
    diff_label.add_theme_font_size_override("font_size", 15)
    diff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(diff_label)
    col.add_child(HSeparator.new())

    axis_view = AxisView.new()
    axis_view.custom_minimum_size = Vector2(0, 300)
    axis_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(axis_view)

    analysis_label = Label.new()
    analysis_label.add_theme_font_size_override("font_size", 15)
    analysis_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(analysis_label)

func _mk_label(parent: Node, text: String, fs: int) -> void:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", fs)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.text = text
    parent.add_child(l)

func _add_param(parent: Node, target: Dictionary, key: String, title: String, mn: float, mx: float, step: float, unit: String) -> void:
    var box := VBoxContainer.new()
    var lab := Label.new()
    lab.add_theme_font_size_override("font_size", 16)
    box.add_child(lab)
    var sl := HSlider.new()
    sl.min_value = mn
    sl.max_value = mx
    sl.step = step
    sl.value = target[key]
    sl.custom_minimum_size = Vector2(0, 40)
    sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(sl)
    parent.add_child(box)
    sliders[key] = sl

    var update := func(v: float) -> void:
        target[key] = v
        lab.text = "%s:  %s %s" % [title, _fmt(v, step), unit]
        _recompute()
    sl.value_changed.connect(update)
    update.call(target[key])

func _add_lead_amp(parent: Node, key: String, title: String, mn: float, mx: float, step: float, unit: String) -> void:
    var box := VBoxContainer.new()
    var lab := Label.new()
    lab.add_theme_font_size_override("font_size", 16)
    box.add_child(lab)
    var sl := HSlider.new()
    sl.min_value = mn
    sl.max_value = mx
    sl.step = step
    sl.custom_minimum_size = Vector2(0, 40)
    sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(sl)
    parent.add_child(box)
    sl.value_changed.connect(_on_lead_amp.bind(key))
    lead_amp[key] = {"slider": sl, "label": lab, "title": title, "step": step, "unit": unit}

func _fmt(v: float, step: float) -> String:
    if step < 0.1: return "%.2f" % v
    if step < 1.0: return "%.1f" % v
    return str(roundi(v))

func _set_value(key: String, val, is_param: bool) -> void:
    if sliders.has(key):
        sliders[key].value = val
    elif is_param:
        params[key] = val
    else:
        state[key] = val

func _reset_keys(defs: Dictionary, is_param: bool) -> void:
    _suspend = true
    for key in defs:
        _set_value(key, defs[key], is_param)
    _suspend = false
    _recompute()

func _apply_preset(idx: int) -> void:
    var preset: Dictionary = PRESETS[idx]
    _suspend = true
    for key in DEFAULTS: _set_value(key, DEFAULTS[key], true)
    for key in STATE_DEFAULTS: _set_value(key, STATE_DEFAULTS[key], false)
    for key in preset["p"]: _set_value(key, preset["p"][key], true)
    for key in preset["s"]: _set_value(key, preset["s"][key], false)
    _suspend = false
    _recompute()

func _build_stress_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(4, "Проба")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 8)
    sc.add_child(col)

    _mk_label(col, "Нагрузочная проба (тредмил/велоэргометр):", 15)
    stress_age_label = Label.new()
    stress_age_label.add_theme_font_size_override("font_size", 14)
    col.add_child(stress_age_label)
    var age_sl := HSlider.new()
    age_sl.min_value = 30
    age_sl.max_value = 80
    age_sl.step = 1
    age_sl.value = stress_age
    age_sl.custom_minimum_size = Vector2(0, 36)
    age_sl.value_changed.connect(_on_stress_age)
    col.add_child(age_sl)

    _mk_label(col, "Коронарный стеноз:", 14)
    var sten := OptionButton.new()
    sten.custom_minimum_size = Vector2(0, 42)
    for nm in STENOSIS_NAMES:
        sten.add_item(nm)
    sten.item_selected.connect(_on_stress_sten)
    col.add_child(sten)

    stress_stage_label = Label.new()
    stress_stage_label.add_theme_font_size_override("font_size", 15)
    col.add_child(stress_stage_label)
    stress_stage_slider = HSlider.new()
    stress_stage_slider.min_value = 0
    stress_stage_slider.max_value = 7
    stress_stage_slider.step = 1
    stress_stage_slider.value = 0
    stress_stage_slider.custom_minimum_size = Vector2(0, 40)
    stress_stage_slider.value_changed.connect(_on_stress_stage)
    col.add_child(stress_stage_slider)

    stress_run_btn = Button.new()
    stress_run_btn.text = "▶ Запустить пробу"
    stress_run_btn.custom_minimum_size = Vector2(0, 46)
    stress_run_btn.pressed.connect(_toggle_stress_run)
    col.add_child(stress_run_btn)

    stress_timer = Timer.new()
    stress_timer.wait_time = 2.2
    stress_timer.one_shot = false
    stress_timer.timeout.connect(_stress_tick)
    add_child(stress_timer)

    stress_view = StressView.new()
    stress_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(stress_view)

    stress_label = Label.new()
    stress_label.add_theme_font_size_override("font_size", 15)
    stress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(stress_label)

    _stress_refresh_display()

func _on_stress_age(v: float) -> void:
    stress_age = v
    _stress_apply()

func _on_stress_sten(i: int) -> void:
    stress_sten = i
    _stress_apply()

func _on_stress_stage(v: float) -> void:
    if stress_running: _stop_stress_run()
    stress_stage = int(v)
    _stress_apply()

func _start_stress_run() -> void:
    stress_running = true
    if stress_run_btn: stress_run_btn.text = "⏸ Остановить пробу"
    stress_stage = 0
    if stress_stage_slider: stress_stage_slider.set_value_no_signal(0)
    _stress_apply()
    if stress_timer: stress_timer.start()

func _stop_stress_run() -> void:
    stress_running = false
    if stress_timer: stress_timer.stop()
    if stress_run_btn: stress_run_btn.text = "▶ Запустить пробу"

func _toggle_stress_run() -> void:
    if stress_running:
        _stop_stress_run()
    else:
        _start_stress_run()

func _stress_tick() -> void:
    stress_stage += 1
    if stress_stage > 7:
        stress_stage = 7
        _stop_stress_run()
        return
    if stress_stage_slider: stress_stage_slider.set_value_no_signal(stress_stage)
    _stress_apply()

func _stress_apply() -> void:
    if not _built: return
    var sv := ECGModel.stress_st_vec(ECGModel.stress_depr(stress_age, stress_sten, stress_stage))
    var bp := ECGModel.stress_bp(stress_sten, stress_stage)
    _suspend = true
    params["rhythm"] = "sinus"
    params["hr"] = ECGModel.stress_hr(stress_age, stress_stage)
    params["st_x"] = sv.x
    params["st_y"] = sv.y
    params["st_z"] = sv.z
    state["bp_sys"] = bp.x
    state["bp_dia"] = bp.y
    _suspend = false
    _recompute()
    _stress_refresh_display()

func _stress_refresh_display() -> void:
    var hrv: Array = []
    var dpv: Array = []
    var spv: Array = []
    for s in 8:
        hrv.append(ECGModel.stress_hr(stress_age, s))
        dpv.append(ECGModel.stress_depr(stress_age, stress_sten, s))
        spv.append(ECGModel.stress_bp(stress_sten, s).x)
    if stress_view:
        stress_view.hr_vals = hrv
        stress_view.depr_vals = dpv
        stress_view.sys_vals = spv
        stress_view.cur_stage = stress_stage
        stress_view.queue_redraw()
    if stress_age_label:
        stress_age_label.text = "Возраст: %d лет  (целевая ЧСС %d)" % [roundi(stress_age), roundi(ECGModel.stress_target_hr(stress_age))]
    if stress_stage_label:
        stress_stage_label.text = "Этап: %s" % STRESS_STAGES[stress_stage]
    if stress_label:
        var hr := ECGModel.stress_hr(stress_age, stress_stage)
        var depr := ECGModel.stress_depr(stress_age, stress_sten, stress_stage)
        var bp := ECGModel.stress_bp(stress_sten, stress_stage)
        var peak_depr := 0.0
        for s in stress_stage + 1:
            peak_depr = maxf(peak_depr, ECGModel.stress_depr(stress_age, stress_sten, s))
        var pct := roundi(hr / maxf(ECGModel.stress_target_hr(stress_age), 1.0) * 100.0)
        stress_label.text = "ЧСС %d (%d%%)  ·  АД %d/%d  ·  депрессия ST ~%.1f мм\nЗаключение: проба %s; реакция АД %s" % [
            roundi(hr), pct, roundi(bp.x), roundi(bp.y), depr,
            ECGModel.stress_verdict(peak_depr), ECGModel.stress_bp_verdict(stress_sten)]

func _on_rhythm(idx: int) -> void:
    params["rhythm"] = RHYTHM_VALUES[idx]
    _recompute()

func _on_bbb(idx: int) -> void:
    params["bbb"] = BBB_VALUES[idx]
    _recompute()

func _on_focus(idx: int) -> void:
    params["vt_focus"] = FOCUS_VALUES[idx]
    _recompute()

func _on_drug_dose(level: int, i: int) -> void:
    if not _built: return
    active_drugs[i] = level
    _recompute()

func _clear_drugs() -> void:
    for i in DRUGS.size():
        active_drugs[i] = 0
        if i < drug_opts.size():
            drug_opts[i].selected = 0
    _recompute()

func _drug_param_deltas() -> Dictionary:
    var out := {}
    for i in DRUGS.size():
        var lvl: int = active_drugs[i]
        if lvl < 1: continue
        var dr: Dictionary = DRUGS[i]
        for key in dr["d"]:
            out[key] = float(out.get(key, 0.0)) + float(dr["d"][key])
        if lvl == 2:
            for key in dr["td"]:
                out[key] = float(out.get(key, 0.0)) + float(dr["td"][key])
    return out

func _eff_state() -> Dictionary:
    var s := state.duplicate(true)
    for i in DRUGS.size():
        var lvl: int = active_drugs[i]
        if lvl < 1: continue
        var dr: Dictionary = DRUGS[i]
        for key in dr["sd"]:
            s[key] = float(s.get(key, 0.0)) + float(dr["sd"][key])
        if lvl == 2:
            for key in dr["tsd"]:
                s[key] = float(s.get(key, 0.0)) + float(dr["tsd"][key])
    s["k"] = clampf(float(s["k"]), 1.5, 9.5)
    s["ca"] = clampf(float(s["ca"]), 1.4, 3.6)
    s["mg"] = clampf(float(s["mg"]), 0.2, 2.2)
    return s

# аритмия от токсичности (vtach приоритетнее av3)
func _drug_rhythm() -> String:
    var found := ""
    for i in DRUGS.size():
        if active_drugs[i] != 2: continue
        var tr := str(DRUGS[i].get("trhythm", ""))
        if tr == "vtach": return "vtach"
        if tr != "" and found == "": found = tr
    return found

func _on_rate(v: float) -> void:
    if _suspend or not _built: return
    params["hr"] = v
    _recompute()

func _on_lead_opt(idx: int) -> void:
    _select_lead(idx)

func _sync_selectors() -> void:
    var ri := RHYTHM_VALUES.find(str(params["rhythm"]))
    rhythm_opt.selected = ri if ri >= 0 else 0
    var bi := BBB_VALUES.find(str(params["bbb"]))
    bbb_opt.selected = bi if bi >= 0 else 0
    var fi := FOCUS_VALUES.find(str(params.get("vt_focus", "lv_lat_mid")))
    if focus_opt: focus_opt.selected = fi if fi >= 0 else 0

# проекция амплитуды (R/T) в отведении через 3D-геометрию
func _amp_scale(key: String, lead: int) -> float:
    if key == "t_amp":
        return ECGModel.LEADVEC[lead].dot(ECGModel.t_dir(params))
    return ECGModel.LEADVEC[lead].dot(ECGModel.main_dir(params))

func _lead_st_level(lead: int) -> float:
    return ECGModel.st_level_lead(params, lead)

# правка R/T/ST в выбранном отведении -> back-solve вектора
func _on_lead_amp(v: float, key: String) -> void:
    if _suspend or not _built: return
    var i := selected_lead
    if key == "st":
        var lvv: Vector3 = ECGModel.LEADVEC[i]
        params["st_x"] = lvv.x * v
        params["st_y"] = lvv.y * v
        params["st_z"] = lvv.z * v
    else:
        var scl := _amp_scale(key, i)
        if absf(scl) < 0.15:
            scl = 0.15 if scl >= 0.0 else -0.15
        var lim := 60.0 if key == "r_amp" else 40.0
        params[key] = clampf(v / scl, -lim, lim)
    _recompute()

func _toggle_edit() -> void:
    edit_mode = not edit_mode
    if monitor: monitor.visible = not edit_mode
    if edit_view: edit_view.visible = edit_mode
    edit_btn.text = "▶ Вернуть монитор" if edit_mode else "✏ Редактировать кривую (сетка ЭКГ)"
    if edit_mode:
        _refresh_edit()

func _refresh_edit() -> void:
    if edit_view == null or not edit_mode:
        return
    if buffers.size() <= selected_lead:
        return
    edit_view.samples = buffers[selected_lead]
    edit_view.lead_name = LEADS[selected_lead]
    edit_view.qrs_eff_ms = float(_last_eff.get("qrs_eff", 90.0))
    edit_view.st_level = ECGModel.st_level_lead(params, selected_lead)
    edit_view.rr_ms = 60000.0 / maxf(float(_last_eff.get("hr", 75.0)), 20.0)
    var rh := str(_last_eff.get("rhythm", "sinus"))
    var hp := (rh == "sinus" or rh == "av3" or rh == "pace_aai" or rh == "pace_ddd")
    edit_view.has_p = hp and float(params.get("p_amp", 0.0)) > 0.2
    edit_view.queue_redraw()

func _nz(x: float) -> float:
    if absf(x) < 0.15:
        return 0.15 if x >= 0.0 else -0.15
    return x

func _apply_edit_param(feature: String, value: float) -> void:
    var i := selected_lead
    if feature == "ST":
        var v := clampf(value, -9.0, 9.0)
        var lvv: Vector3 = ECGModel.LEADVEC[i]
        params["st_x"] = lvv.x * v
        params["st_y"] = lvv.y * v
        params["st_z"] = lvv.z * v
    elif feature == "P":
        var sp := _nz(ECGModel.LEADVEC[i].dot(ECGModel.p_dir(params)))
        params["p_amp"] = clampf(value / sp, -3.0, 6.0)
    elif feature == "T":
        var stp := _nz(ECGModel.LEADVEC[i].dot(ECGModel.t_dir(params)))
        params["t_amp"] = clampf(value / stp, -40.0, 40.0)
    else:
        var sr := _nz(ECGModel.LEADVEC[i].dot(ECGModel.main_dir(params)))
        params["r_amp"] = clampf(value / sr, -60.0, 60.0)

func _on_edit_drag(feature: String, value: float) -> void:
    if not _built:
        return
    _apply_edit_param(feature, value)
    var eff := _effective_params()
    _last_eff = eff
    if buffers.size() > selected_lead:
        buffers[selected_lead] = ECGModel.generate_lead(eff, selected_lead)
    _refresh_edit()

func _on_edit_release() -> void:
    if not _built:
        return
    _recompute()

func _on_thumb_input(event: InputEvent, i: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _select_lead(i)

func _select_lead(i: int) -> void:
    selected_lead = i
    _refresh_views()

func _refresh_views() -> void:
    _refresh_monitor()
    _refresh_param_amps()
    if edit_mode and edit_view:
        _refresh_edit()
    if rate_slider:
        rate_slider.set_value_no_signal(float(params["hr"]))
        rate_label.text = "Частота (ЧСС):  %d уд/мин" % roundi(float(params["hr"]))

func _refresh_monitor() -> void:
    for j in lead_views.size():
        var lvj: LeadView = lead_views[j]
        lvj.highlighted = (j == selected_lead)
        lvj.queue_redraw()
    if _last_eff.is_empty(): return
    monitor.samples = ECGModel.generate_monitor(_last_eff, selected_lead, 20000.0, 4000)
    monitor.lead_name = LEADS[selected_lead]
    monitor.queue_redraw()

func _refresh_param_amps() -> void:
    if lead_opt:
        lead_opt.selected = selected_lead
    for key in lead_amp:
        var info: Dictionary = lead_amp[key]
        var proj: float
        if key == "st":
            proj = _lead_st_level(selected_lead)
        else:
            proj = float(params[key]) * _amp_scale(key, selected_lead)
        var sl: HSlider = info["slider"]
        sl.set_value_no_signal(clampf(proj, sl.min_value, sl.max_value))
        info["label"].text = "%s в %s:  %s %s" % [
            info["title"], LEADS[selected_lead], _fmt(proj, info["step"]), info["unit"]]

func _effective_params() -> Dictionary:
    var e := params.duplicate(true)
    e["t_sharp"] = 1.0
    e["u_amp"] = 0.0
    var es := _eff_state()

    var dd := _drug_param_deltas()
    for key in dd:
        e[key] = float(e.get(key, 0.0)) + float(dd[key])

    var k := float(es["k"])
    if k > 5.5:
        var hk := k - 5.5
        e["t_amp"] = float(e["t_amp"]) + hk * 4.0
        e["t_sharp"] = 1.0 + hk * 0.5
        e["pr"] = float(e["pr"]) + hk * 22.0
        e["p_amp"] = maxf(0.0, float(e["p_amp"]) - hk * 0.7)
        e["qrs_dur"] = float(e["qrs_dur"]) + hk * 18.0
    elif k < 3.5:
        var lk := 3.5 - k
        e["t_amp"] = float(e["t_amp"]) - lk * 1.5
        e["u_amp"] = lk * 1.2
        e["qt"] = float(e["qt"]) + lk * 20.0

    var ca := float(es["ca"])
    if ca < 2.2:
        e["qt"] = float(e["qt"]) + (2.2 - ca) * 200.0
    elif ca > 2.6:
        e["qt"] = float(e["qt"]) - (ca - 2.6) * 200.0

    var mg := float(es["mg"])
    if mg < 0.6:
        e["qt"] = float(e["qt"]) + (0.6 - mg) * 120.0
    elif mg > 1.2:
        e["pr"] = float(e["pr"]) + (mg - 1.2) * 30.0
        e["qrs_dur"] = float(e["qrs_dur"]) + (mg - 1.2) * 15.0

    var sys := float(state["bp_sys"])
    if sys > 145.0:
        var d := (sys - 145.0) / 10.0
        e["r_amp"] = float(e["r_amp"]) + d * 3.0
        e["s_amp"] = float(e["s_amp"]) + d * 2.0

    var rr_sec := 60.0 / clampf(float(e["hr"]), 20.0, 300.0)
    e["qtc"] = clampf(float(e["qt"]), 240.0, 700.0)
    e["qt"] = clampf(float(e["qtc"]) * sqrt(rr_sec), 180.0, 700.0)
    e["qrs_dur"] = clampf(e["qrs_dur"], 40.0, 220.0)
    e["pr"] = clampf(e["pr"], 80.0, 400.0)
    e["r_amp"] = clampf(e["r_amp"], -60.0, 60.0)
    e["s_amp"] = clampf(e["s_amp"], 0.0, 50.0)
    var drh := _drug_rhythm()
    if drh != "":
        e["rhythm"] = drh
    return e

func _recompute() -> void:
    if not _built or _suspend: return
    var eff := _effective_params()
    _last_eff = eff
    var gen := ECGModel.generate_all(eff)
    buffers = gen["buffers"]
    var ev: Dictionary = gen["ev"]
    eff["qrs_eff"] = float(gen["qeff"])

    var sp := ECGModel.M / ECGModel.WINDOW_MS
    var vent: Array = ev["vent"]
    var fv := float(vent[0]["t"]) if not vent.is_empty() else 0.0
    var qd := maxf(float(gen["qeff"]), 140.0)
    var lo := maxi(0, int((fv - 20.0) * sp))
    var hi := int((fv + qd + 40.0) * sp)

    var rs: Array = []
    for i in lead_views.size():
        var buf: PackedFloat32Array = buffers[i]
        var lv: LeadView = lead_views[i]
        lv.samples = buf
        lv.queue_redraw()
        rs.append(ECGModel.measure_rs(buf, lo, hi))

    var rhythm := str(eff.get("rhythm", "sinus"))
    var es := _eff_state()
    var ed := ECGModel.electrolyte_dx(es)
    var res := ECGModel.classify(eff)
    var sok := ECGModel.sokolow(rs)
    var net_i: float = rs[0].x - rs[0].y
    var net_avf: float = rs[5].x - rs[5].y
    var axis: float
    if absf(net_i) < 0.05 and absf(net_avf) < 0.05:
        axis = float(eff["qrs_axis"])
    else:
        axis = rad_to_deg(atan2(net_avf, net_i))
    var axis_lbl := ECGModel.axis_label(axis)

    axis_view.axis_deg = axis
    axis_view.label = "Ось %d° — %s" % [roundi(axis), axis_lbl]
    axis_view.queue_redraw()

    var primary_dx: String
    var primary_conf: float
    if rhythm == "afib":
        primary_dx = "Фибрилляция предсердий"
        primary_conf = 0.9
    elif rhythm == "vtach":
        primary_dx = "Желудочковая тахикардия"
        primary_conf = 0.95
    elif rhythm == "torsades":
        primary_dx = "Тахикардия пируэт (Torsades)"
        primary_conf = 0.95
    elif rhythm == "av3":
        primary_dx = "Полная AV-блокада (диссоциация)"
        primary_conf = 0.9
    elif rhythm == "pace_vvi":
        primary_dx = "ЭКС: желудочковая стимуляция (VVI)"
        primary_conf = 0.92
    elif rhythm == "pace_aai":
        primary_dx = "ЭКС: предсердная стимуляция (AAI)"
        primary_conf = 0.92
    elif rhythm == "pace_ddd":
        primary_dx = "ЭКС: двухкамерная стимуляция (DDD)"
        primary_conf = 0.92
    elif ed["dx"] != "":
        primary_dx = ed["dx"]
        primary_conf = ed["conf"]
    else:
        primary_dx = res["dx"]
        primary_conf = res["conf"]

    var findings: Array = []
    if rhythm == "sinus":
        if sok["lvh"]: findings.append("ГЛЖ (Соколов-Лайон)")
        if sok["rvh"]: findings.append("ГПЖ")
        if axis_lbl != "норма": findings.append(axis_lbl)
        if float(es["mg"]) < 0.6 and float(res["qtc"]) > 480.0: findings.append("риск Torsades")
    var ftext := ""
    for n in range(findings.size()):
        ftext += findings[n]
        if n < findings.size() - 1: ftext += ", "

    var head := primary_dx
    if rhythm == "sinus" and primary_dx == "Норма (синусовый ритм)" and not findings.is_empty():
        head = ftext
    var abnormal: bool = rhythm != "sinus" or ed["dx"] != "" or res["dx"] != "Норма (синусовый ритм)" or not findings.is_empty()
    dx_label.text = "%s — %d%%" % [head, roundi(primary_conf * 100.0)]
    dx_label.add_theme_color_override("font_color",
        Color.ORANGE_RED if abnormal else Color(0.3, 1.0, 0.45))

    var wb := ECGModel.wellbeing(eff, es)
    wb_label.text = "Самочувствие: " + str(wb["text"])
    var sev: int = wb["sev"]
    var wbcol := Color(0.3, 1.0, 0.45)
    if sev == 1: wbcol = Color(0.95, 0.85, 0.2)
    elif sev == 2: wbcol = Color(1.0, 0.55, 0.1)
    elif sev == 3: wbcol = Color(1.0, 0.3, 0.2)
    wb_label.add_theme_color_override("font_color", wbcol)

    report_label.text = ECGModel.ecg_report(eff, sok, axis_lbl, res)

    var diff := ECGModel.pathology_probabilities(eff, es)
    var abn := ECGModel.abnormality_prob(diff)
    prob_label.text = "Вероятность патологии: %d%%" % roundi(abn * 100.0)
    var pcol := Color(0.3, 1.0, 0.45)
    if abn >= 0.75: pcol = Color(1.0, 0.3, 0.2)
    elif abn >= 0.45: pcol = Color(1.0, 0.55, 0.1)
    elif abn >= 0.2: pcol = Color(0.95, 0.85, 0.2)
    prob_label.add_theme_color_override("font_color", pcol)

    var dtext := ""
    if diff.is_empty():
        dtext = "Существенной патологии не выявлено (≈" + str(roundi((1.0 - abn) * 100.0)) + "% норма)."
    else:
        var shown := mini(diff.size(), 5)
        for n in range(shown):
            dtext += "• %s — %d%%\n" % [str(diff[n]["name"]), roundi(float(diff[n]["prob"]) * 100.0)]
    diff_label.text = dtext

    if drug_summary:
        var names: Array = []
        for i in DRUGS.size():
            if active_drugs[i] >= 1:
                names.append(str(DRUGS[i]["name"]) + " (" + DOSE_NAMES[active_drugs[i]] + ")")
        if names.is_empty():
            drug_summary.text = "Препараты не выбраны."
        else:
            drug_summary.text = "Активно: " + ", ".join(PackedStringArray(names))

    analysis_label.text = _build_analysis(es, res, sok, axis, axis_lbl, net_i, net_avf)
    _sync_selectors()
    _refresh_views()

func _build_analysis(es: Dictionary, res: Dictionary, sok: Dictionary, axis: float, axis_lbl: String, net_i: float, net_avf: float) -> String:
    var si := "+" if net_i >= 0.0 else "-"
    var sa := "+" if net_avf >= 0.0 else "-"
    var t := ""
    t += "Состояние: K %.1f  Ca %.2f  Mg %.2f  Na %d ммоль/л  ·  АД %d/%d\n\n" % [
        float(es["k"]), float(es["ca"]), float(es["mg"]),
        roundi(state["na"]), roundi(state["bp_sys"]), roundi(state["bp_dia"])]
    t += "Электрическая ось QRS: %d° — %s\n" % [roundi(axis), axis_lbl]
    t += "Метод I/aVF:  I %s,  aVF %s\n\n" % [si, sa]
    t += "Соколов-Лайон (ГЛЖ):\n"
    t += "  SV1 %.1f + R(V5/V6) %.1f = %.1f мм  (порог 35) → %s\n" % [
        sok["sv1"], maxf(sok["rv5"], sok["rv6"]), sok["lvh_prec_idx"],
        "ДА" if sok["lvh_by_prec"] else "нет"]
    t += "  Лимб: R aVL %.1f (>=11)  |  R I + S III %.1f (>=25) → %s\n\n" % [
        sok["r_avl"], sok["r_i"] + sok["s_iii"], "ДА" if sok["lvh_by_limb"] else "нет"]
    t += "ГПЖ: RV1 %.1f + S(V5/V6) %.1f = %.1f мм  (>=11) → %s\n\n" % [
        sok["rv1"], maxf(sok["sv5"], sok["sv6"]), sok["rvh_idx"],
        "ДА" if sok["rvh"] else "нет"]
    t += "QTc (Базетт): %d мс  (норма < 460)" % roundi(res["qtc"])
    return t
