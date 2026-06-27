class_name ECGModel
extends RefCounted

# 3D-ДИПОЛЬ. Один сердечный вектор H(t) бежит через His-Пуркинье
# (септум -> главный вектор стенок -> базис), каждое отведение = проекция L . H(t).
# Координаты: X = влево, Y = вниз (книзу), Z = назад (кзади).

const WINDOW_MS := 4000.0
const M := 800
const LEAD_NAMES := ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]

# Векторы отведений (единичные). Конечностные — фронтальная плоскость (гексаксиал),
# грудные — поперечный обход от передне-правого (V1) к левому (V6).
const LEADVEC := [
    Vector3(1.0, 0.0, 0.0),            # I
    Vector3(0.5, 0.8660, 0.0),         # II
    Vector3(-0.5, 0.8660, 0.0),        # III
    Vector3(-0.8660, -0.5, 0.0),       # aVR
    Vector3(0.8660, -0.5, 0.0),        # aVL
    Vector3(0.0, 1.0, 0.0),            # aVF
    Vector3(-0.3011, 0.0, -0.9536),    # V1
    Vector3(0.1498, 0.0, -0.9887),     # V2
    Vector3(0.4983, 0.0, -0.8670),     # V3
    Vector3(0.7507, 0.0, -0.6606),     # V4
    Vector3(0.9207, 0.0, -0.3903),     # V5
    Vector3(1.0, 0.0, 0.0),            # V6
]

# ---------- единые клинические пороги ----------
# Единственный источник правды для классификации/вероятностей/самочувствия.
# Раньше эти значения дублировались (и местами расходились) в classify,
# pathology_probabilities, _normal_conf, wellbeing.
const THR := {
    "hr_tachy": 100.0,      # ЧСС, тахикардия, уд/мин
    "hr_brady": 60.0,       # ЧСС, брадикардия, уд/мин
    "st_elev": 1.0,         # подъём ST, мм
    "st_depr": 1.0,         # депрессия ST, мм (модуль)
    "qrs_wide": 120.0,      # широкий QRS, мс
    "pr_long": 200.0,       # удлинение PR, мс
    "qtc_long": 460.0,      # удлинённый QTc, мс
    "qtc_short": 350.0,     # короткий QTc, мс
    "qtc_torsades": 500.0,  # QTc, порог риска Torsades, мс
    "t_high": 10.0,         # высокие T, мм
    "k_hyper": 5.5,         # гиперкалиемия, ммоль/л
    "k_hyper_mod": 6.5,     # умеренная гиперкалиемия
    "k_hyper_sev": 8.0,     # тяжёлая гиперкалиемия (синусоида)
    "k_hypo": 3.4,          # гипокалиемия
    "k_hypo_sev": 2.8,      # тяжёлая гипокалиемия (U-зубцы)
    "ca_hypo": 1.9,         # гипокальциемия, ммоль/л
    "ca_hyper": 2.9,        # гиперкальциемия, ммоль/л
}

# ---------- базисные функции ----------
static func _g(t: float, c: float, sigma: float) -> float:
    var d := t - c
    return exp(-(d * d) / (2.0 * sigma * sigma))

static func _plateau(t: float, a: float, b: float) -> float:
    if t <= a or t >= b: return 0.0
    var e := 12.0
    if t < a + e: return clampf((t - a) / e, 0.0, 1.0)
    if t > b - e: return clampf((b - t) / e, 0.0, 1.0)
    return 1.0

static func _u(v: Vector3) -> Vector3:
    return v.normalized() if v.length() > 0.0001 else v

# ---------- направления сердечного вектора (для обратного пересчёта в UI) ----------
static func p_dir(p: Dictionary) -> Vector3:
    var pa := deg_to_rad(60.0)
    return _u(Vector3(cos(pa), sin(pa), 0.10))

static func main_dir(p: Dictionary) -> Vector3:
    var a := deg_to_rad(float(p["qrs_axis"]))
    return _u(Vector3(cos(a), sin(a), 0.45))

static func t_dir(p: Dictionary) -> Vector3:
    var block := -1
    var bbb := str(p.get("bbb", "none"))
    if bbb == "lbbb": block = 0
    elif bbb == "rbbb": block = 1
    var tt := _activation(block, "", float(p.get("qrs_dur", 90.0)) / 90.0)
    var vg := _vg_from_tt(tt)
    if vg.length() > 0.001:
        return vg.normalized()
    var a := deg_to_rad(float(p["t_axis"]))
    return _u(Vector3(cos(a), sin(a), 0.30))

static func st_vec(p: Dictionary) -> Vector3:
    return Vector3(float(p.get("st_x", 0.0)), float(p.get("st_y", 0.0)), float(p.get("st_z", 0.0)))

static func st_level_lead(p: Dictionary, lead: int) -> float:
    return LEADVEC[lead].dot(st_vec(p))

