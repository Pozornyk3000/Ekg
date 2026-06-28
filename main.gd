extends Control

const LEADS := ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]

const DEFAULTS := {
    "hr": 75.0, "p_amp": 1.5, "p_dur": 90.0, "pr": 160.0,
    "q_amp": 1.0, "r_amp": 12.0, "s_amp": 4.0, "qrs_dur": 90.0,
    "st_x": 0.0, "st_y": 0.0, "st_z": 0.0, "qt": 380.0, "t_amp": 4.0,
    "qrs_axis": 60.0, "t_axis": 45.0, "rhythm": "sinus", "bbb": "none", "vt_focus": "lv_lat_mid",
    "pace_fault": "none", "pvc_rate": 0.0, "pvc_focus": "lv_lat_mid",
    "resp_arr": 0.06, "baseline_wander": 0.0, "mains_noise": 0.0, "cpr": 0.0,
    "st_shape": 0.0, "p_morph": "normal",
    "delta_amp": 0.0, "j_wave": 0.0, "t_post": 0.0, "pr_dep": 0.0, "strain": 0.0, "rv_boost": 0.0,
    "hemiblock": "none",
}
const STATE_DEFAULTS := {
    "k": 4.0, "ca": 2.4, "mg": 0.85, "na": 140.0,
    "bp_sys": 120.0, "bp_dia": 80.0,
}
const RHYTHM_NAMES := ["Синусовый", "Фибрилляция предсердий", "Трепетание предсердий (волны F)", "АВУРТ (узловая тахикардия)", "Узловой (АВ-узловой) ритм", "Ускоренный идиовентрикулярный (AIVR)", "Желудочковая тахикардия", "Фибрилляция желудочков (крупноволновая)", "ФЖ мелковолновая", "Тахикардия пируэт (Torsades)", "Двунаправленная ЖТ (дигоксин)", "ЭМД / PEA (без пульса)", "СССУ / синусовые паузы", "AV-блокада 2 ст. Мобитц I (Венкебах)", "AV-блокада 2 ст. Мобитц II", "Полная AV-блокада", "Асистолия", "ЭКС желудочковый (VVI)", "ЭКС предсердный (AAI)", "ЭКС двухкамерный (DDD)", "ЭКС бивентрикулярный (BiV/CRT)"]
const RHYTHM_VALUES := ["sinus", "afib", "aflutter", "avnrt", "junctional", "aivr", "vtach", "vfib", "vfib_fine", "torsades", "bidirectional", "pea", "sss", "wenckebach", "mobitz2", "av3", "asystole", "pace_vvi", "pace_aai", "pace_ddd", "pace_biv"]
# Группировка ритмов в выпадающем списке (подсписки с заголовками).
const RHYTHM_GROUPS := [
    ["Наджелудочковые", ["sinus", "afib", "aflutter", "avnrt"]],
    ["Желудочковые", ["vtach", "torsades", "bidirectional", "aivr"]],
    ["Остановка кровообращения", ["vfib", "vfib_fine", "pea", "asystole"]],
    ["Блокады, паузы, эскейп", ["wenckebach", "mobitz2", "av3", "sss", "junctional"]],
    ["Кардиостимулятор", ["pace_vvi", "pace_aai", "pace_ddd", "pace_biv"]],
]
const PACE_FAULT_NAMES := ["ЭКС: норма", "Потеря захвата", "Undersensing (асинхронно)"]
const PACE_FAULT_VALUES := ["none", "loss_capture", "undersense"]
const PVC_NAMES := ["Нет", "Редкие", "Частые"]
const PVC_RATES := [0.0, 8.0, 22.0]
const BBB_NAMES := ["Без блокады ножки", "Блокада ЛНПГ", "Блокада ПНПГ"]
const BBB_VALUES := ["none", "lbbb", "rbbb"]
const FOCUS_NAMES := ["ЛЖ боковая", "ЛЖ верхушка", "Перегородка", "ПЖ свободная стенка", "Выносящий тракт ПЖ"]
const FOCUS_VALUES := ["lv_lat_mid", "lv_lat_ap", "sep_mid", "rv_mid", "rv_out"]

# Препараты: d/sd — терапевтическая доза; td/tsd — ДОБАВКА при токсической; trhythm — аритмия при токсичности.
const DRUGS := [
    {"name": "Дигоксин", "d": {"qt": -35.0, "pr": 25.0, "hr": -10.0, "t_amp": -1.5, "st_x": -0.5, "st_y": -0.3, "st_shape": -1.0}, "sd": {}, "td": {"pr": 45.0, "hr": -18.0}, "tsd": {}, "trhythm": "bidirectional", "desc": "тер: ↓QT, ↑PR, корытообразная ST. токс: двунаправленная ЖТ, AV-блокада"},
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
    {"name": "Аденозин", "d": {}, "sd": {}, "td": {}, "tsd": {}, "trhythm": "", "desc": "купирует АВУРТ (кратковременная AV-блокада); демаскирует трепетание"},
    {"name": "Магния сульфат", "d": {}, "sd": {"mg": 0.6}, "td": {}, "tsd": {}, "trhythm": "", "desc": "купирует Torsades; ↑Mg"},
]
# Конверсия ритма в синус терапевтической дозой (купирование аритмии).
const DRUG_CONV := {
    "Амиодарон (III)": ["vtach", "afib", "aflutter", "avnrt"],
    "Соталол (III)": ["afib", "aflutter", "vtach"],
    "Флекаинид (IC)": ["afib", "aflutter"],
    "Хинидин (IA)": ["afib"],
    "Лидокаин (IB)": ["vtach"],
    "Бета-блокатор": ["avnrt"],
    "Верапамил/Дилтиазем": ["avnrt"],
    "Аденозин": ["avnrt"],
    "Магния сульфат": ["torsades"],
    "Адреналин": ["asystole", "pea"],
    "Атропин": ["sss", "av3", "wenckebach"],
}
# Группировка препаратов по классам (для вкладки «Препараты»).
const DRUG_GROUPS := [
    ["Класс I — блокаторы Na", ["Хинидин (IA)", "Флекаинид (IC)", "Лидокаин (IB)"]],
    ["Класс II — β-блокаторы", ["Бета-блокатор"]],
    ["Класс III — блокаторы K", ["Амиодарон (III)", "Соталол (III)"]],
    ["Класс IV — блокаторы Ca", ["Верапамил/Дилтиазем"]],
    ["Неотложные / прочие", ["Дигоксин", "Аденозин", "Атропин", "Адреналин", "Магния сульфат"]],
    ["Влияющие на электролиты / токсины", ["Спиронолактон", "Фуросемид", "Амитриптилин (ТЦА)"]],
]
const DOSE_NAMES := ["Выкл", "Терапевт.", "Токсич."]
const QUIZ_DIFF_NAMES := ["Все уровни", "Новичок", "Эксперт"]
const QUIZ_CAT_NAMES := ["Все системы", "Аритмии / ЭКС", "Инфаркт / ишемия", "Блокады проводимости", "Гипертрофия / прочее"]
const QUIZ_CAT_KEYS := ["", "arr", "mi", "block", "other"]
# Тонкие («экспертные») паттерны — по ключевым словам в названии пресета.
const QUIZ_HARD_KEYS := ["mitrale", "pulmonale", "реполяриз", "Wellens", "Бругада", "задний", "Гемиблок", "Мобитц", "Венкебах", "атлет", "Детское", "Трифасцикул", "Бифасцикул", "перегрузк", "undersensing", "захвата", "СССУ", "АВУРТ", "Двунаправ"]

const STRESS_STAGES := ["Покой", "Ступень 1", "Ступень 2", "Ступень 3", "Ступень 4", "Пик нагрузки", "Восстановление 1 мин", "Восстановление 3 мин"]
const STENOSIS_NAMES := ["Нет стеноза", "Умеренный стеноз", "Выраженный стеноз"]