# ---------- проводящая система: моменты возбуждения ----------
static func _gen_events(p: Dictionary, window: float = WINDOW_MS) -> Dictionary:
    var rhythm := str(p.get("rhythm", "sinus"))
    var hr := clampf(float(p["hr"]), 20.0, 300.0)
    var rr := 60000.0 / hr
    var bbb := str(p.get("bbb", "none"))
    var wide := bbb == "lbbb" or bbb == "rbbb"
    var nkind := bbb if wide else "n"
    var atrial: Array = []
    var vent: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 987654

    if rhythm == "afib":
        var taf := rng.randf_range(0.0, rr * 0.6)
        while taf < window:
            vent.append({"t": taf, "kind": nkind})
            taf += rr * rng.randf_range(0.5, 1.6)
        return {"atrial": [], "vent": vent, "afib": true}
    elif rhythm == "aflutter":
        # Трепетание предсердий: предсердия ~300/мин (пилообразные F), желудочки —
        # проведение N:1 (ratio выводится из ЧСС). QRS узкий, поверх непрерывной пилы.
        var arate := 300.0
        var fcycle := 60000.0 / arate  # ~200 мс
        var ratio := clampi(roundi(arate / clampf(hr, 50.0, 300.0)), 1, 6)
        var tfl := fcycle * ratio
        while tfl < window:
            vent.append({"t": tfl, "kind": nkind})
            tfl += fcycle * ratio
        return {"atrial": [], "vent": vent, "afib": false, "flutter": true, "fcycle": fcycle, "ratio": ratio}
    elif rhythm == "vtach":
        var tvt := 0.0
        while tvt < window:
            vent.append({"t": tvt, "kind": "vt"})
            tvt += rr
        return {"atrial": [], "vent": vent, "afib": false}
    elif rhythm == "torsades":
        var rrt := 60000.0 / maxf(hr, 200.0)
        var tto := 0.0
        while tto < window:
            vent.append({"t": tto, "kind": "vt"})
            tto += rrt
        return {"atrial": [], "vent": vent, "afib": false}
    elif rhythm == "av3":
        var ata := 0.0
        while ata < window:
            atrial.append(ata)
            ata += rr
        var esc := 60000.0 / 40.0
        var tv := rng.randf_range(0.0, esc)
        while tv < window:
            vent.append({"t": tv, "kind": "vt"})
            tv += esc
        return {"atrial": atrial, "vent": vent, "afib": false}
    elif rhythm == "wenckebach":
        # AV-блокада 2 ст., Мобитц I: PR прогрессивно удлиняется, пока QRS не выпадает
        # (P без QRS), затем цикл повторяется. 4:3 (выпадает каждый 4-й).
        var pr0 := float(p["pr"])
        var cyc := 4
        var taw := 0.0
        var bw := 0
        while taw < window:
            atrial.append(taw)
            var nph := bw % cyc
            if nph < cyc - 1:
                vent.append({"t": taw + pr0 + nph * 55.0, "kind": nkind})
            taw += rr
            bw += 1
        return {"atrial": atrial, "vent": vent, "afib": false}
    elif rhythm == "mobitz2":
        # AV-блокада 2 ст., Мобитц II: PR постоянный, периодически внезапно выпадает
        # QRS (непроведённый P). 3:2 (выпадает каждый 3-й).
        var pr2 := float(p["pr"])
        var tam := 0.0
        var bm := 0
        while tam < window:
            atrial.append(tam)
            if (bm + 1) % 3 != 0:
                vent.append({"t": tam + pr2, "kind": nkind})
            tam += rr
            bm += 1
        return {"atrial": atrial, "vent": vent, "afib": false}
    elif rhythm == "pace_vvi":
        var fault := str(p.get("pace_fault", "none"))
        var spk_v: Array = []
        var rrv := 60000.0 / hr
        if fault == "loss_capture":
            # Потеря захвата: спайк есть, но QRS вызывает только часть стимулов.
            var tlc := 0.0
            var bi := 0
            while tlc < window:
                spk_v.append(tlc - 6.0)
                if bi % 2 == 1:
                    vent.append({"t": tlc, "kind": "paced"})
                tlc += rrv
                bi += 1
            return {"atrial": [], "vent": vent, "afib": false, "spikes": spk_v}
        elif fault == "undersense":
            # Undersensing: ЭКС не видит собственный ритм и жёстко стимулирует со своей
            # частотой; спайк вне рефрактерного периода захватывает, внутри — нет.
            var intr := 60000.0 / maxf(float(p.get("intrinsic_hr", 50.0)), 25.0)
            var ti := rng.randf_range(0.0, intr)
            while ti < window:
                vent.append({"t": ti, "kind": nkind})
                ti += intr
            var tus := rrv * 0.4
            while tus < window:
                spk_v.append(tus - 6.0)
                var refractory := false
                for vv in vent:
                    if absf(float(vv["t"]) - tus) < 280.0:
                        refractory = true
                        break
                if not refractory:
                    vent.append({"t": tus, "kind": "paced"})
                tus += rrv
            vent.sort_custom(func(x, y): return float(x["t"]) < float(y["t"]))
            return {"atrial": [], "vent": vent, "afib": false, "spikes": spk_v}
        else:
            var tpv := 0.0
            while tpv < window:
                vent.append({"t": tpv, "kind": "paced"})
                spk_v.append(tpv - 6.0)
                tpv += rrv
            return {"atrial": [], "vent": vent, "afib": false, "spikes": spk_v}
    elif rhythm == "pace_biv":
        # Бивентрикулярная стимуляция (CRT): отслеживает синусовый P, стимулирует
        # оба желудочка с коротким AV-интервалом → узкий «слитный» QRS, два спайка.
        var spk_b: Array = []
        var rrb := 60000.0 / hr
        var avb := 120.0
        var tpb := 0.0
        while tpb < window:
            atrial.append(tpb)
            vent.append({"t": tpb + avb, "kind": "biv"})
            spk_b.append(tpb + avb - 6.0)
            spk_b.append(tpb + avb - 2.0)
            tpb += rrb
        return {"atrial": atrial, "vent": vent, "afib": false, "spikes": spk_b}
    elif rhythm == "pace_aai":
        var spk_a: Array = []
        var rra := 60000.0 / hr
        var prd := float(p["pr"])
        var tpa := 0.0
        while tpa < window:
            atrial.append(tpa)
            spk_a.append(tpa - 6.0)
            vent.append({"t": tpa + prd, "kind": nkind})
            tpa += rra
        return {"atrial": atrial, "vent": vent, "afib": false, "spikes": spk_a}
    elif rhythm == "pace_ddd":
        var spk_d: Array = []
        var rrd := 60000.0 / hr
        var avd := 165.0
        var tpd := 0.0
        while tpd < window:
            atrial.append(tpd)
            spk_d.append(tpd - 6.0)
            vent.append({"t": tpd + avd, "kind": "paced"})
            spk_d.append(tpd + avd - 6.0)
            tpd += rrd
        return {"atrial": atrial, "vent": vent, "afib": false, "spikes": spk_d}
    else:
        # Синус (+ опц. желудочковые экстрасистолы). pvc_rate — ЖЭ в минуту.
        var pvc_rate := float(p.get("pvc_rate", 0.0))
        var pvc_prob := clampf(pvc_rate / maxf(hr, 1.0), 0.0, 0.85) if pvc_rate > 0.0 else 0.0
        var resp := clampf(float(p.get("resp_arr", 0.0)), 0.0, 0.25)  # дыхательная аритмия
        var has_pvc := false
        var ats := 0.0
        while ats < window:
            atrial.append(ats)
            vent.append({"t": ats + float(p["pr"]), "kind": nkind})
            if pvc_prob > 0.0 and rng.randf() < pvc_prob:
                var pvc_t := ats + rr * 0.55  # преждевременный, после синусового QRS
                if pvc_t < window:
                    vent.append({"t": pvc_t, "kind": "pvc"})
                    has_pvc = true
            # RR удлиняется на выдохе / укорачивается на вдохе (~15 дых/мин)
            var rr_i := rr * (1.0 + resp * sin(TAU * (ats / 1000.0) * 0.25)) if resp > 0.0 else rr
            ats += rr_i
        if has_pvc:
            vent.sort_custom(func(x, y): return float(x["t"]) < float(y["t"]))
        return {"atrial": atrial, "vent": vent, "afib": false}

# ---------- компоненты сердечного вектора одного сокращения ----------
static func _p_components(p: Dictionary) -> Array:
    var pd := float(p["p_dur"])
    var pamp := float(p["p_amp"])
    var pa := deg_to_rad(60.0)
    var pdir := _u(Vector3(cos(pa), sin(pa), 0.10))
    var morph := str(p.get("p_morph", "normal"))
    var out: Array = []
    if morph == "pulmonale":
        # P-pulmonale (ГПП): высокий заострённый P, ось чуть «нижнее».
        var pdp := _u(Vector3(cos(deg_to_rad(75.0)), sin(deg_to_rad(75.0)), 0.05))
        out = [{"v": pdp * (pamp * 1.5), "c": pd * 0.45, "s": maxf(pd * 0.22, 6.0)}]
    elif morph == "mitrale":
        # P-mitrale (ГЛП): широкий двугорбый P; терминальная часть кзади (+Z) →
        # двухфазный P в V1 с глубокой отрицательной фазой, зазубрина (M) в II.
        var la := _u(Vector3(cos(pa) * 0.7, sin(pa) * 0.7, 0.85))
        out = [
            {"v": pdir * (pamp * 0.85), "c": pd * 0.34, "s": maxf(pd * 0.26, 7.0)},
            {"v": la * (pamp * 0.85), "c": pd * 0.72, "s": maxf(pd * 0.30, 8.0)},
        ]
    else:
        out = [{"v": pdir * pamp, "c": pd * 0.5, "s": maxf(pd * 0.30, 7.0)}]
    # Депрессия PR-сегмента (перикардит): Ta-волна (реполяризация предсердий)
    # противоположна P → депрессия PR в большинстве отведений, элевация в aVR.
    var pr_dep := float(p.get("pr_dep", 0.0))
    if pr_dep > 0.0:
        out.append({"v": -pdir * pr_dep, "c": pd * 1.15, "s": maxf(pd * 0.5, 30.0)})
    return out

# ---------- сегменты желудочков (активация по His-Пуркинье) ----------
static var _SEG: Array = []
static var _SEGMAP: Dictionary = {}

static func _segs() -> Array:
    if _SEG.is_empty():
        _SEG = [
            {"n": "sep_ap", "pos": Vector3(-0.3, 1.5, -1.0), "dir": Vector3(-0.7, 0.2, -0.4).normalized(), "w": 0.45, "b": 0, "endo": 8.0},
            {"n": "sep_mid", "pos": Vector3(-0.5, 0.0, -0.8), "dir": Vector3(-0.85, 0.0, -0.2).normalized(), "w": 0.60, "b": 0, "endo": 14.0},
            {"n": "sep_bas", "pos": Vector3(-0.6, -1.5, -0.5), "dir": Vector3(-0.75, -0.2, 0.1).normalized(), "w": 0.45, "b": 0, "endo": 24.0},
            {"n": "lv_lat_ap", "pos": Vector3(2.5, 1.6, -0.3), "dir": Vector3(0.75, 0.4, -0.2).normalized(), "w": 0.80, "b": 0, "endo": 28.0},
            {"n": "lv_lat_mid", "pos": Vector3(3.2, 0.0, 0.2), "dir": Vector3(0.92, 0.1, 0.05).normalized(), "w": 1.00, "b": 0, "endo": 36.0},
            {"n": "lv_lat_bas", "pos": Vector3(2.8, -1.6, 0.6), "dir": Vector3(0.80, -0.2, 0.3).normalized(), "w": 0.80, "b": 0, "endo": 50.0},
            {"n": "lv_ant_ap", "pos": Vector3(1.5, 1.5, -2.2), "dir": Vector3(0.4, 0.3, -0.85).normalized(), "w": 0.60, "b": 0, "endo": 28.0},
            {"n": "lv_ant_mid", "pos": Vector3(1.7, 0.0, -2.6), "dir": Vector3(0.3, 0.0, -0.92).normalized(), "w": 0.70, "b": 0, "endo": 38.0},
            {"n": "lv_ant_bas", "pos": Vector3(1.4, -1.6, -2.3), "dir": Vector3(0.2, -0.3, -0.85).normalized(), "w": 0.50, "b": 0, "endo": 52.0},
            {"n": "lv_inf_ap", "pos": Vector3(1.5, 2.6, -0.3), "dir": Vector3(0.3, 0.75, -0.2).normalized(), "w": 0.60, "b": 0, "endo": 30.0},
            {"n": "lv_inf_mid", "pos": Vector3(1.7, 3.0, 0.4), "dir": Vector3(0.2, 0.92, 0.25).normalized(), "w": 0.70, "b": 0, "endo": 42.0},
            {"n": "lv_inf_bas", "pos": Vector3(1.2, 2.6, 1.2), "dir": Vector3(0.0, 0.7, 0.6).normalized(), "w": 0.50, "b": 0, "endo": 56.0},
            {"n": "lv_post_mid", "pos": Vector3(1.8, 0.4, 2.4), "dir": Vector3(0.3, 0.2, 0.9).normalized(), "w": 0.55, "b": 0, "endo": 48.0},
            {"n": "lv_post_bas", "pos": Vector3(1.2, -1.0, 2.6), "dir": Vector3(0.1, -0.1, 0.92).normalized(), "w": 0.45, "b": 0, "endo": 60.0},
            {"n": "rv_ap", "pos": Vector3(-3.0, 1.6, -2.4), "dir": Vector3(-0.4, 0.3, -0.85).normalized(), "w": 0.32, "b": 1, "endo": 22.0},
            {"n": "rv_mid", "pos": Vector3(-3.8, 0.2, -2.6), "dir": Vector3(-0.5, 0.0, -0.85).normalized(), "w": 0.36, "b": 1, "endo": 31.0},
            {"n": "rv_out", "pos": Vector3(-3.6, -1.8, -2.0), "dir": Vector3(-0.6, -0.3, -0.7).normalized(), "w": 0.30, "b": 1, "endo": 48.0},
        ]
        for s in _SEG:
            _SEGMAP[s["n"]] = s
    return _SEG

# Длительность ПД сегмента (анатомический градиент: верхушка/эпикард короче — реполяризуются раньше).
static func _apd(name: String) -> float:
    var b := 205.0
    if "_ap" in name: b -= 35.0
    if "_bas" in name: b += 30.0
    if "lat" in name: b -= 26.0
    if "ant" in name: b -= 10.0
    if name.begins_with("rv"): b -= 12.0
    if name.begins_with("sep"): b += 12.0
    return b

# Желудочковый градиент Вилсона: направление T ~ -Σ wᵢ·dirᵢ·(rᵢ − r̄), rᵢ = активация + APD.
static func _vg_from_tt(tt: Dictionary) -> Vector3:
    var wsum := 0.0
    var rmean := 0.0
    for s in _segs():
        rmean += float(s["w"]) * (float(tt[s["n"]]) + _apd(s["n"]))
        wsum += float(s["w"])
    if wsum > 0.0: rmean /= wsum
    var vg := Vector3.ZERO
    for s in _segs():
        var rr := float(tt[s["n"]]) + _apd(s["n"])
        vg += s["dir"] * (-float(s["w"]) * (rr - rmean))
    return vg

const _V_MUSCLE := 0.045
const _SPIKE_VEC := Vector3(0.3, -0.85, -0.2)
const _SPIKE_AMP := 11.0
# Трепетание: вектор F-волны (кверху → пилообразные отрицательные F в II/III/aVF,
# положительные в V1, низкие в I) и амплитуда.
const _FLUTTER_VEC := Vector3(0.1, -1.0, -0.3)
const _FLUTTER_AMP := 2.6
const _SEPT := ["sep_ap", "sep_mid", "sep_bas"]
const _LVFREE := ["lv_lat_ap", "lv_lat_mid", "lv_ant_ap", "lv_ant_mid", "lv_inf_ap", "lv_inf_mid", "lv_post_mid"]
const _RVFREE := ["rv_ap", "rv_mid", "rv_out"]
const _BASAL := ["sep_bas", "lv_lat_bas", "lv_ant_bas", "lv_inf_bas", "lv_post_bas"]

# Дейкстра: моменты активации сегментов. block: -1 нет, 0 ЛНПГ, 1 ПНПГ. focus: очаг.
static func _activation(block: int, focus: String, qscale: float) -> Dictionary:
    var segs := _segs()
    var tt := {}
    for s in segs:
        tt[s["n"]] = INF
    var use_focus := focus != "" and _SEGMAP.has(focus)
    if use_focus:
        tt[focus] = 0.0
    else:
        for s in segs:
            var b: int = s["b"]
            if block == 0 and b == 0: continue
            if block == 1 and b == 1: continue
            tt[s["n"]] = float(s["endo"]) * qscale
    var visited := {}
    for _i in range(segs.size()):
        var best := ""
        var bestv := INF
        for s in segs:
            var nm: String = s["n"]
            if visited.has(nm): continue
            if tt[nm] < bestv:
                bestv = tt[nm]
                best = nm
        if best == "": break
        visited[best] = true
        if is_inf(bestv): continue
        var pbest: Vector3 = _SEGMAP[best]["pos"]
        for s2 in segs:
            var m: String = s2["n"]
            if visited.has(m): continue
            var cand := bestv + pbest.distance_to(s2["pos"]) / _V_MUSCLE
            if cand < tt[m]: tt[m] = cand
    return tt

# Дейкстра с несколькими очагами (бивентрикулярная стимуляция: RV + LV одновременно).
static func _activation_foci(foci: Array, qscale: float) -> Dictionary:
    var segs := _segs()
    var tt := {}
    for s in segs:
        tt[s["n"]] = INF
    for f in foci:
        if _SEGMAP.has(f):
            tt[f] = 0.0
    var visited := {}
    for _i in range(segs.size()):
        var best := ""
        var bestv := INF
        for s in segs:
            var nm: String = s["n"]
            if visited.has(nm): continue
            if tt[nm] < bestv:
                bestv = tt[nm]
                best = nm
        if best == "": break
        visited[best] = true
        if is_inf(bestv): continue
        var pbest: Vector3 = _SEGMAP[best]["pos"]
        for s2 in segs:
            var m: String = s2["n"]
            if visited.has(m): continue
            var cand := bestv + pbest.distance_to(s2["pos"]) / _V_MUSCLE
            if cand < tt[m]: tt[m] = cand
    return tt

static func _rtimes(tt: Dictionary, names: Array) -> Vector3:
    var mn := INF
    var mx := -INF
    var sm := 0.0
    for nm in names:
        var v: float = tt[nm]
        mn = minf(mn, v)
        mx = maxf(mx, v)
        sm += v
    return Vector3(mn, sm / names.size(), mx)