const PRESETS := [
    {"name": "Норма", "p": {}, "s": {}},
    {"name": "Инфаркт нижний (STEMI)", "p": {"st_y": 3.0, "q_amp": 3.0, "st_shape": 1.0}, "s": {}},
    {"name": "Инфаркт передний (STEMI)", "p": {"st_z": -3.0, "q_amp": 3.5, "st_shape": 1.0}, "s": {}},
    {"name": "ГЛЖ (гипертрофия ЛЖ)", "p": {"r_amp": 28.0, "s_amp": 14.0, "qrs_axis": -20.0}, "s": {"bp_sys": 185.0}},
    {"name": "ГЛЖ с перегрузкой (strain)", "p": {"r_amp": 32.0, "s_amp": 18.0, "qrs_axis": -15.0, "strain": 4.5}, "s": {"bp_sys": 195.0}},
    {"name": "ГПЖ с перегрузкой (strain)", "p": {"r_amp": 9.0, "s_amp": 14.0, "qrs_axis": 120.0, "strain": 3.5, "rv_boost": 3.2}, "s": {}},
    {"name": "Инфаркт задний (зеркало V1-V2)", "p": {"st_z": 2.6, "q_amp": 3.2}, "s": {}},
    {"name": "Гемиблок передней ветви (ЛПВ/LAFB)", "p": {"hemiblock": "lafb", "qrs_axis": -60.0, "qrs_dur": 100.0}, "s": {}},
    {"name": "Гемиблок задней ветви (ЛЗВ/LPFB)", "p": {"hemiblock": "lpfb", "qrs_axis": 120.0, "qrs_dur": 100.0}, "s": {}},
    {"name": "Бифасцикулярная блокада (ПНПГ + ЛПВ)", "p": {"bbb": "rbbb", "hemiblock": "lafb", "qrs_axis": -35.0, "qrs_dur": 140.0}, "s": {}},
    {"name": "Блокада ЛНПГ", "p": {"bbb": "lbbb", "qrs_dur": 150.0, "qrs_axis": -30.0}, "s": {}},
    {"name": "Блокада ПНПГ", "p": {"bbb": "rbbb", "qrs_dur": 140.0}, "s": {}},
    {"name": "AV-блокада 1 ст.", "p": {"pr": 280.0}, "s": {}},
    {"name": "Полная AV-блокада", "p": {"rhythm": "av3"}, "s": {}},
    {"name": "Брадикардия", "p": {"hr": 45.0}, "s": {}},
    {"name": "Синусовая тахикардия", "p": {"hr": 130.0}, "s": {}},
    {"name": "Желудочковая тахикардия", "p": {"rhythm": "vtach", "hr": 180.0}, "s": {}},
    {"name": "Двунаправленная ЖТ (дигоксин)", "p": {"rhythm": "bidirectional", "hr": 150.0, "p_amp": 0.0, "qrs_dur": 130.0}, "s": {}},
    {"name": "Фибрилляция желудочков", "p": {"rhythm": "vfib", "hr": 60.0, "p_amp": 0.0}, "s": {"bp_sys": 0.0, "bp_dia": 0.0}},
    {"name": "ФЖ мелковолновая", "p": {"rhythm": "vfib_fine", "hr": 60.0, "p_amp": 0.0}, "s": {"bp_sys": 0.0, "bp_dia": 0.0}},
    {"name": "ЭМД / PEA (без пульса)", "p": {"rhythm": "pea", "hr": 30.0, "p_amp": 0.0, "qrs_dur": 150.0}, "s": {"bp_sys": 0.0, "bp_dia": 0.0}},
    {"name": "Асистолия (изолиния)", "p": {"rhythm": "asystole", "hr": 50.0, "p_amp": 0.0}, "s": {"bp_sys": 0.0, "bp_dia": 0.0}},
    {"name": "АВУРТ (узловая тахикардия)", "p": {"rhythm": "avnrt", "hr": 180.0, "p_amp": 0.0}, "s": {}},
    {"name": "СССУ / синусовые паузы", "p": {"rhythm": "sss", "hr": 60.0}, "s": {}},
    {"name": "Трифасцикулярная блокада", "p": {"bbb": "rbbb", "hemiblock": "lafb", "qrs_axis": -35.0, "qrs_dur": 140.0, "pr": 240.0}, "s": {}},
    {"name": "Тахикардия пируэт (Torsades)", "p": {"rhythm": "torsades", "hr": 240.0, "qt": 520.0, "p_amp": 0.0}, "s": {"mg": 0.4}},
    {"name": "Кардиостимулятор (VVI)", "p": {"rhythm": "pace_vvi", "hr": 70.0, "p_amp": 0.0}, "s": {}},
    {"name": "Детское сердце", "p": {"rhythm": "sinus", "bbb": "none", "hr": 130.0, "pr": 110.0, "qt": 300.0, "qrs_axis": 100.0, "qrs_dur": 70.0, "r_amp": 10.0}, "s": {}},
    {"name": "Сердце атлета", "p": {"rhythm": "sinus", "bbb": "none", "hr": 48.0, "pr": 205.0, "r_amp": 17.0, "s_amp": 8.0, "qrs_axis": 65.0}, "s": {"bp_sys": 118.0}},
    {"name": "Фибрилляция предсердий", "p": {"rhythm": "afib", "hr": 110.0, "p_amp": 0.0}, "s": {}},
    {"name": "Трепетание предсердий 2:1", "p": {"rhythm": "aflutter", "hr": 150.0, "p_amp": 0.0}, "s": {}},
    {"name": "Трепетание предсердий 4:1", "p": {"rhythm": "aflutter", "hr": 75.0, "p_amp": 0.0}, "s": {}},
    {"name": "Гиперкалиемия", "p": {}, "s": {"k": 7.0}},
    {"name": "Гипокалиемия", "p": {}, "s": {"k": 2.5}},
    {"name": "Гипокальциемия (long QT)", "p": {}, "s": {"ca": 1.7}},
    {"name": "P-mitrale (ГЛП, двугорбый P)", "p": {"p_morph": "mitrale", "p_dur": 145.0, "p_amp": 2.0}, "s": {}},
    {"name": "P-pulmonale (ГПП, высокий P)", "p": {"p_morph": "pulmonale", "p_amp": 2.8}, "s": {}},
    {"name": "Желудочковые экстрасистолы (ЖЭ)", "p": {"rhythm": "sinus", "pvc_rate": 14.0}, "s": {}},
    {"name": "ЭКС бивентрикулярный (CRT)", "p": {"rhythm": "pace_biv", "hr": 70.0, "qrs_axis": -120.0, "p_amp": 1.0}, "s": {}},
    {"name": "ЭКС: потеря захвата", "p": {"rhythm": "pace_vvi", "hr": 70.0, "pace_fault": "loss_capture", "p_amp": 0.0}, "s": {}},
    {"name": "ЭКС: undersensing", "p": {"rhythm": "pace_vvi", "hr": 75.0, "pace_fault": "undersense", "p_amp": 0.0}, "s": {}},
    {"name": "WPW (дельта-волна)", "p": {"pr": 90.0, "delta_amp": 0.38, "qrs_dur": 110.0}, "s": {}},
    {"name": "Wellens (крит. стеноз ПМЖВ)", "p": {"t_post": 7.5}, "s": {}},
    {"name": "Ранняя реполяризация", "p": {"j_wave": 1.6, "st_y": 1.3, "st_shape": -0.4}, "s": {}},
    {"name": "Перикардит (диффузный)", "p": {"st_x": 0.6, "st_y": 1.8, "st_z": -0.4, "st_shape": -0.4, "pr_dep": 0.55}, "s": {}},
    {"name": "Синдром Бругада (тип 1)", "p": {"st_x": -0.8, "st_z": -2.4, "st_shape": 1.0, "t_post": 4.5}, "s": {}},
    {"name": "Узловой (АВ-узловой) ритм", "p": {"rhythm": "junctional", "hr": 50.0, "p_amp": 0.0}, "s": {}},
    {"name": "Ускоренный идиовентрикулярный ритм (AIVR)", "p": {"rhythm": "aivr", "hr": 80.0, "qrs_dur": 130.0, "p_amp": 1.0}, "s": {}},
    {"name": "ТЭЛА (перегрузка ПЖ: тахи, RAD, T V1-V3)", "p": {"hr": 110.0, "qrs_axis": 100.0, "t_post": 4.0, "strain": 2.5}, "s": {}},
    {"name": "Гипотермия (волны Осборна)", "p": {"j_wave": 2.8, "hr": 45.0, "qt": 440.0}, "s": {}},
    {"name": "Гиперкальциемия (короткий QT)", "p": {}, "s": {"ca": 3.2}},
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
var pace_fault_opt: OptionButton
var pvc_opt: OptionButton
var export_btn: Button
var monitor_speed_btn: Button
var bg_rect: ColorRect
var theme_btn: Button
var theme_name := "blue"
var section_bars: Array = []
var event_label: Label
var expl_label: Label
var _conv_shown_for := ""

const PALETTES := {
    "blue": {"name": "Синяя", "bg": "#070e1c", "panel": "#0e1830", "panel2": "#152444", "hover": "#1e3461", "accent": "#4d9fff", "accent_d": "#2a4f8f", "border": "#21345e", "text": "#dce6f7", "dim": "#8497bd", "darktxt": "#06112a", "trace": "#73d2ff", "mon_bg": "#03060f", "grid": "#2a4f8f"},
    "green": {"name": "Зелёная", "bg": "#07140e", "panel": "#0e2018", "panel2": "#143226", "hover": "#1d4a38", "accent": "#2fe089", "accent_d": "#246b4c", "border": "#1f4534", "text": "#dceee7", "dim": "#84a89c", "darktxt": "#05140d", "trace": "#5dffa0", "mon_bg": "#04100a", "grid": "#246b4c"},
    "light": {"name": "Светлая", "bg": "#e9eef6", "panel": "#ffffff", "panel2": "#eef3fb", "hover": "#dbe6f7", "accent": "#2f6df0", "accent_d": "#9fbcf0", "border": "#cdd9ee", "text": "#16233e", "dim": "#5d6e8e", "darktxt": "#ffffff", "trace": "#4db0ff", "mon_bg": "#081326", "grid": "#2a4f8f"},
}
const THEME_ORDER := ["blue", "green", "light"]
const SHOCKABLE := ["vtach", "vfib", "vfib_fine", "torsades", "bidirectional", "afib", "aflutter", "avnrt"]
const CRITICAL := ["vfib", "vfib_fine", "vtach", "torsades", "bidirectional", "asystole", "pea"]
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
var quiz_lead_views: Array = []
var quiz_monitor: MonitorView
var quiz_answer_btns: Array = []
var quiz_options: Array = []
var quiz_answer_idx := -1
var quiz_answered := false
var quiz_correct := 0
var quiz_total := 0
var quiz_explain_text := ""
var quiz_feedback: Label
var quiz_explain: Label
var quiz_score_label: Label
var quiz_next_btn: Button
var quiz_diff_opt: OptionButton
var quiz_cat_opt: OptionButton
var quiz_diff_idx := 0
var quiz_cat_idx := 0
var exam_btn: Button
var exam_active := false
var exam_q := 0
var exam_score := 0
var exam_misses: Array = []
var exam_best := 0
const EXAM_TOTAL := 10

const SETTINGS_PATH := "user://settings.cfg"

func _load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) != OK:
        return
    var saved := str(cfg.get_value("ui", "theme", theme_name))
    if PALETTES.has(saved):
        theme_name = saved
    quiz_correct = int(cfg.get_value("quiz", "correct", 0))
    quiz_total = int(cfg.get_value("quiz", "total", 0))
    exam_best = int(cfg.get_value("quiz", "best_exam", 0))