# Гибрид: тайминг фаз берётся из активации сегментов, рисуется чистыми нетто-векторами.
static func _beat_components(p: Dictionary, kind: String) -> Dictionary:
    var a := deg_to_rad(float(p["qrs_axis"]))
    var ta := deg_to_rad(float(p["t_axis"]))
    var qt := float(p["qt"])
    var block := -1
    var focus := ""
    var biv := false
    if kind == "lbbb": block = 0
    elif kind == "rbbb": block = 1
    elif kind == "vt": focus = str(p.get("vt_focus", "lv_lat_mid"))
    elif kind == "pvc": focus = str(p.get("pvc_focus", "lv_lat_mid"))
    elif kind == "paced": focus = "rv_ap"
    elif kind == "biv": biv = true

    var tt := _activation_foci(["rv_ap", "lv_lat_mid"], float(p["qrs_dur"]) / 90.0) if biv else _activation(block, focus, float(p["qrs_dur"]) / 90.0)
    var qon := INF
    var qoff := -INF
    for s in _segs():
        var tv: float = tt[s["n"]]
        qon = minf(qon, tv)
        qoff = maxf(qoff, tv)
    var qeff := (qoff - qon) + 34.0
    var wide := qeff > 120.0 or block >= 0 or focus != "" or biv

    var s_mid := _rtimes(tt, _SEPT).y
    var lvr := _rtimes(tt, _LVFREE)
    var m_mid := lvr.y
    var m_max := lvr.z
    var rvr := _rtimes(tt, _RVFREE)
    var b_mid := _rtimes(tt, _BASAL).y
    var main_amp := float(p["r_amp"])

    var comps: Array = []
    var samp := float(p["q_amp"]) * 1.2
    if block == 0 or focus.begins_with("lv") or biv: samp *= -0.2
    var hemi := str(p.get("hemiblock", "none"))
    # Гемиблок задаёт начальный вектор ЛЖ; комбинируется с ПНПГ (бифасцикулярная блокада:
    # ЛЖ через одну ветвь + поздний ПЖ от ПНПГ). С ПЛНПГ не сочетается (ЛЖ — сам блок).
    var hemi_ok := kind == "n" or kind == "rbbb"
    if hemi == "lafb" and hemi_ok:
        # Блокада передней ветви ЛНПГ: первой активируется задняя ветвь → начальный
        # вектор книзу-вправо (r в II/III/aVF, q в I/aVL), главный вектор кверху-влево
        # (резкая левая ось задаётся qrs_axis).
        comps.append({"v": _u(Vector3(-0.2, 0.65, -0.2)) * (absf(samp) * 1.4 + 1.0), "c": s_mid, "s": 8.0})
    elif hemi == "lpfb" and hemi_ok:
        # Блокада задней ветви ЛНПГ: первой активируется передняя ветвь → начальный
        # вектор кверху-влево (r в I/aVL, q в II/III/aVF), главный вектор книзу-вправо.
        comps.append({"v": _u(Vector3(0.35, -0.6, 0.0)) * (absf(samp) * 1.4 + 1.0), "c": s_mid, "s": 8.0})
    else:
        comps.append({"v": _u(Vector3(-0.55, -0.20, -0.45)) * samp, "c": s_mid, "s": 7.0})

    # Патологический Q инфаркта: вектор некроза направлен ОТ зоны повреждения
    # (против ST-вектора) → Q появляется в тех же отведениях, что и подъём ST,
    # территориально верно (нижний/передний/боковой). Только при норм. проведении.
    if kind == "n":
        var nv := st_vec(p)
        if absf(float(p["q_amp"])) > 1.8 and nv.length() > 0.3:
            comps.append({"v": -nv.normalized() * (float(p["q_amp"]) * 0.9), "c": qon + 5.0, "s": 6.0})

    var msig := maxf((m_max - s_mid) * 0.30, 6.0)
    var mamp := main_amp
    if wide:
        mamp *= 0.9
        msig = maxf(msig, 12.0)
    comps.append({"v": _u(Vector3(cos(a), sin(a), 0.45)) * mamp, "c": m_mid, "s": msig})

    var rv_amp := main_amp * 0.30
    if block == 1: rv_amp = main_amp * 0.62
    rv_amp *= (1.0 + float(p.get("rv_boost", 0.0)))  # ГПЖ: усиление передне-правых сил → доминантный R в V1
    var rsig := maxf((rvr.z - rvr.x) * 0.4, 6.0)
    if wide: rsig = maxf(rsig, 10.0)
    comps.append({"v": _u(Vector3(-0.70, -0.05, -0.55)) * rv_amp, "c": rvr.y, "s": rsig})

    comps.append({"v": _u(Vector3(-0.15, -0.25, 0.55)) * float(p["s_amp"]) * 0.8, "c": b_mid, "s": maxf(qeff * 0.10, 5.0)})

    # Передне-левая «переходная» R-компонента (норм. проведение): даёт физиологичную
    # прогрессию R V1→V6 (переходная зона V3-V4) и одновременно компенсирует S в I от
    # ПЖ-сил, так что измеренная ось ≈ параметру. Чисто фронтальная часть (X,Y) правит
    # ось, задняя (-Z) — грудные. Только для kind=="n" (блокады/эктопия — своя форма).
    if kind == "n":
        var ant_dir := _u(Vector3(0.70, 0.10, -0.70))
        var ant_scale := 1.0
        var nvec := st_vec(p)
        if absf(float(p["q_amp"])) > 1.8 and nvec.length() > 0.3:
            # Некроз гасит R в направлении повреждённой стенки: передний ИМ → потеря
            # передних R-сил → QS в V1-V3 (align высок для переднего, мал для нижнего).
            var align := maxf(0.0, ant_dir.dot(nvec.normalized()))
            ant_scale = clampf(1.0 - 1.1 * align * clampf(float(p["q_amp"]) / 3.5, 0.0, 1.2), 0.0, 1.0)
        comps.append({"v": ant_dir * (main_amp * 0.50 * ant_scale), "c": m_mid - 6.0, "s": msig * 0.9})
        # WPW: дельта-волна — медленный смазанный начальный подъём (предвозбуждение).
        var delta_amp := float(p.get("delta_amp", 0.0))
        if delta_amp > 0.0:
            comps.append({"v": _u(Vector3(cos(a), sin(a), 0.20)) * (main_amp * delta_amp), "c": qon - 10.0, "s": 20.0})

    # J-волна (ранняя реполяризация / синдром J-волны): зазубрина на конце QRS,
    # нижне-боковая (II/III/aVF/V4-V6).
    var j_wave := float(p.get("j_wave", 0.0))
    if j_wave > 0.0:
        comps.append({"v": _u(Vector3(0.4, 0.7, -0.1)) * j_wave, "c": qoff + 6.0, "s": 7.0})

    var j := qoff + 18.0
    var stt := maxf(qt - qeff, 120.0)
    var t_on := j + stt * 0.25
    var t_pk := j + stt * 0.55
    var t_sig := maxf(stt * 0.20, 9.0)
    var vg := _vg_from_tt(tt)
    var tdir: Vector3
    if vg.length() > 0.001:
        tdir = vg.normalized()
    else:
        tdir = _u(Vector3(cos(ta), sin(ta), 0.30))
    var tamp := absf(float(p["t_amp"]))
    if wide: tamp = maxf(tamp, 5.0)
    var t_sharp := maxf(float(p.get("t_sharp", 1.0)), 1.0)  # заострение T (гиперкалиемия)
    t_sig = t_sig / t_sharp
    var strain := float(p.get("strain", 0.0))
    if block == 0 or kind == "paced" or kind == "biv":
        # Широкий комплекс с поздней активацией ЛЖ (ПЛНПГ, ЭКС из ПЖ, BiV): вторичный
        # ДИСКОРДАНТНЫЙ T, противоположный главному вектору; амплитуда пропорциональна
        # QRS (глубже при высоком R) → инверсия T в I/aVL/V5-V6, положительный в V1-V3.
        tdir = -_u(Vector3(cos(a), sin(a), 0.45))
        tamp = maxf(tamp, main_amp * 0.42)
    elif strain > 0.0 and kind == "n":
        # Перегрузка (strain) при гипертрофии: вторичная инверсия T против главного
        # вектора в отведениях с высоким R (ГЛЖ: I/aVL/V5-V6; ГПЖ: V1-V3).
        tdir = -_u(Vector3(cos(a), sin(a), 0.30))
        tamp = maxf(tamp * 0.5, strain)
    comps.append({"v": tdir * tamp, "c": t_pk, "s": t_sig})
    if block == 1:
        # ПНПГ: вторичная дискордантная инверсия T в правых грудных (V1-V3) —
        # вектор кзади (+Z), противоположно терминальным силам ПЖ; лимб/V6 не трогает.
        comps.append({"v": _u(Vector3(0.10, 0.0, 1.0)) * (tamp * 1.1), "c": t_pk, "s": t_sig})

    # Задний T-вектор (+Z): инверсия T в правых/передних грудных V1-V4 без изменения
    # лимб/боковых — Wellens (глубокий симметричный T) и Бругада (инверсия в V1-V2).
    var t_post := float(p.get("t_post", 0.0))
    if t_post > 0.0:
        comps.append({"v": _u(Vector3(0.10, 0.0, 1.0)) * t_post, "c": t_pk, "s": t_sig})

    # U-волна (выражена при гипокалиемии): после T, конкордантна T, малой амплитуды.
    var u_amp := float(p.get("u_amp", 0.0))
    if u_amp > 0.01:
        var t_dir_u := tdir if tdir.length() > 0.001 else _u(Vector3(cos(ta), sin(ta), 0.30))
        comps.append({"v": t_dir_u * u_amp, "c": t_pk + maxf(t_sig * 1.8, 55.0), "s": maxf(t_sig * 0.9, 14.0)})

    return {"comps": comps, "j": j, "t_on": t_on, "qeff": qeff}