func _save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)  # сохранить прочие ключи, если есть
    cfg.set_value("ui", "theme", theme_name)
    cfg.set_value("quiz", "correct", quiz_correct)
    cfg.set_value("quiz", "total", quiz_total)
    cfg.set_value("quiz", "best_exam", exam_best)
    cfg.save(SETTINGS_PATH)

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _load_settings()
    theme = _build_theme(_pal(theme_name))
    bg_rect = ColorRect.new()
    bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_rect.color = Color(PALETTES[theme_name]["bg"])
    bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg_rect)
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

    event_label = Label.new()
    event_label.add_theme_font_size_override("font_size", 15)
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
    vb.add_child(event_label)

    report_label = Label.new()
    report_label.add_theme_font_size_override("font_size", 13)
    report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    report_label.modulate = Color(0.82, 0.87, 0.92)
    vb.add_child(report_label)

    prob_label = Label.new()
    prob_label.add_theme_font_size_override("font_size", 14)
    prob_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vb.add_child(prob_label)

    # Строчка-подсказка: как отличить паттерн на ЭКГ и почему он так выглядит.
    expl_label = Label.new()
    expl_label.add_theme_font_size_override("font_size", 13)
    expl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    expl_label.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0))
    vb.add_child(expl_label)

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
    _build_quiz_tab(tabs)

    _enable_touch_scroll(tabs)

    _built = true
    _recompute()
    _quiz_new()
    _apply_theme(theme_name)

# Плавная прокрутка пальцем на мобильном: ScrollContainer перехватывает протяжку,
# но дочерние контролы со STOP «съедают» жест. Делаем неинтерактивные элементы
# (надписи, контейнеры, полоски, монитор, миниатюры) прозрачными для жеста (PASS):
# нажатие они получают, а если не приняли — протяжка всплывает к ScrollContainer.
func _enable_touch_scroll(node: Node) -> void:
    for c in node.get_children():
        if c is ScrollContainer:
            var s := c as ScrollContainer
            s.size_flags_vertical = Control.SIZE_EXPAND_FILL
            s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        elif c is OptionButton:
            # Длинные списки (пресеты/ритмы) не должны вылезать за экран — ограничиваем
            # высоту всплывающего меню, тогда оно прокручивается протяжкой пальца.
            var pm := (c as OptionButton).get_popup()
            pm.max_size = Vector2i(0, _popup_max_h())
        elif c is Label or c is ColorRect or c is HSeparator or c is VSeparator \
                or c is BoxContainer or c is GridContainer or c is MarginContainer \
                or c is PanelContainer or c is MonitorView or c is LeadView \
                or c is AxisView or c is StressView:
            (c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
        if c.get_child_count() > 0:
            _enable_touch_scroll(c)

func _popup_max_h() -> int:
    var vh := DisplayServer.window_get_size().y
    if vh <= 0:
        vh = 900
    return int(vh * 0.6)

# ---------- оформление (тёмно-синяя тема) ----------
func _sbflat(bg: Color, radius: int, bw: int = 0, bc: Color = Color(0, 0, 0, 0), pad: int = 12) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.set_corner_radius_all(radius)
    if bw > 0:
        sb.set_border_width_all(bw)
        sb.border_color = bc
    sb.content_margin_left = pad
    sb.content_margin_right = pad
    sb.content_margin_top = maxi(int(pad * 0.6), 6)
    sb.content_margin_bottom = maxi(int(pad * 0.6), 6)
    return sb

func _pal(pname: String) -> Dictionary:
    var raw: Dictionary = PALETTES[pname]
    var P := {}
    for k in raw:
        var val = raw[k]
        P[k] = Color(val) if (val is String and val.begins_with("#")) else val
    return P

func _apply_theme(pname: String) -> void:
    theme_name = pname
    var P := _pal(pname)
    theme = _build_theme(P)
    if bg_rect: bg_rect.color = P["bg"]
    for mon in [monitor, quiz_monitor]:
        if mon:
            mon.bg_c = P["mon_bg"]
            mon.trace_color = P["trace"]
            mon.grid_c = P["grid"]
            mon.queue_redraw()
    for arr in [lead_views, quiz_lead_views]:
        for lv in arr:
            lv.bg_c = P["mon_bg"]
            lv.trace_color = P["trace"]
            lv.grid_c = P["grid"]
            lv.queue_redraw()
    for bar in section_bars:
        if is_instance_valid(bar): bar.color = P["accent"]
    if theme_btn:
        theme_btn.text = "Тема: " + str(PALETTES[pname]["name"])
    _save_settings()

func _cycle_theme() -> void:
    var i := THEME_ORDER.find(theme_name)
    _apply_theme(THEME_ORDER[(i + 1) % THEME_ORDER.size()])

func _build_theme(P: Dictionary) -> Theme:
    var PANEL: Color = P["panel"]
    var PANEL2: Color = P["panel2"]
    var HOVER: Color = P["hover"]
    var ACCENT: Color = P["accent"]
    var ACCENT_D: Color = P["accent_d"]
    var BORDER: Color = P["border"]
    var TEXT: Color = P["text"]
    var DIM: Color = P["dim"]
    var DARKTXT: Color = P["darktxt"]
    var t := Theme.new()
    t.default_font_size = 15

    t.set_color("font_color", "Label", TEXT)

    var bn := _sbflat(PANEL2, 10, 1, BORDER, 12)
    var bh := _sbflat(HOVER, 10, 1, ACCENT, 12)
    var bp := _sbflat(ACCENT, 10, 0, Color(0, 0, 0, 0), 12)
    var bf := _sbflat(Color(0, 0, 0, 0), 10, 1, ACCENT, 12)
    var bd := _sbflat(Color("#10182c"), 10, 1, Color("#1a2742"), 12)
    for ctl in ["Button", "OptionButton"]:
        t.set_stylebox("normal", ctl, bn)
        t.set_stylebox("hover", ctl, bh)
        t.set_stylebox("pressed", ctl, bp)
        t.set_stylebox("focus", ctl, bf)
        t.set_stylebox("disabled", ctl, bd)
        t.set_color("font_color", ctl, TEXT)
        t.set_color("font_hover_color", ctl, ACCENT)
        t.set_color("font_pressed_color", ctl, DARKTXT)
        t.set_color("font_disabled_color", ctl, DIM)
        t.set_color("font_focus_color", ctl, TEXT)

    t.set_stylebox("panel", "PopupMenu", _sbflat(PANEL, 8, 1, ACCENT_D, 8))
    t.set_stylebox("hover", "PopupMenu", _sbflat(HOVER, 6, 0, Color(0, 0, 0, 0), 6))
    t.set_color("font_color", "PopupMenu", TEXT)
    t.set_color("font_hover_color", "PopupMenu", ACCENT)

    t.set_stylebox("panel", "TabContainer", _sbflat(PANEL, 12, 1, BORDER, 12))
    t.set_stylebox("tabbar_background", "TabContainer", _sbflat(Color(0, 0, 0, 0), 0))
    t.set_stylebox("tab_selected", "TabContainer", _sbflat(ACCENT, 8, 0, Color(0, 0, 0, 0), 12))
    t.set_stylebox("tab_unselected", "TabContainer", _sbflat(PANEL2, 8, 0, Color(0, 0, 0, 0), 12))
    t.set_stylebox("tab_hovered", "TabContainer", _sbflat(HOVER, 8, 0, Color(0, 0, 0, 0), 12))
    t.set_color("font_selected_color", "TabContainer", DARKTXT)
    t.set_color("font_unselected_color", "TabContainer", DIM)
    t.set_color("font_hovered_color", "TabContainer", ACCENT)
    t.set_font_size("font_size", "TabContainer", 14)

    t.set_stylebox("slider", "HSlider", _sbflat(Color("#0c1626"), 6))
    t.set_stylebox("grabber_area", "HSlider", _sbflat(ACCENT_D, 6))
    t.set_stylebox("grabber_area_highlight", "HSlider", _sbflat(ACCENT, 6))

    t.set_color("font_color", "CheckBox", TEXT)
    t.set_color("font_hover_color", "CheckBox", ACCENT)

    t.set_stylebox("panel", "Panel", _sbflat(PANEL, 12, 1, BORDER, 10))
    t.set_stylebox("separator", "HSeparator", _sbflat(BORDER, 0, 0, Color(0, 0, 0, 0), 0))

    # Скроллбары
    var track := _sbflat(P["bg"], 6, 0, Color(0, 0, 0, 0), 0)
    var grab := _sbflat(ACCENT_D, 6, 0, Color(0, 0, 0, 0), 0)
    var grab_h := _sbflat(ACCENT, 6, 0, Color(0, 0, 0, 0), 0)
    for sbn in ["VScrollBar", "HScrollBar"]:
        t.set_stylebox("scroll", sbn, track)
        t.set_stylebox("grabber", sbn, grab)
        t.set_stylebox("grabber_highlight", sbn, grab_h)
        t.set_stylebox("grabber_pressed", sbn, grab_h)

    # CheckBox / CheckButton — фон-«пилюля» (галочки-иконки остаются дефолтными)
    t.set_color("font_color", "CheckButton", TEXT)
    t.set_color("font_hover_color", "CheckButton", ACCENT)
    t.set_stylebox("normal", "CheckBox", _sbflat(Color(0, 0, 0, 0), 8, 0, Color(0, 0, 0, 0), 6))
    t.set_stylebox("hover", "CheckBox", _sbflat(HOVER, 8, 0, Color(0, 0, 0, 0), 6))
    t.set_stylebox("pressed", "CheckBox", _sbflat(HOVER, 8, 0, Color(0, 0, 0, 0), 6))
    return t

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
    # Группировка по категориям: заголовок-разделитель + пункты; id = индекс в PRESETS.
    var pgroups := [
        ["norm", "Норма и варианты"], ["arr", "Аритмии"], ["block", "Блокады и гипертрофия"],
        ["mi", "Инфаркт / ишемия"], ["synd", "Электролиты и синдромы"], ["pace", "Кардиостимулятор"],
    ]
    for g in pgroups:
        var added := false
        for pi in PRESETS.size():
            if _preset_group(PRESETS[pi]) != g[0]: continue
            if not added:
                preset_opt.add_separator(str(g[1]))
                added = true
            var it := preset_opt.item_count
            preset_opt.add_item(str(PRESETS[pi]["name"]))
            preset_opt.set_item_id(it, pi)
    preset_opt.item_selected.connect(_apply_preset)
    col.add_child(preset_opt)

    _mk_label(col, "Ритм:", 14)
    rhythm_opt = OptionButton.new()
    rhythm_opt.custom_minimum_size = Vector2(0, 42)
    # Сгруппированный список: заголовок-разделитель + пункты; id пункта = индекс в RHYTHM_VALUES.
    for grp in RHYTHM_GROUPS:
        rhythm_opt.add_separator(str(grp[0]))
        for val in grp[1]:
            var vi: int = RHYTHM_VALUES.find(val)
            var item := rhythm_opt.item_count
            rhythm_opt.add_item(RHYTHM_NAMES[vi])
            rhythm_opt.set_item_id(item, vi)
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

    _mk_label(col, "Неисправность ЭКС (для режимов стимуляции):", 14)
    pace_fault_opt = OptionButton.new()
    pace_fault_opt.custom_minimum_size = Vector2(0, 42)
    for n in PACE_FAULT_NAMES:
        pace_fault_opt.add_item(n)
    pace_fault_opt.item_selected.connect(_on_pace_fault)
    col.add_child(pace_fault_opt)

    _mk_label(col, "Желудочковые экстрасистолы (ЖЭ):", 14)
    pvc_opt = OptionButton.new()
    pvc_opt.custom_minimum_size = Vector2(0, 42)
    for n in PVC_NAMES:
        pvc_opt.add_item(n)
    pvc_opt.item_selected.connect(_on_pvc)
    col.add_child(pvc_opt)

    _mk_label(col, "Реализм сигнала (живой монитор):", 14)
    _add_artifact_check(col, "Дыхательная аритмия (вариабельность RR)", "resp_arr", 0.06, true)
    _add_artifact_check(col, "Дрейф изолинии", "baseline_wander", 0.8, false)
    _add_artifact_check(col, "Сетевая наводка 50 Гц", "mains_noise", 0.15, false)

    export_btn = Button.new()
    export_btn.text = "💾 Экспорт 12 отведений в PNG"
    export_btn.custom_minimum_size = Vector2(0, 42)
    export_btn.pressed.connect(_export_png)
    col.add_child(export_btn)

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
    monitor.custom_minimum_size = Vector2(0, 185)
    monitor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    monitor.clip_contents = true
    col.add_child(monitor)

    var ctlrow := HBoxContainer.new()
    ctlrow.add_theme_constant_override("separation", 8)
    ctlrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_child(ctlrow)
    monitor_speed_btn = Button.new()
    monitor_speed_btn.text = "Скорость: 25 мм/с"
    monitor_speed_btn.custom_minimum_size = Vector2(0, 38)
    monitor_speed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    monitor_speed_btn.pressed.connect(_toggle_monitor_speed)
    ctlrow.add_child(monitor_speed_btn)
    theme_btn = Button.new()
    theme_btn.text = "Тема: Синяя"
    theme_btn.custom_minimum_size = Vector2(0, 38)
    theme_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    theme_btn.pressed.connect(_cycle_theme)
    ctlrow.add_child(theme_btn)

    var defib_btn := Button.new()
    defib_btn.text = "⚡ Разряд (дефибрилляция / кардиоверсия)"
    defib_btn.custom_minimum_size = Vector2(0, 42)
    defib_btn.pressed.connect(_defib)
    col.add_child(defib_btn)
    _add_artifact_check(col, "СЛР — компрессии грудной клетки (~110/мин)", "cpr", 7.0, false)

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

func _drug_index(dname: String) -> int:
    for i in DRUGS.size():
        if str(DRUGS[i]["name"]) == dname:
            return i
    return -1

func _add_drug_row(col: Node, i: int) -> void:
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
    drug_opts[i] = ob
    col.add_child(row)
    var dl := Label.new()
    dl.text = "    " + str(dr["desc"])
    dl.add_theme_font_size_override("font_size", 12)
    dl.modulate = Color(0.65, 0.72, 0.8)
    dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(dl)

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
    drug_opts.resize(DRUGS.size())
    for grp in DRUG_GROUPS:
        _mk_label(col, str(grp[0]), 12)
        for nm in grp[1]:
            var i := _drug_index(str(nm))
            if i >= 0:
                _add_drug_row(col, i)

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
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 7)
    hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var bar := ColorRect.new()
    bar.custom_minimum_size = Vector2(3, fs + 4)
    bar.color = Color(PALETTES[theme_name]["accent"])
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    section_bars.append(bar)
    hb.add_child(bar)
    var l := Label.new()
    l.add_theme_font_size_override("font_size", fs)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.text = text
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(l)
    parent.add_child(hb)

func _add_artifact_check(parent: Node, title: String, key: String, on_value: float, default_on: bool) -> void:
    var cb := CheckBox.new()
    cb.text = title
    cb.add_theme_font_size_override("font_size", 14)
    cb.custom_minimum_size = Vector2(0, 40)
    cb.button_pressed = default_on
    params[key] = on_value if default_on else 0.0
    cb.toggled.connect(func(on: bool):
        params[key] = on_value if on else 0.0
        _recompute())
    parent.add_child(cb)

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

func _preset_group(pr: Dictionary) -> String:
    var n := str(pr["name"])
    var p: Dictionary = pr["p"]
    var rh := str(p.get("rhythm", "sinus"))
    if "нфаркт" in n or "Wellens" in n or "ругада" in n or "ерикардит" in n or "шемия" in n or "ТЭЛА" in n or "STEMI" in n:
        return "mi"
    if rh.begins_with("pace") or "ЭКС" in n or "CRT" in n:
        return "pace"
    if "калиемия" in n or "кальциемия" in n or "WPW" in n or "P-" in n or "еполяриз" in n or "потермия" in n or "Осборн" in n:
        return "synd"
    if rh != "sinus" or "ахикардия" in n or "радикардия" in n or "СССУ" in n or "Асистол" in n or "ЭМД" in n or "ФЖ" in n:
        return "arr"
    if str(p.get("bbb", "none")) != "none" or str(p.get("hemiblock", "none")) != "none" or "локада" in n or "емиблок" in n or "фасцикул" in n or "ГЛЖ" in n or "ГПЖ" in n:
        return "block"
    return "norm"