# Пилообразная F-волна трепетания: асимметричный «зуб пилы» без изолинии (медленный
# подъём ~60% цикла, быстрый спад ~40%), непрерывно — и под QRS-T тоже.
static func _saw(ts: float, cycle: float) -> float:
    var ph := fmod(ts, cycle) / cycle
    if ph < 0.78:
        return -1.0 + 2.0 * (ph / 0.78)
    return 1.0 - 2.0 * ((ph - 0.78) / 0.22)

static func _fwave(ts: float, lead: int) -> float:
    var w := 0.4
    if lead == 6: w = 1.0
    elif lead == 1: w = 0.7
    elif lead == 0 or lead == 5: w = 0.5
    var x := ts / 1000.0
    return w * (0.6 * sin(TAU * 5.5 * x) + 0.4 * sin(TAU * 8.3 * x + 1.7) + 0.3 * sin(TAU * 3.7 * x + 0.5))

# ---------- наборы комплексов (для пируэта — свой набор на удар) ----------
static func _build_beatsets(p: Dictionary, ev: Dictionary) -> Dictionary:
    var rhythm := str(p.get("rhythm", "sinus"))
    var vent: Array = ev["vent"]
    var sets: Array = []
    var idx: Array = []
    var qeff_out := 80.0
    if rhythm == "torsades":
        for bi in range(vent.size()):
            var pp := p.duplicate(true)
            pp["qrs_axis"] = float(p["qrs_axis"]) + bi * 42.0
            var bc := _beat_components(pp, "vt")
            sets.append(bc)
            idx.append(bi)
            qeff_out = maxf(qeff_out, float(bc["qeff"]))
    else:
        var kindmap := {}
        for vv in vent:
            var k = vv["kind"]
            if not kindmap.has(k):
                kindmap[k] = sets.size()
                var bc2 := _beat_components(p, k)
                sets.append(bc2)
                qeff_out = maxf(qeff_out, float(bc2["qeff"]))
            idx.append(kindmap[k])
    return {"sets": sets, "idx": idx, "qeff": qeff_out}

# рендер одного отведения по событиям и наборам комплексов
static func _render_one(p: Dictionary, lead: int, ev: Dictionary, bs: Dictionary, n: int, window: float) -> PackedFloat32Array:
    var lv: Vector3 = LEADVEC[lead]
    var sv := st_vec(p)
    var pst := lv.dot(sv)
    var strain := float(p.get("strain", 0.0))
    if strain > 0.0:
        # Косонисходящая депрессия ST в отведениях с высоким R (перегрузка): ST против
        # главного вектора, поэтому ГЛЖ даёт депрессию в I/aVL/V5-V6, ГПЖ — в V1-V3.
        pst += lv.dot(main_dir(p)) * (-strain * 0.4)
    var pd_lim := float(p["p_dur"]) + 40.0
    if float(p.get("pr_dep", 0.0)) > 0.0:
        pd_lim = maxf(pd_lim, float(p["pr"]))  # Ta-волна тянется до QRS (депрессия PR)
    var qt_lim := float(p["qt"]) + 160.0

    var pp: Array = []
    for c in _p_components(p):
        pp.append({"a": lv.dot(c["v"]), "c": c["c"], "s": c["s"]})
    var setproj: Array = []
    for st in bs["sets"]:
        var arr: Array = []
        for c in st["comps"]:
            arr.append({"a": lv.dot(c["v"]), "c": c["c"], "s": c["s"]})
        setproj.append({"comps": arr, "j": st["j"], "t_on": st["t_on"]})

    var buf := PackedFloat32Array()
    buf.resize(n)
    var afib: bool = ev["afib"]
    var flutter: bool = ev.get("flutter", false)
    var fcycle: float = ev.get("fcycle", 200.0)
    var fl_proj := lv.dot(_FLUTTER_VEC.normalized()) * _FLUTTER_AMP
    var atrial: Array = ev["atrial"]
    var vent: Array = ev["vent"]
    var idx: Array = bs["idx"]
    var spikes: Array = ev.get("spikes", [])
    var sp_proj := lv.dot(_SPIKE_VEC.normalized()) * _SPIKE_AMP
    var st_shape := float(p.get("st_shape", 0.0))  # +1 выпуклый (STEMI), -1 корытом (дигоксин)
    # Скользящие окна активных событий: события отсортированы по времени, ts растёт,
    # ширина окна постоянна — значит активный набор непрерывен. Это убирает
    # внутренний цикл по всем ударам на каждый отсчёт (было O(отсчёты × удары)).
    var a_start := 0
    var v_start := 0
    var s_start := 0
    var na := atrial.size()
    var nv := vent.size()
    var nsp := spikes.size()
    for si in n:
        var ts := si / float(n) * window
        var v := 0.0
        if not afib:
            while a_start < na and ts - float(atrial[a_start]) > pd_lim:
                a_start += 1
            var ai := a_start
            while ai < na:
                var tau := ts - float(atrial[ai])
                if tau < -10.0: break
                for pc in pp:
                    v += pc["a"] * _g(tau, pc["c"], pc["s"])
                ai += 1
        while v_start < nv and ts - float(vent[v_start]["t"]) > qt_lim:
            v_start += 1
        var ei := v_start
        while ei < nv:
            var tau2 := ts - float(vent[ei]["t"])
            if tau2 < -40.0: break
            var sp: Dictionary = setproj[idx[ei]]
            for cc in sp["comps"]:
                v += cc["a"] * _g(tau2, cc["c"], cc["s"])
            var pl := _plateau(tau2, sp["j"], sp["t_on"])
            if pl > 0.0:
                v += pst * pl
                # Форма сегмента ST: выпуклая (STEMI «надгробие») / корытообразная
                # (дигоксин). Кривизна ∝ уровню ST, поэтому реципрокные отв. зеркалят.
                if st_shape != 0.0 and absf(pst) > 0.05:
                    var ph := (tau2 - sp["j"]) / maxf(sp["t_on"] - sp["j"], 1.0)
                    v += st_shape * 0.6 * pst * (4.0 * ph * (1.0 - ph)) * pl
            ei += 1
        while s_start < nsp and ts - float(spikes[s_start]) > 14.0:
            s_start += 1
        var spi := s_start
        while spi < nsp:
            var dss := ts - float(spikes[spi])
            if dss < -14.0: break
            if absf(dss) < 14.0:
                v += sp_proj * _g(dss, 0.0, 2.5)
            spi += 1
        if afib:
            v += _fwave(ts, lead)
        if flutter:
            v += fl_proj * _saw(ts, fcycle)
        buf[si] = v
    return buf

# ---------- рендер: проекция вектора на каждое отведение ----------
static func generate_all(p: Dictionary) -> Dictionary:
    var ev := _gen_events(p)
    var bs := _build_beatsets(p, ev)
    var buffers: Array = []
    for li in 12:
        buffers.append(_render_one(p, li, ev, bs, M, WINDOW_MS))
    return {"buffers": buffers, "ev": ev, "qeff": bs["qeff"]}

# Длинный буфер одного отведения для бегущего монитора (ФП не повторяется ~20 с).
static func generate_monitor(p: Dictionary, lead: int, total_ms: float, n: int) -> PackedFloat32Array:
    var ev := _gen_events(p, total_ms)
    var bs := _build_beatsets(p, ev)
    var buf := _render_one(p, lead, ev, bs, n, total_ms)
    _add_artifacts(buf, p, lead, total_ms, n)
    return buf