func _apply_preset(idx: int) -> void:
    var pid := preset_opt.get_item_id(idx)  # id = индекс в PRESETS (списки сгруппированы)
    if pid < 0 or pid >= PRESETS.size():
        return
    var preset: Dictionary = PRESETS[pid]
    _suspend = true
    for key in DEFAULTS: _set_value(key, DEFAULTS[key], true)
    for key in STATE_DEFAULTS: _set_value(key, STATE_DEFAULTS[key], false)
    for key in preset["p"]: _set_value(key, preset["p"][key], true)
    for key in preset["s"]: _set_value(key, preset["s"][key], false)
    _suspend = false
    _recompute()

# ---------- Викторина «угадай диагноз» ----------
func _build_quiz_tab(tabs: TabContainer) -> void:
    var sc := ScrollContainer.new()
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    tabs.set_tab_title(5, "Викторина")
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 8)
    sc.add_child(col)

    quiz_score_label = Label.new()
    quiz_score_label.add_theme_font_size_override("font_size", 16)
    col.add_child(quiz_score_label)

    _mk_label(col, "Уровень:", 13)
    quiz_diff_opt = OptionButton.new()
    quiz_diff_opt.custom_minimum_size = Vector2(0, 40)
    for nm in QUIZ_DIFF_NAMES: quiz_diff_opt.add_item(nm)
    quiz_diff_opt.item_selected.connect(_on_quiz_diff)
    col.add_child(quiz_diff_opt)
    _mk_label(col, "Система:", 13)
    quiz_cat_opt = OptionButton.new()
    quiz_cat_opt.custom_minimum_size = Vector2(0, 40)
    for nm in QUIZ_CAT_NAMES: quiz_cat_opt.add_item(nm)
    quiz_cat_opt.item_selected.connect(_on_quiz_cat)
    col.add_child(quiz_cat_opt)

    _mk_label(col, "Ритм (бегущая лента, II):", 14)
    quiz_monitor = MonitorView.new()
    quiz_monitor.custom_minimum_size = Vector2(0, 130)
    quiz_monitor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quiz_monitor.clip_contents = true
    col.add_child(quiz_monitor)

    _mk_label(col, "Определите диагноз по ЭКГ:", 15)
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
        grid.add_child(lv)
        quiz_lead_views.append(lv)

    _mk_label(col, "Варианты ответа:", 14)
    for i in 4:
        var b := Button.new()
        b.custom_minimum_size = Vector2(0, 46)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        b.pressed.connect(_quiz_answer.bind(i))
        col.add_child(b)
        quiz_answer_btns.append(b)

    quiz_feedback = Label.new()
    quiz_feedback.add_theme_font_size_override("font_size", 16)
    quiz_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(quiz_feedback)

    quiz_explain = Label.new()
    quiz_explain.add_theme_font_size_override("font_size", 14)
    quiz_explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col.add_child(quiz_explain)

    quiz_next_btn = Button.new()
    quiz_next_btn.text = "▶ Новый вопрос"
    quiz_next_btn.custom_minimum_size = Vector2(0, 46)
    quiz_next_btn.pressed.connect(_quiz_next)
    col.add_child(quiz_next_btn)

    exam_btn = Button.new()
    exam_btn.text = "🎓 Экзамен (10 вопросов)"
    exam_btn.custom_minimum_size = Vector2(0, 46)
    exam_btn.pressed.connect(_exam_start)
    col.add_child(exam_btn)

func _on_quiz_diff(i: int) -> void:
    quiz_diff_idx = i
    exam_active = false
    _quiz_new()

func _on_quiz_cat(i: int) -> void:
    quiz_cat_idx = i
    exam_active = false
    _quiz_new()

func _exam_start() -> void:
    exam_active = true
    exam_q = 0
    exam_score = 0
    exam_misses = []
    _quiz_new()

func _quiz_next() -> void:
    if exam_active and exam_q >= EXAM_TOTAL and quiz_answered:
        _exam_finish()
    else:
        _quiz_new()

func _exam_finish() -> void:
    exam_active = false
    var pct := roundi(float(exam_score) / float(EXAM_TOTAL) * 100.0)
    var record := pct > exam_best
    if record: exam_best = pct
    var verdict := "нужна практика"
    if pct >= 90: verdict = "отлично"
    elif pct >= 70: verdict = "хорошо"
    elif pct >= 50: verdict = "удовлетворительно"
    quiz_feedback.text = "📊 Экзамен: %d / %d (%d%%) — %s%s" % [exam_score, EXAM_TOTAL, pct, verdict, "  🏆 рекорд!" if record else ""]
    quiz_feedback.add_theme_color_override("font_color",
        Color(0.3, 1.0, 0.45) if pct >= 70 else (Color(0.95, 0.85, 0.2) if pct >= 50 else Color(1.0, 0.4, 0.3)))
    if exam_misses.is_empty():
        quiz_explain.text = "Без ошибок — отличная работа!"
    else:
        quiz_explain.text = "Ошибки (повтори): " + ", ".join(PackedStringArray(exam_misses))
    quiz_score_label.text = "Счёт: %d / %d   ·   Лучший экзамен: %d%%" % [quiz_correct, quiz_total, exam_best]
    for b in quiz_answer_btns:
        b.disabled = true
    quiz_next_btn.text = "▶ Новый вопрос"
    _save_settings()

func _quiz_category(pr: Dictionary) -> String:
    var p: Dictionary = pr["p"]
    var rh := str(p.get("rhythm", "sinus"))
    if rh.begins_with("pace") or rh in ["afib", "aflutter", "avnrt", "vtach", "torsades", "bidirectional", "sss", "wenckebach", "mobitz2", "av3"]:
        return "arr"
    if str(p.get("bbb", "none")) != "none" or str(p.get("hemiblock", "none")) != "none":
        return "block"
    if float(p.get("st_x", 0.0)) != 0.0 or float(p.get("st_y", 0.0)) != 0.0 or float(p.get("st_z", 0.0)) != 0.0 or float(p.get("q_amp", 1.0)) >= 2.5 or float(p.get("t_post", 0.0)) > 0.0:
        return "mi"
    return "other"  # гипертрофия, электролиты, норма, синдромы (WPW и т.п.)

func _quiz_is_hard(pr: Dictionary) -> bool:
    var nm := str(pr["name"])
    for kw in QUIZ_HARD_KEYS:
        if kw in nm: return true
    return false

func _quiz_pool() -> Array:
    var pool: Array = []
    for i in PRESETS.size():
        var pr: Dictionary = PRESETS[i]
        if quiz_cat_idx > 0 and _quiz_category(pr) != QUIZ_CAT_KEYS[quiz_cat_idx]:
            continue
        if quiz_diff_idx == 1 and _quiz_is_hard(pr):
            continue
        if quiz_diff_idx == 2 and not _quiz_is_hard(pr):
            continue
        pool.append(i)
    return pool

func _quiz_build_eff(preset: Dictionary) -> Dictionary:
    # Считаем ЭКГ загадки в изоляции, не трогая глобальные параметры (не палим ответ).
    var sp := params
    var ss := state
    var sd := active_drugs
    params = DEFAULTS.duplicate(true)
    for key in preset["p"]: params[key] = preset["p"][key]
    state = STATE_DEFAULTS.duplicate(true)
    for key in preset["s"]: state[key] = preset["s"][key]
    active_drugs = []
    for _i in DRUGS.size(): active_drugs.append(0)
    var eff := _effective_params()
    params = sp
    state = ss
    active_drugs = sd
    return eff

func _quiz_report(eff: Dictionary, gen: Dictionary) -> String:
    var bufs: Array = gen["buffers"]
    var ev: Dictionary = gen["ev"]
    var spm := ECGModel.M / ECGModel.WINDOW_MS
    var vent: Array = ev["vent"]
    var fv := float(vent[0]["t"]) if not vent.is_empty() else 0.0
    var qd := maxf(float(gen["qeff"]), 140.0)
    var lo := maxi(0, int((fv - 20.0) * spm))
    var hi := int((fv + qd + 40.0) * spm)
    var rs: Array = []
    for b in bufs: rs.append(ECGModel.measure_rs(b, lo, hi))
    var res := ECGModel.classify(eff)
    var sok := ECGModel.sokolow(rs)
    var net_i: float = rs[0].x - rs[0].y
    var net_avf: float = rs[5].x - rs[5].y
    var axis := float(eff["qrs_axis"])
    if absf(net_i) > 0.05 or absf(net_avf) > 0.05:
        axis = rad_to_deg(atan2(net_avf, net_i))
    return ECGModel.ecg_report(eff, sok, ECGModel.axis_label(axis), res)

func _quiz_new() -> void:
    if quiz_lead_views.size() < 12:
        return
    quiz_answered = false
    var n := PRESETS.size()
    var pool := _quiz_pool()
    if pool.is_empty():
        for i in n: pool.append(i)
    var correct: int = pool[randi() % pool.size()]
    quiz_options = [correct]
    # Дистракторы — из той же выборки (правдоподобнее), при нехватке добираем из всех.
    var dpool := pool.duplicate()
    dpool.shuffle()
    for d in dpool:
        if quiz_options.size() >= 4: break
        if not (d in quiz_options): quiz_options.append(d)
    while quiz_options.size() < 4:
        var d2 := randi() % n
        if not (d2 in quiz_options): quiz_options.append(d2)
    quiz_options.shuffle()
    quiz_answer_idx = quiz_options.find(correct)
    for i in 4:
        var b: Button = quiz_answer_btns[i]
        b.text = str(PRESETS[quiz_options[i]]["name"])
        b.disabled = false
        b.remove_theme_color_override("font_color")
    var eff := _quiz_build_eff(PRESETS[correct])
    var gen := ECGModel.generate_all(eff)
    eff["qrs_eff"] = float(gen["qeff"])
    var bufs: Array = gen["buffers"]
    for i in quiz_lead_views.size():
        var lv: LeadView = quiz_lead_views[i]
        lv.samples = bufs[i]
        lv.queue_redraw()
    if quiz_monitor:
        quiz_monitor.hr_bpm = float(eff.get("hr", 0.0))
        quiz_monitor.update_samples(ECGModel.generate_monitor(eff, 1, 20000.0, 4000))
    quiz_explain_text = _quiz_report(eff, gen)
    quiz_feedback.text = ""
    quiz_feedback.remove_theme_color_override("font_color")
    quiz_explain.text = ""
    if exam_active:
        exam_q += 1
        quiz_score_label.text = "🎓 Экзамен — вопрос %d/%d   (верно: %d)" % [exam_q, EXAM_TOTAL, exam_score]
        quiz_next_btn.text = "Ответьте на вопрос…"
        quiz_next_btn.disabled = true
    else:
        quiz_next_btn.text = "▶ Следующий вопрос"
        quiz_next_btn.disabled = false
        quiz_score_label.text = "Счёт: %d / %d   ·   Лучший экзамен: %d%%" % [quiz_correct, quiz_total, exam_best]

func _quiz_answer(i: int) -> void:
    if quiz_answered or quiz_answer_idx < 0:
        return
    quiz_answered = true
    quiz_total += 1
    var ok := i == quiz_answer_idx
    if ok: quiz_correct += 1
    for j in 4:
        var b: Button = quiz_answer_btns[j]
        b.disabled = true
        if j == quiz_answer_idx:
            b.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45))
        elif j == i:
            b.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
    quiz_feedback.text = "✓ Верно!" if ok else "✗ Неверно. Правильно: " + str(quiz_answer_btns[quiz_answer_idx].text)
    quiz_feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45) if ok else Color(1.0, 0.4, 0.3))
    quiz_explain.text = quiz_explain_text
    if exam_active:
        if ok: exam_score += 1
        else: exam_misses.append(str(quiz_answer_btns[quiz_answer_idx].text))
        quiz_next_btn.disabled = false
        quiz_next_btn.text = "📊 Показать результат" if exam_q >= EXAM_TOTAL else "▶ Далее (%d/%d)" % [exam_q, EXAM_TOTAL]
        quiz_score_label.text = "🎓 Экзамен — вопрос %d/%d   (верно: %d)" % [exam_q, EXAM_TOTAL, exam_score]
    else:
        quiz_score_label.text = "Счёт: %d / %d   ·   Лучший экзамен: %d%%" % [quiz_correct, quiz_total, exam_best]
    _save_settings()

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
    # ЖЭ на пике нагрузки (чаще при ишемии/стенозе), угасают в восстановлении.
    var pvc := 0.0
    if stress_stage == 5: pvc = 6.0 + 8.0 * float(stress_sten)
    elif stress_stage == 6: pvc = 3.0 + 4.0 * float(stress_sten)
    params["pvc_rate"] = pvc
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
    var vi := rhythm_opt.get_item_id(idx)  # id пункта = индекс в RHYTHM_VALUES
    if vi < 0 or vi >= RHYTHM_VALUES.size():
        return
    params["rhythm"] = RHYTHM_VALUES[vi]
    _recompute()

func _on_bbb(idx: int) -> void:
    params["bbb"] = BBB_VALUES[idx]
    _recompute()

func _on_focus(idx: int) -> void:
    params["vt_focus"] = FOCUS_VALUES[idx]
    params["pvc_focus"] = FOCUS_VALUES[idx]
    _recompute()

func _on_pace_fault(idx: int) -> void:
    params["pace_fault"] = PACE_FAULT_VALUES[idx]
    _recompute()

func _on_pvc(idx: int) -> void:
    params["pvc_rate"] = PVC_RATES[idx]
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

# Активный препарат (терап. доза), купирующий данную аритмию → его название, иначе "".
func _active_converter(base: String) -> String:
    if base == "sinus" or base == "":
        return ""
    for i in DRUGS.size():
        if active_drugs[i] < 1: continue
        var nm := str(DRUGS[i]["name"])
        if DRUG_CONV.has(nm) and base in DRUG_CONV[nm]:
            return nm
    return ""

func _toxic_drug(rhythm: String) -> String:
    for i in DRUGS.size():
        if active_drugs[i] == 2 and str(DRUGS[i].get("trhythm", "")) == rhythm:
            return str(DRUGS[i]["name"])
    return ""

func _rhythm_rus(v: String) -> String:
    var i := RHYTHM_VALUES.find(v)
    return RHYTHM_NAMES[i] if i >= 0 else v

# аритмия от токсичности (vtach приоритетнее av3)
func _drug_rhythm() -> String:
    var found := ""
    for i in DRUGS.size():
        if active_drugs[i] != 2: continue
        var trv := str(DRUGS[i].get("trhythm", ""))
        if trv == "vtach": return "vtach"
        if trv != "" and found == "": found = trv
    return found

func _on_rate(v: float) -> void:
    if _suspend or not _built: return
    params["hr"] = v
    _recompute()

func _on_lead_opt(idx: int) -> void:
    _select_lead(idx)

func _sync_selectors() -> void:
    var ri := RHYTHM_VALUES.find(str(params["rhythm"]))
    for ii in rhythm_opt.item_count:  # выбрать пункт с нужным id (списки сгруппированы)
        if rhythm_opt.get_item_id(ii) == ri:
            rhythm_opt.selected = ii
            break
    var bi := BBB_VALUES.find(str(params["bbb"]))
    bbb_opt.selected = bi if bi >= 0 else 0
    var fi := FOCUS_VALUES.find(str(params.get("vt_focus", "lv_lat_mid")))
    if focus_opt: focus_opt.selected = fi if fi >= 0 else 0
    var pfi := PACE_FAULT_VALUES.find(str(params.get("pace_fault", "none")))
    if pace_fault_opt: pace_fault_opt.selected = pfi if pfi >= 0 else 0
    var pvi := PVC_RATES.find(float(params.get("pvc_rate", 0.0)))
    if pvc_opt: pvc_opt.selected = pvi if pvi >= 0 else 0

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
    var hp := (rh == "sinus" or rh == "av3" or rh == "sss" or rh == "wenckebach" or rh == "mobitz2" or rh == "pace_aai" or rh == "pace_ddd")
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

func _export_png() -> void:
    # Рендер 12-канального листа во внеэкранный SubViewport и сохранение в PNG.
    if buffers.size() < 12:
        return
    var vp := SubViewport.new()
    vp.size = Vector2i(1600, 1000)
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    var sheet := ECGSheet.new()
    sheet.size = Vector2(1600, 1000)
    sheet.buffers = buffers
    sheet.lead_names = LEADS
    sheet.title = dx_label.text if dx_label else "ЭКГ 12 отведений"
    vp.add_child(sheet)
    add_child(vp)
    sheet.queue_redraw()
    await RenderingServer.frame_post_draw
    var img := vp.get_texture().get_image()
    var path := "user://ecg_export.png"
    var err := img.save_png(path)
    vp.queue_free()
    if export_btn:
        export_btn.text = ("✓ PNG: " + ProjectSettings.globalize_path(path)) if err == OK else "Ошибка сохранения PNG"

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