# Артефакты живого монитора (на сетку 12 отведений/анализ НЕ наносятся — она чистая).
static func _add_artifacts(buf: PackedFloat32Array, p: Dictionary, lead: int, total_ms: float, n: int) -> void:
    var wander := float(p.get("baseline_wander", 0.0))  # дрейф изолинии, мм
    var mains := float(p.get("mains_noise", 0.0))        # сетевая наводка 50 Гц, мм
    if wander <= 0.0 and mains <= 0.0:
        return
    var phase := float(lead) * 0.7
    for i in n:
        var t := i / float(n) * total_ms / 1000.0
        if wander > 0.0:
            buf[i] += wander * (sin(TAU * 0.22 * t + phase) + 0.4 * sin(TAU * 0.11 * t + phase * 1.7))
        if mains > 0.0:
            buf[i] += mains * sin(TAU * 50.0 * t + phase)

# Один лид в стандартном окне — для интерактивной правки (лёгкий пересчёт при перетаскивании).
static func generate_lead(p: Dictionary, lead: int) -> PackedFloat32Array:
    var ev := _gen_events(p)
    var bs := _build_beatsets(p, ev)
    return _render_one(p, lead, ev, bs, M, WINDOW_MS)

# ---------- измерения ----------
static func measure_rs(buf: PackedFloat32Array, lo: int, hi: int) -> Vector2:
    var r := 0.0
    var s := 0.0
    for i in range(maxi(0, lo), mini(buf.size(), hi)):
        r = maxf(r, buf[i])
        s = maxf(s, -buf[i])
    return Vector2(r, s)

static func sokolow(rs: Array) -> Dictionary:
    var sv1: float = rs[6].y
    var rv1: float = rs[6].x
    var rv5: float = rs[10].x
    var rv6: float = rs[11].x
    var sv5: float = rs[10].y
    var sv6: float = rs[11].y
    var r_avl: float = rs[4].x
    var r_i: float = rs[0].x
    var s_iii: float = rs[2].y
    var lvh_prec := sv1 + maxf(rv5, rv6)
    var lvh_limb := r_avl >= 11.0 or (r_i + s_iii) >= 25.0
    var rvh_idx := rv1 + maxf(sv5, sv6)
    return {
        "lvh_prec_idx": lvh_prec, "lvh_by_prec": lvh_prec >= 35.0,
        "lvh_by_limb": lvh_limb, "lvh": lvh_prec >= 35.0 or lvh_limb,
        "rvh_idx": rvh_idx, "rvh": rvh_idx >= 11.0,
        "sv1": sv1, "rv1": rv1, "rv5": rv5, "rv6": rv6,
        "sv5": sv5, "sv6": sv6, "r_avl": r_avl, "r_i": r_i, "s_iii": s_iii,
    }

static func axis_label(a: float) -> String:
    if a >= -30.0 and a <= 90.0: return "норма"
    if a > 90.0 and a <= 180.0: return "отклонение вправо"
    if a >= -90.0 and a < -30.0: return "отклонение влево"
    return "резкое отклонение (СЗ-квадрант)"

static func qtc(p: Dictionary) -> float:
    if p.has("qtc"):
        return float(p["qtc"])
    var rr_sec := 60.0 / clampf(float(p["hr"]), 20.0, 300.0)
    return float(p["qt"]) / sqrt(rr_sec)

static func _conf(margin: float, scale: float) -> float:
    return clampf(0.5 + 0.5 * margin / scale, 0.5, 0.99)

static func _st_extremes(p: Dictionary) -> Vector2:
    var hi := -1.0e9
    var lo := 1.0e9
    for i in 12:
        var lvl := st_level_lead(p, i)
        hi = maxf(hi, lvl)
        lo = minf(lo, lvl)
    return Vector2(hi, lo)

static func electrolyte_dx(s: Dictionary) -> Dictionary:
    var k: float = s["k"]
    var ca: float = s["ca"]
    if k >= THR.k_hyper_sev: return {"dx": "Тяжёлая гиперкалиемия (синусоида)", "conf": _conf(k - THR.k_hyper_sev, 1.5)}
    if k >= THR.k_hyper_mod: return {"dx": "Гиперкалиемия", "conf": _conf(k - THR.k_hyper_mod, 1.5)}
    if k >= THR.k_hyper: return {"dx": "Гиперкалиемия (остроконечные T)", "conf": _conf(k - THR.k_hyper, 1.0)}
    if k <= THR.k_hypo_sev: return {"dx": "Гипокалиемия (зубцы U)", "conf": _conf(THR.k_hypo_sev - k, 1.0)}
    if k <= THR.k_hypo: return {"dx": "Гипокалиемия", "conf": _conf(THR.k_hypo - k, 0.8)}
    if ca <= THR.ca_hypo: return {"dx": "Гипокальциемия (удлинение QT)", "conf": _conf(THR.ca_hypo - ca, 0.6)}
    if ca >= THR.ca_hyper: return {"dx": "Гиперкальциемия (укорочение QT)", "conf": _conf(ca - THR.ca_hyper, 0.6)}
    return {"dx": ""}

static func classify(p: Dictionary) -> Dictionary:
    var hr: float = p["hr"]
    var qrs: float = p.get("qrs_eff", p["qrs_dur"])
    var pr: float = p["pr"]
    var ste := _st_extremes(p)
    var st_e := ste.x
    var st_d := ste.y
    var t_amp: float = p["t_amp"]
    var p_amp: float = p["p_amp"]
    var qtc_v := qtc(p)
    var wide := qrs > THR.qrs_wide
    var no_p := p_amp < 0.5

    var dx := ""
    var conf := 0.9
    if st_e >= THR.st_elev:
        dx = "Подъём ST (STEMI)"
        conf = _conf(st_e - THR.st_elev, 3.0)
    elif st_d <= -THR.st_depr:
        dx = "Депрессия ST / ишемия"
        conf = _conf(-THR.st_depr - st_d, 2.5)
    elif wide:
        dx = "Блокада ножки пучка Гиса"
        conf = _conf(qrs - THR.qrs_wide, 60.0)
    elif hr > THR.hr_tachy:
        dx = "Синусовая тахикардия"
        conf = _conf(hr - THR.hr_tachy, 40.0)
    elif hr < THR.hr_brady:
        dx = "Синусовая брадикардия"
        conf = _conf(THR.hr_brady - hr, 25.0)
    elif pr > THR.pr_long:
        dx = "AV-блокада 1 ст."
        conf = _conf(pr - THR.pr_long, 80.0)
    elif qtc_v > THR.qtc_long:
        dx = "Удлинённый QT"
        conf = _conf(qtc_v - THR.qtc_long, 80.0)
    elif t_amp > THR.t_high:
        dx = "Гиперкалиемия (высокие T)"
        conf = _conf(t_amp - THR.t_high, 8.0)
    elif no_p:
        dx = "Нет P-зубца"
        conf = 0.6
    else:
        dx = "Норма (синусовый ритм)"
        conf = _normal_conf(hr, st_e, st_d, qrs, pr, qtc_v, t_amp)
    return {"dx": dx, "conf": conf, "qtc": qtc_v}

static func _normal_conf(hr: float, st_e: float, st_d: float, qrs: float, pr: float, qtc_v: float, t_amp: float) -> float:
    var m: Array[float] = [
        (THR.hr_tachy - hr) / 40.0, (hr - THR.hr_brady) / 25.0,
        (THR.st_elev - st_e) / 3.0, (st_d + THR.st_depr) / 2.5,
        (THR.qrs_wide - qrs) / 60.0, (THR.pr_long - pr) / 80.0,
        (THR.qtc_long - qtc_v) / 80.0, (THR.t_high - t_amp) / 8.0,
    ]
    var lo := 1.0
    for v in m: lo = minf(lo, v)
    return clampf(0.5 + 0.5 * lo, 0.5, 0.99)

# ---------- вероятность патологии (дифференциальный диагноз) ----------
static func _p_hi(x: float, thr: float, scale: float) -> float:
    return clampf(1.0 / (1.0 + exp(-(x - thr) / scale)), 0.0, 0.99)

static func _p_lo(x: float, thr: float, scale: float) -> float:
    return clampf(1.0 / (1.0 + exp((x - thr) / scale)), 0.0, 0.99)