func _defib() -> void:
    if not _built or _last_eff.is_empty():
        return
    var base := str(_last_eff.get("rhythm", "sinus"))
    if not (base in SHOCKABLE):
        event_label.text = "⚡ Разряд: нет показаний (ритм не требует кардиоверсии)"
        event_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
        return
    var eff_before := _last_eff.duplicate(true)  # текущая аритмия (до разряда)
    if _drug_rhythm() != "":
        # Аритмию поддерживает препарат (токсичность) — разряд даёт лишь рецидив.
        var steady0 := ECGModel.generate_monitor(_last_eff, selected_lead, 20000.0, 4000)
        var dbuf := ECGModel.generate_defib(eff_before, eff_before, selected_lead, 20000.0, 4000, 4000.0)
        monitor.play_transition(dbuf, steady0)
        event_label.text = "⚡ Разряд: ритм рецидивирует — устраните причину (%s)" % _toxic_drug(base)
        event_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
        return
    params["rhythm"] = "sinus"
    _recompute()  # 12 отведений/диагноз → синус; _last_eff теперь синус
    var steady := ECGModel.generate_monitor(_last_eff, selected_lead, 20000.0, 4000)
    var defib_buf := ECGModel.generate_defib(eff_before, _last_eff, selected_lead, 20000.0, 4000, 4000.0)
    monitor.play_transition(defib_buf, steady)
    _conv_shown_for = "sinus>sinus"  # не перезапускать анимацию на следующем refresh
    event_label.text = "⚡ Электроимпульсная терапия: %s → синусовый ритм" % _rhythm_rus(base)
    event_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

func _toggle_monitor_speed() -> void:
    if not monitor:
        return
    monitor.mm_per_s = 50.0 if monitor.mm_per_s < 40.0 else 25.0
    monitor_speed_btn.text = "Скорость: %d мм/с" % int(monitor.mm_per_s)

func _refresh_monitor() -> void:
    for j in lead_views.size():
        var lvj: LeadView = lead_views[j]
        lvj.highlighted = (j == selected_lead)
        lvj.queue_redraw()
    if _last_eff.is_empty(): return
    monitor.lead_name = LEADS[selected_lead]
    var base := str(params.get("rhythm", "sinus"))
    var effr := str(_last_eff.get("rhythm", "sinus"))
    monitor.hr_bpm = 0.0 if effr in ["asystole", "vfib", "vfib_fine"] else float(_last_eff.get("hr", 0.0))
    monitor.alarm = effr in CRITICAL
    monitor.alarm_text = "⚠ ТРЕВОГА: " + _rhythm_rus(effr) if monitor.alarm else ""
    var steady := ECGModel.generate_monitor(_last_eff, selected_lead, 20000.0, 4000)
    var sig := base + ">" + effr
    if effr != base and sig != _conv_shown_for and not edit_mode:
        # Препарат изменил ритм: анимируем переход base→eff один раз (купирование/индукция).
        var eff_before: Dictionary = _last_eff.duplicate(true)
        eff_before["rhythm"] = base
        var trans := ECGModel.generate_transition(eff_before, _last_eff, selected_lead, 20000.0, 4000, 5000.0)
        monitor.play_transition(trans, steady)
        _conv_shown_for = sig
    else:
        if effr == base: _conv_shown_for = ""
        monitor.update_samples(steady)
    if effr != base:
        if effr == "sinus":
            if base == "asystole" or base == "pea":
                event_label.text = "✚ %s: восстановление ритма (ROSC) — %s → синус" % [_active_converter(base), _rhythm_rus(base)]
            else:
                event_label.text = "✚ %s: купирование — %s → синусовый ритм" % [_active_converter(base), _rhythm_rus(base)]
            event_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.6))
        else:
            event_label.text = "⚠ %s (токсичность): %s" % [_toxic_drug(effr), _rhythm_rus(effr)]
            event_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
    else:
        event_label.text = ""
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
    elif _active_converter(str(e["rhythm"])) != "":
        e["rhythm"] = "sinus"  # купирование аритмии терапевтическим препаратом
    return e