static func pathology_probabilities(p: Dictionary, s: Dictionary) -> Array:
    var hr := float(p["hr"])
    var rhythm := str(p.get("rhythm", "sinus"))
    var ste := _st_extremes(p)
    var qrs := float(p.get("qrs_eff", p["qrs_dur"]))
    var pr := float(p["pr"])
    var qtc_v := qtc(p)
    var k := float(s["k"])
    var ca := float(s["ca"])
    var t_amp := float(p["t_amp"])
    var out: Array = []

    if rhythm == "afib": out.append({"name": "Фибрилляция предсердий", "prob": 0.96})
    elif rhythm == "aflutter": out.append({"name": "Трепетание предсердий (волны F)", "prob": 0.95})
    elif rhythm == "vtach": out.append({"name": "Желудочковая тахикардия", "prob": 0.97})
    elif rhythm == "torsades": out.append({"name": "Пируэтная тахикардия (Torsades)", "prob": 0.97})
    elif rhythm == "wenckebach": out.append({"name": "AV-блокада 2 ст. Мобитц I (Венкебах)", "prob": 0.93})
    elif rhythm == "mobitz2": out.append({"name": "AV-блокада 2 ст. Мобитц II", "prob": 0.93})
    elif rhythm == "av3": out.append({"name": "Полная AV-блокада", "prob": 0.95})
    var paced := rhythm.begins_with("pace")
    if paced: out.append({"name": "Ритм электрокардиостимулятора", "prob": 0.9})
    if rhythm == "sinus" and float(p.get("pvc_rate", 0.0)) > 0.0:
        out.append({"name": "Желудочковые экстрасистолы (ЖЭ)", "prob": 0.85})

    # Распознавание синдромов по характерным признакам морфологии.
    if float(p.get("delta_amp", 0.0)) > 0.0 and float(p["pr"]) < 120.0:
        out.append({"name": "WPW (предвозбуждение)", "prob": 0.9})
    if float(p.get("pr_dep", 0.0)) > 0.0:
        out.append({"name": "Перикардит (диффузный)", "prob": 0.85})
    if float(p.get("j_wave", 0.0)) > 0.0:
        out.append({"name": "Ранняя реполяризация", "prob": 0.78})
    if float(p.get("t_post", 0.0)) > 0.0:
        if ste.x >= 0.7:
            out.append({"name": "Синдром Бругада (тип 1)", "prob": 0.85})
        else:
            out.append({"name": "Синдром Wellens (стеноз ПМЖВ)", "prob": 0.85})
    if float(p.get("strain", 0.0)) > 0.0:
        out.append({"name": "Гипертрофия с перегрузкой (strain)", "prob": 0.82})
    var hemi := str(p.get("hemiblock", "none"))
    var is_rbbb := str(p.get("bbb", "none")) == "rbbb"
    if hemi == "lafb":
        if is_rbbb: out.append({"name": "Бифасцикулярная блокада (ПНПГ + ЛПВ)", "prob": 0.9})
        else: out.append({"name": "Блокада передней ветви ЛНПГ (ЛПВ)", "prob": 0.85})
    elif hemi == "lpfb":
        if is_rbbb: out.append({"name": "Бифасцикулярная блокада (ПНПГ + ЛЗВ)", "prob": 0.88})
        else: out.append({"name": "Блокада задней ветви ЛНПГ (ЛЗВ)", "prob": 0.8})

    # Центры сигмоид = клинические пороги THR (50% уверенности на пороге);
    # ворота (gate) — порог минус запас, чтобы пограничные случаи попадали в дифференциал.
    if ste.x >= THR.st_elev - 0.3: out.append({"name": "Подъём ST (STEMI)", "prob": _p_hi(ste.x, THR.st_elev, 0.9)})
    if ste.y <= -(THR.st_depr - 0.3): out.append({"name": "Ишемия (депрессия ST)", "prob": _p_hi(-ste.y, THR.st_depr, 0.8)})
    if qrs >= THR.qrs_wide - 15.0 and not paced: out.append({"name": "Блокада ножки пучка Гиса", "prob": _p_hi(qrs, THR.qrs_wide, 14.0)})
    if pr >= THR.pr_long - 5.0: out.append({"name": "AV-блокада 1 ст.", "prob": _p_hi(pr, THR.pr_long, 26.0)})
    if qtc_v >= THR.qtc_long - 20.0: out.append({"name": "Удлинённый QT", "prob": _p_hi(qtc_v, THR.qtc_long, 28.0)})
    if qtc_v <= THR.qtc_short: out.append({"name": "Короткий QT", "prob": _p_lo(qtc_v, THR.qtc_short - 10.0, 20.0)})
    if rhythm == "sinus" and hr >= THR.hr_tachy - 5.0: out.append({"name": "Синусовая тахикардия", "prob": _p_hi(hr, THR.hr_tachy, 22.0)})
    if rhythm == "sinus" and hr <= THR.hr_brady + 2.0: out.append({"name": "Синусовая брадикардия", "prob": _p_lo(hr, THR.hr_brady, 14.0)})
    if k >= THR.k_hyper - 0.1: out.append({"name": "Гиперкалиемия", "prob": _p_hi(k, THR.k_hyper_mod - 0.5, 0.7)})
    if k <= THR.k_hypo + 0.1: out.append({"name": "Гипокалиемия", "prob": _p_lo(k, THR.k_hypo - 0.2, 0.6)})
    if ca <= THR.ca_hypo + 0.2: out.append({"name": "Гипокальциемия", "prob": _p_lo(ca, THR.ca_hypo + 0.1, 0.25)})
    if ca >= THR.ca_hyper - 0.2: out.append({"name": "Гиперкальциемия", "prob": _p_hi(ca, THR.ca_hyper - 0.05, 0.25)})
    if t_amp >= THR.t_high - 1.0 and k < THR.k_hyper - 0.1: out.append({"name": "Высокие зубцы T", "prob": _p_hi(t_amp, THR.t_high + 1.0, 4.0)})

    out.sort_custom(func(x, y): return float(x["prob"]) > float(y["prob"]))
    return out

static func abnormality_prob(diff: Array) -> float:
    if diff.is_empty(): return 0.04
    return float(diff[0]["prob"])

# ---------- текстовое описание ЭКГ ----------
static func _join(arr: Array, sep: String) -> String:
    var out := ""
    for i in range(arr.size()):
        out += str(arr[i])
        if i < arr.size() - 1: out += sep
    return out

static func _st_description(p: Dictionary) -> String:
    var elev: Array = []
    var depr: Array = []
    for i in 12:
        var lvl := st_level_lead(p, i)
        if lvl >= THR.st_elev: elev.append(LEAD_NAMES[i])
        elif lvl <= -THR.st_depr: depr.append(LEAD_NAMES[i])
    if elev.is_empty() and depr.is_empty(): return ""
    var parts: Array = []
    if not elev.is_empty(): parts.append("подъём ST в " + _join(elev, ", "))
    if not depr.is_empty(): parts.append("реципрокная депрессия ST в " + _join(depr, ", "))
    return _join(parts, "; ")

static func ecg_report(p: Dictionary, sok: Dictionary, axis_lbl: String, res: Dictionary) -> String:
    var rhythm := str(p.get("rhythm", "sinus"))
    var hr := roundi(float(p["hr"]))
    var line1 := ""
    if rhythm == "afib":
        line1 = "Ритм: фибрилляция предсердий, ср. ЧСС ~%d, нерегулярный (нет P, волны f)." % hr
    elif rhythm == "aflutter":
        var ratio := clampi(roundi(300.0 / maxf(float(p["hr"]), 50.0)), 1, 6)
        line1 = "Ритм: трепетание предсердий, пилообразные волны F ~300/мин, проведение %d:1, ЧСС жел. ~%d." % [ratio, hr]
    elif rhythm == "vtach":
        line1 = "Ритм: желудочковая тахикардия, ЧСС %d, широкие комплексы без P." % hr
    elif rhythm == "torsades":
        line1 = "Ритм: пируэтная тахикардия (Torsades) — полиморфная ЖТ с вращением оси на фоне длинного QT."
    elif rhythm == "wenckebach":
        line1 = "Ритм: AV-блокада 2 ст. Мобитц I (Венкебах) — PR прогрессивно удлиняется до выпадения QRS (предсердия %d)." % hr
    elif rhythm == "mobitz2":
        line1 = "Ритм: AV-блокада 2 ст. Мобитц II — PR постоянный, периодически выпадает QRS (предсердия %d)." % hr
    elif rhythm == "av3":
        line1 = "Ритм: полная АВ-блокада, предсердия %d / желудочки ~40 (диссоциация)." % hr
    elif rhythm == "pace_vvi":
        var pf := str(p.get("pace_fault", "none"))
        if pf == "loss_capture":
            line1 = "Ритм: ЭКС (VVI), ЧСС %d — ПОТЕРЯ ЗАХВАТА: спайки без последующего QRS." % hr
        elif pf == "undersense":
            line1 = "Ритм: ЭКС (VVI), ЧСС %d — UNDERSENSING: спайки асинхронны собственному ритму." % hr
        else:
            line1 = "Ритм: ЭКС, желудочковая стимуляция (VVI), ЧСС %d. Спайк + широкий навязанный QRS, верхняя ось." % hr
    elif rhythm == "pace_aai":
        line1 = "Ритм: ЭКС, предсердная стимуляция (AAI), ЧСС %d. Спайк перед P, QRS узкий (проведение сохранено)." % hr
    elif rhythm == "pace_ddd":
        line1 = "Ритм: ЭКС, двухкамерная стимуляция (DDD), ЧСС %d. Спайк P + спайк QRS (AV-последовательно)." % hr
    elif rhythm == "pace_biv":
        line1 = "Ритм: ЭКС, бивентрикулярная стимуляция (BiV/CRT), ЧСС %d. Два спайка, узкий слитный QRS, R в aVR." % hr
    else:
        line1 = "Ритм: синусовый, ЧСС %d." % hr
        if float(p.get("pvc_rate", 0.0)) > 0.0:
            line1 += " Желудочковые экстрасистолы (широкие преждевременные комплексы без P)."
    var line2 := "Ось %s. PR %d, QRS %d, QTc %d мс." % [
        axis_lbl, roundi(float(p["pr"])), roundi(float(p.get("qrs_eff", p["qrs_dur"]))), roundi(float(res["qtc"]))]
    var extra: Array = []
    var st_desc := _st_description(p)
    if st_desc != "": extra.append(st_desc)
    if sok["lvh"]: extra.append("признаки ГЛЖ (Соколов-Лайон)")
    if sok["rvh"]: extra.append("признаки ГПЖ")
    if float(p.get("qrs_eff", p["qrs_dur"])) > 120.0 and rhythm == "sinus": extra.append("широкий QRS — блокада ножки")
    var out := line1 + "\n" + line2
    if not extra.is_empty():
        out += "\nОсобенности: " + _join(extra, "; ") + "."
    return out

# ---------- нагрузочная проба ----------
static func stress_target_hr(age: float) -> float:
    return 0.85 * (220.0 - age)

static func stress_hr(age: float, stage: int) -> float:
    var rest := 72.0
    var peak := stress_target_hr(age)
    if stage <= 0: return rest
    if stage <= 5: return rest + (peak - rest) * (float(stage) / 5.0)
    if stage == 6: return rest + (peak - rest) * 0.62
    return rest + 20.0

static func stress_depr(age: float, stenosis: int, stage: int) -> float:
    if stenosis <= 0: return 0.0
    var thr := 100.0
    var peak := stress_target_hr(age)
    var hr := stress_hr(age, stage)
    var frac := clampf((hr - thr) / maxf(peak - thr, 1.0), 0.0, 1.15)
    var maxd := 1.6 if stenosis == 1 else 3.2
    var d := frac * maxd
    if stage == 6: d = maxf(d, 0.6 * maxd)
    if stage == 7: d *= 0.3
    return d

# субэндокардиальная ишемия: вектор ST к aVR → депрессия в боковых/нижних, элевация aVR
static func stress_st_vec(depr: float) -> Vector3:
    return Vector3(-0.87, -0.5, 0.0).normalized() * (depr / 0.87)

static func stress_verdict(peak_depr: float) -> String:
    if peak_depr >= 2.0: return "положительная (выраженная депрессия ST)"
    if peak_depr >= 1.0: return "положительная (депрессия ST ≥1 мм)"
    if peak_depr >= 0.5: return "сомнительная"
    return "отрицательная"

# Реакция АД на нагрузку. Норма: систолическое растёт. Выраженный стеноз: экзерционная
# гипотензия (АД не растёт/падает на пике) — признак тяжёлой ишемии/дисфункции ЛЖ.
static func stress_bp(stenosis: int, stage: int) -> Vector2:
    var rest_sys := 125.0
    var rest_dia := 80.0
    var f := 0.0
    if stage <= 5: f = float(stage) / 5.0
    elif stage == 6: f = 0.4
    else: f = 0.12
    var dsys := 72.0 * f
    if stenosis == 1:
        dsys *= 0.8
    elif stenosis == 2:
        dsys = 72.0 * f * (1.0 - 1.05 * f)
    var sys := maxf(rest_sys + dsys, 85.0)
    var dia := rest_dia + 3.0 * f
    return Vector2(sys, dia)

static func stress_bp_verdict(stenosis: int) -> String:
    var peak_sys := stress_bp(stenosis, 5).x
    if peak_sys < 135.0: return "патологическая — АД не растёт/падает (тревожно)"
    if peak_sys > 210.0: return "гипертоническая реакция"
    return "нормальная"

# ---------- самочувствие ----------
static func wellbeing(p: Dictionary, s: Dictionary) -> Dictionary:
    var hr := float(p["hr"])
    var rhythm := str(p.get("rhythm", "sinus"))
    var sys := float(s["bp_sys"])
    var k := float(s["k"])
    var st := _st_extremes(p).x
    var qtc_v := qtc(p)
    var issues: Array = []
    var sev := 0

    if rhythm == "vtach":
        issues.append("желудочковая тахикардия — угроза остановки")
        sev = maxi(sev, 3)
    elif rhythm == "torsades":
        issues.append("пируэтная тахикардия — угроза фибрилляции желудочков")
        sev = maxi(sev, 3)
    elif rhythm == "av3":
        issues.append("полная AV-блокада — редкий пульс, обмороки")
        sev = maxi(sev, 2)
    elif rhythm.begins_with("pace"):
        issues.append("ритм навязан кардиостимулятором (стабильно)")
        sev = maxi(sev, 0)
    elif rhythm == "afib" and hr > 110.0:
        issues.append("ФП с тахисистолией — сердцебиение")
        sev = maxi(sev, 1)

    if k >= 7.5:
        issues.append("тяжёлая гиперкалиемия — риск остановки")
        sev = maxi(sev, 3)
    elif k >= THR.k_hyper_mod:
        issues.append("гиперкалиемия")
        sev = maxi(sev, 2)
    elif k <= 2.5:
        issues.append("тяжёлая гипокалиемия — аритмии")
        sev = maxi(sev, 2)

    if rhythm != "vtach" and rhythm != "av3" and rhythm != "torsades" and not rhythm.begins_with("pace"):
        if hr >= 180.0:
            issues.append("крайняя тахикардия")
            sev = maxi(sev, 3)
        elif hr >= 150.0:
            issues.append("тахикардия — сердцебиение, одышка")
            sev = maxi(sev, 2)
        elif hr <= 35.0:
            issues.append("крайняя брадикардия — обморок")
            sev = maxi(sev, 3)
        elif hr <= 45.0:
            issues.append("брадикардия — слабость")
            sev = maxi(sev, 2)

    if sys < 80.0:
        issues.append("шок — критическая гипотония")
        sev = maxi(sev, 3)
    elif sys < 90.0:
        issues.append("гипотония")
        sev = maxi(sev, 2)
    elif sys >= 200.0:
        issues.append("гипертонический криз")
        sev = maxi(sev, 2)
    elif sys >= 180.0:
        issues.append("высокое АД")
        sev = maxi(sev, 1)

    if st >= THR.st_elev:
        issues.append("подъём ST — боль в груди, инфаркт")
        sev = maxi(sev, 3)
    if qtc_v > THR.qtc_torsades:
        issues.append("длинный QTc — риск Torsades/обморока")
        sev = maxi(sev, 2)

    var text := ""
    if issues.is_empty():
        text = "стабилен, бессимптомно"
    else:
        text = _join(issues, "; ")
    return {"text": text, "sev": sev}