# Одна строка: «как отличить (ЭКГ-признак) · почему так (механизм)».
# Выводится из текущего состояния модели, а не из имени пресета — для любой комбинации.
func _explain(eff: Dictionary, es: Dictionary, sok: Dictionary) -> String:
    var rhythm := str(eff.get("rhythm", "sinus"))
    if rhythm == "pace_vvi":
        var pf := str(eff.get("pace_fault", "none"))
        if pf == "loss_capture":
            return "Как отличить: спайки есть, QRS за ними нет · Почему: импульс не захватывает миокард (смещение электрода / высокий порог)."
        if pf == "undersense":
            return "Как отличить: спайки ложатся на собственные комплексы · Почему: ЭКС не «видит» свои сокращения (недочувствительность)."
    var R := {
        "afib": "Как отличить: нет зубцов P, мелковолнистая изолиния, RR абсолютно нерегулярный · Почему: хаотичное возбуждение предсердий, АВ-узел проводит беспорядочно.",
        "aflutter": "Как отличить: пилообразные волны F ~300/мин (II, III, aVF), проведение N:1 · Почему: macro-re-entry в правом предсердии вокруг трикуспидального кольца.",
        "avnrt": "Как отличить: узкие QRS 150–220/мин, P не видны · Почему: re-entry в АВ-узле — предсердия и желудочки активируются почти одновременно.",
        "junctional": "Как отличить: узкие QRS 40–60/мин, P отсутствует или ретроградный (отриц. в II/III/aVF) · Почему: водитель ритма в АВ-соединении, проведение ниже His нормальное.",
        "aivr": "Как отличить: широкие QRS 60–110/мин, АВ-диссоциация, плавное начало/конец · Почему: желудочковый водитель временно опережает синусовый — частый маркер реперфузии.",
        "vtach": "Как отличить: широкие QRS >120 мс, частота >100, АВ-диссоциация · Почему: очаг в желудочке, фронт идёт по миокарду в обход His-Пуркинье.",
        "vfib": "Как отличить: хаотичные волны разной амплитуды, нет QRS/P · Почему: множественные re-entry, желудочки не сокращаются — СЛР + дефибрилляция.",
        "vfib_fine": "Как отличить: те же хаотичные волны, но низкоамплитудные · Почему: поздняя ФЖ, истощение миокарда — прогноз хуже, продолжать СЛР.",
        "torsades": "Как отличить: полиморфная ЖТ, ось «вращается» вокруг изолинии, фон — длинный QT · Почему: ранние постдеполяризации при удлинённой реполяризации (магний).",
        "bidirectional": "Как отличить: направление QRS чередуется через комплекс · Почему: дигоксиновая интоксикация — альтернирующее проведение в пучках.",
        "pea": "Как отличить: на мониторе организованный ритм, но пульса нет · Почему: электрика есть, механики нет — искать обратимые причины (4Г/4Т).",
        "sss": "Как отличить: выраженная брадикардия и длинные синусовые паузы · Почему: дисфункция синусового узла (сбой автоматизма / синоатриальный блок).",
        "wenckebach": "Как отличить: PR удлиняется от удара к удару до выпадения QRS · Почему: нарастающая задержка в АВ-узле (Мобитц I, обычно доброкачественно).",
        "mobitz2": "Как отличить: PR постоянный, QRS внезапно выпадает · Почему: блок ниже АВ-узла (His-Пуркинье) — риск полной блокады, нужен ЭКС.",
        "av3": "Как отличить: P и QRS независимы, предсердия чаще желудочков · Почему: полный блок проведения, желудочки на собственном эскейп-ритме.",
        "asystole": "Как отличить: ровная изолиния без комплексов · Почему: нет электрической активности — НЕ шоковый ритм (адреналин + СЛР).",
        "pace_vvi": "Как отличить: спайк перед широким QRS, P нет · Почему: электрод в правом желудочке — стимуляция «снизу» даёт картину ЛБНПГ.",
        "pace_aai": "Как отличить: спайк перед P, QRS узкий собственный · Почему: стимулируется предсердие, проведение по His-Пуркинье сохранено.",
        "pace_ddd": "Как отличить: два спайка — предсердный и желудочковый · Почему: двухкамерная стимуляция синхронизирует A и V.",
        "pace_biv": "Как отличить: стимуляция обоих желудочков, QRS уже, чем при обычной ЭКС · Почему: ресинхронизация (CRT) при сердечной недостаточности.",
    }
    if R.has(rhythm):
        return R[rhythm]
    # синусовый — наслаиваем главную находку (по убыванию специфичности)
    var bbb := str(eff.get("bbb", "none"))
    var hemi := str(eff.get("hemiblock", "none"))
    var k := float(es.get("k", 4.0))
    var ca := float(es.get("ca", 2.4))
    var st_x := float(eff.get("st_x", 0.0))
    var st_y := float(eff.get("st_y", 0.0))
    var st_z := float(eff.get("st_z", 0.0))
    var delta := float(eff.get("delta_amp", 0.0))
    var t_post := float(eff.get("t_post", 0.0))
    var j_wave := float(eff.get("j_wave", 0.0))
    var pr_dep := float(eff.get("pr_dep", 0.0))
    var strain := float(eff.get("strain", 0.0))
    var pr := float(eff.get("pr", 160.0))
    var hr := float(eff.get("hr", 75.0))
    var pmorph := str(eff.get("p_morph", "normal"))
    if delta > 0.05 and pr < 120.0:
        return "Как отличить: короткий PR + дельта-волна (плавный наклон в начале QRS) · Почему: дополнительный путь (пучок Кента) проводит в обход АВ-узла (WPW)."
    if pr_dep > 0.1:
        return "Как отличить: диффузная вогнутая элевация ST + депрессия PR · Почему: воспаление субэпикарда всех стенок (перикардит)."
    if t_post > 1.0 and strain > 0.0 and float(eff.get("qrs_axis", 60.0)) >= 90.0:
        return "Как отличить: синусовая тахикардия, отклонение оси вправо, инверсия T в V1-V3 (± S1Q3T3) · Почему: острая перегрузка правого желудочка (ТЭЛА)."
    if st_x < -0.3 and st_z < -1.0 and t_post > 1.0:
        return "Как отличить: сводчатая («акулий плавник») элевация ST в V1-V2 + инверсия T · Почему: дисфункция Na-каналов, риск ФЖ (Бругада тип 1)."
    if j_wave > 2.0 and hr < 55.0:
        return "Как отличить: волны Осборна (горб на конце QRS, инферолатерально), брадикардия · Почему: гипотермия резко замедляет реполяризацию (J-волна растёт при ↓t°)."
    if j_wave > 0.5:
        return "Как отличить: зазубрина/подъём точки J с вогнутым ST · Почему: ранняя реполяризация — вариант нормы."
    if t_post > 3.0 and st_y < 1.0 and st_z > -1.0:
        return "Как отличить: глубокая симметричная инверсия T в V2-V3 · Почему: критический стеноз ПМЖВ — предынфарктное состояние (Wellens)."
    if st_y >= 1.0:
        return "Как отличить: элевация ST в II, III, aVF + реципрокная депрессия в I/aVL · Почему: окклюзия ПКА, повреждение нижней стенки (STEMI)."
    if st_z <= -1.0:
        return "Как отличить: элевация ST в V1-V4 + патологический Q · Почему: окклюзия ПМЖВ, повреждение передней стенки (STEMI)."
    if st_z >= 1.0:
        return "Как отличить: высокий R + депрессия ST в V1-V2 (зеркало) · Почему: задний инфаркт — прямых отведений нет, смотрим в зеркале."
    if k >= 5.5:
        return "Как отличить: высокий заострённый «шатровый» T, расширение QRS · Почему: гиперкалиемия ускоряет реполяризацию и замедляет проведение."
    if k <= 3.0:
        return "Как отличить: уплощение T, появление волны U, депрессия ST · Почему: гипокалиемия удлиняет реполяризацию (риск аритмий)."
    if ca <= 2.0:
        return "Как отличить: удлинение QT за счёт растянутого ST · Почему: гипокальциемия удлиняет фазу плато (реполяризацию)."
    if bbb == "lbbb":
        return "Как отличить: широкий QRS, в V6 широкий R без Q, в V1 QS · Почему: ЛЖ возбуждается с задержкой через миокард; T дискордантен."
    if bbb == "rbbb" and hemi == "lafb" and pr > 200.0:
        return "Как отличить: ПНПГ + блок передней ветви + удлинённый PR · Почему: трифасцикулярный блок — скомпрометированы все три пути проведения."
    if bbb == "rbbb" and hemi == "lafb":
        return "Как отличить: rSR′ в V1 (ПНПГ) + резкое отклонение оси влево (ЛПВ) · Почему: бифасцикулярный блок — проводит только задняя ветвь."
    if bbb == "rbbb":
        return "Как отличить: rSR′ (M-форма) в V1, широкий S в I и V6 · Почему: ПЖ возбуждается с задержкой; T дискордантен в V1-V3."
    if hemi == "lafb":
        return "Как отличить: резкое отклонение оси влево (≤ −45°), qR в aVL, rS в II/III · Почему: блок передней ветви — фронт обходит её снизу-вверх."
    if hemi == "lpfb":
        return "Как отличить: отклонение оси вправо, rS в I, qR в III · Почему: блок задней ветви (редкий — исключить ГПЖ)."
    if strain > 1.0 and bool(sok.get("lvh", false)):
        return "Как отличить: высокие R V5-V6 + косонисходящая депрессия ST и инверсия T · Почему: ГЛЖ с перегрузкой — субэндокардиальная ишемия."
    if bool(sok.get("lvh", false)):
        return "Как отличить: высокие R в V5-V6 + глубокие S в V1-V2 (Соколов-Лайон) · Почему: увеличенная масса ЛЖ даёт больший вектор."
    if bool(sok.get("rvh", false)):
        return "Как отличить: высокий R в V1, отклонение оси вправо · Почему: гипертрофия ПЖ перетягивает вектор вперёд-вправо."
    if pmorph == "mitrale":
        return "Как отличить: широкий двугорбый P в I/II · Почему: перегрузка левого предсердия (P-mitrale)."
    if pmorph == "pulmonale":
        return "Как отличить: высокий заострённый P в II/III/aVF · Почему: перегрузка правого предсердия (P-pulmonale)."
    if float(eff.get("pvc_rate", 0.0)) > 0.0:
        return "Как отличить: преждевременные широкие QRS без P, с компенсаторной паузой · Почему: эктопический желудочковый очаг (ЖЭ)."
    if pr > 200.0:
        return "Как отличить: PR > 200 мс, но каждый P проводится · Почему: замедление проведения в АВ-узле (АВ-блокада 1 ст.)."
    if hr > 100.0:
        return "Как отличить: синусовый ритм >100/мин, P перед каждым QRS · Почему: повышенный симпатический тонус (синусовая тахикардия)."
    if hr < 60.0:
        return "Как отличить: синусовый ритм <60/мин, P перед каждым QRS · Почему: вагусный тонус / тренированность (брадикардия)."
    return "Как отличить: P перед каждым QRS, RR постоянный, узкий QRS · Почему: норма — проведение по His-Пуркинье, ЧСС 60–100."

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
    elif rhythm == "aflutter":
        primary_dx = "Трепетание предсердий (волны F)"
        primary_conf = 0.92
    elif rhythm == "vtach":
        primary_dx = "Желудочковая тахикардия"
        primary_conf = 0.95
    elif rhythm == "torsades":
        primary_dx = "Тахикардия пируэт (Torsades)"
        primary_conf = 0.95
    elif rhythm == "bidirectional":
        primary_dx = "Двунаправленная ЖТ (дигоксиновая интоксикация)"
        primary_conf = 0.93
    elif rhythm == "avnrt":
        primary_dx = "АВУРТ (узловая тахикардия)"
        primary_conf = 0.9
    elif rhythm == "junctional":
        primary_dx = "Узловой (АВ-узловой) ритм"
        primary_conf = 0.88
    elif rhythm == "aivr":
        primary_dx = "Ускоренный идиовентрикулярный ритм (AIVR)"
        primary_conf = 0.88
    elif rhythm == "sss":
        primary_dx = "СССУ (синусовые паузы)"
        primary_conf = 0.88
    elif rhythm == "wenckebach":
        primary_dx = "AV-блокада 2 ст. Мобитц I (Венкебах)"
        primary_conf = 0.9
    elif rhythm == "mobitz2":
        primary_dx = "AV-блокада 2 ст. Мобитц II"
        primary_conf = 0.9
    elif rhythm == "av3":
        primary_dx = "Полная AV-блокада (диссоциация)"
        primary_conf = 0.9
    elif rhythm == "vfib":
        primary_dx = "ФИБРИЛЛЯЦИЯ ЖЕЛУДОЧКОВ — остановка кровообращения"
        primary_conf = 0.98
    elif rhythm == "vfib_fine":
        primary_dx = "Мелковолновая ФЖ — остановка кровообращения"
        primary_conf = 0.9
    elif rhythm == "pea":
        primary_dx = "ЭМД / PEA — электрическая активность без пульса"
        primary_conf = 0.95
    elif rhythm == "asystole":
        primary_dx = "АСИСТОЛИЯ — остановка кровообращения"
        primary_conf = 0.97
    elif rhythm == "pace_vvi":
        var pf := str(params.get("pace_fault", "none"))
        if pf == "loss_capture":
            primary_dx = "ЭКС (VVI): потеря захвата — спайки без QRS"
        elif pf == "undersense":
            primary_dx = "ЭКС (VVI): undersensing — асинхронная стимуляция"
        else:
            primary_dx = "ЭКС: желудочковая стимуляция (VVI)"
        primary_conf = 0.92
    elif rhythm == "pace_aai":
        primary_dx = "ЭКС: предсердная стимуляция (AAI)"
        primary_conf = 0.92
    elif rhythm == "pace_ddd":
        primary_dx = "ЭКС: двухкамерная стимуляция (DDD)"
        primary_conf = 0.92
    elif rhythm == "pace_biv":
        primary_dx = "ЭКС: бивентрикулярная стимуляция (BiV/CRT)"
        primary_conf = 0.92
    elif ed["dx"] != "":
        primary_dx = ed["dx"]
        primary_conf = ed["conf"]
    else:
        primary_dx = res["dx"]
        primary_conf = res["conf"]

    var findings: Array = []
    if rhythm == "sinus":
        if float(eff.get("pvc_rate", 0.0)) > 0.0: findings.append("желудочковые экстрасистолы")
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
    expl_label.text = _explain(eff, es, sok)

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
