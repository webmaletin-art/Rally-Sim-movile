extends Node
## Controlador de una etapa del modo aventura (vive dentro de race.gd):
##   brief → (intro la primera vez) → salida de la estación (cinemática) → carrera contra el rival → llegada a la estación
##   (cinemática, guardado, guía, ajuste, habilidades) → siguiente etapa. Si el rival llega primero, se repite la etapa.
## El rival lo maneja la IA de siempre con un «director» que le ajusta el ritmo según la distancia: va adelante «al filo»,
## aprieta si lo apretás, pelea por recuperar el puesto si lo pasás, y nunca te choca a propósito.
## También: talleres (entrar/seguir, reparaciones que cuestan tiempo), daño del auto, cámaras guionadas.

const AdvRoute := preload("res://game/adventure/adv_route.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvHud := preload("res://game/adventure/adv_hud.gd")
const CinePilot := preload("res://game/adventure/cine_pilot.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const Profile := preload("res://game/data/profile.gd")

const CAMS := [1, 0, 6, 7] # tercera persona, piloto (casco), interior atrás (se ve el piloto y el copiloto) y capó

var r # race.gd
var track
var view # vista para medir el avance del jugador
var views: Array = []
var st: Dictionary # progreso guardado
var stage := 0
var S: Dictionary # datos de la etapa
var hud: Control
var state := ""
var t := 0.0 # tiempo en el estado actual
var time := 0.0 # reloj de la etapa
var s_start := 0.0
var s_end := 0.0
var prog: Array = [] # metros sobre la ruta de cada auto
var lock_input := true
var rival_ids: Array = []
var rival_info: Array = []
var vmax := 0.0
var intro_page := 0
var shot := {}
var shot_t := 0.0
var cam_i := 0 # índice en CAMS
var ws: Dictionary = {} # taller de esta etapa (evento) o vacío
var ws_choice := "" # "" sin elegir · "in" · "skip"
var ws_busy := ""
var ws_prog := 0.0
var ws_dur := 0.0
var dmg0: Dictionary # daño al empezar la etapa (para reintentar)
var station_tab := "sum"
var result := {}
var rival_mode: Array = [] # por rival: tiempo de "pelea" después de que lo pasaron
var finished := false
var station_name := ""
var tunnel_k := 0.0
var _dbg_go := OS.get_cmdline_user_args().has("--advgo") # prueba: sale solo de la estación
var _fx_base := {}

## Completa la configuración de la carrera antes de armarla (auto, clima, rivales)
static func prepare_cfg(cfg: Dictionary, profile: RefCounted) -> void:
	var stv := AdvData.state(profile) if profile != null else AdvData.default_state()
	var si: int = clampi(int(cfg.get("stage", stv["stage"])), 0, AdvRoute.STAGES.size() - 1)
	cfg["stage"] = si
	var S0: Dictionary = AdvRoute.STAGES[si]
	cfg["car"] = AdvData.CAR
	cfg["state"] = AdvData.car_state(stv)
	cfg["sky"] = {"dia": "day", "nublado": "overcast", "lluvia": "rain", "atardecer": "sunset", "ocaso": "dusk", "nieve": "snow"}.get(str(S0["sky"]), "day")
	cfg["ai"] = 2 if S0.has("rival2") else 1
	cfg["sim"] = "adv"
	cfg["track"] = "adv"
	if not cfg.has("back"):
		cfg["back"] = "adventure"
	var tr_len := 0.0
	var R = AdvRoute.get_route()
	var rg: Vector2i = R.stage_range(si)
	var g0 := maxi(0, rg.x - 100)
	tr_len = float(rg.x - g0) * AdvRoute.DS
	cfg["s_load"] = tr_len + (float(cfg.get("at", 0.0)) * R.stage_length(si))
	if cfg.get("intro", false) == true:
		cfg["s_load"] = tr_len + 2600.0

## Autos: el DR Bisonte del jugador (con su ajuste, habilidades y daño) y el/los rivales de la etapa
static func car_setups(race) -> Array:
	var cfg: Dictionary = race.cfg
	var profile: RefCounted = race.profile
	var stv := AdvData.state(profile) if profile != null else AdvData.default_state()
	var vehicles: Dictionary = race.vehicles
	var sa: Dictionary = race._sim_assists()
	var assists := {"abs": sa["abs"], "tc": sa["tc"], "stab": sa["stab"]}
	var pst: Dictionary = cfg["state"]
	var P: Dictionary = CarBuild.build_params(vehicles[AdvData.CAR], pst, assists)
	AdvData.apply_skills(P, stv)
	var dm := AdvData.damage_mul(stv)
	P["powerScale"] = float(P["powerScale"]) * float(dm["power"])
	P["gripFront"] = float(P["gripFront"]) * float(dm["grip"])
	P["gripRear"] = float(P["gripRear"]) * float(dm["grip"])
	var pname := str(profile.d["name"]) if profile != null else "Piloto"
	var out: Array = [{"params": P, "paint": Color(str(AdvData.PAINT["body"])), "rim": Color(str(AdvData.PAINT["rim"])), "name": pname, "finish": str(AdvData.PAINT["finish"]), "visual_type": str(vehicles[AdvData.CAR].get("visualType", AdvData.CAR)), "ai": {},
		"livery": int(AdvData.PAINT["livery"]), "accent": Color(str(AdvData.PAINT["accent"]))}]
	var S0: Dictionary = AdvRoute.STAGES[int(cfg["stage"])]
	var rv: Array = [S0["rival"]]
	if S0.has("rival2"):
		rv.append(S0["rival2"])
	for k in rv.size():
		var R0: Dictionary = rv[k]
		var cid := str(R0["car"])
		var rs := Profile.new_car_state(cid)
		var RP: Dictionary = CarBuild.build_params(vehicles[cid], rs, {"abs": true, "tc": 40.0, "stab": 30.0})
		RP["powerScale"] = float(RP["powerScale"]) * float(R0.get("power", 1.0))
		RP["gripFront"] = float(RP["gripFront"]) * float(R0.get("grip", 1.0))
		RP["gripRear"] = float(RP["gripRear"]) * float(R0.get("grip", 1.0))
		RP["vGov"] = 0.0
		out.append({"params": RP, "paint": Color(str(R0["paint"])), "rim": Color(0.12, 0.12, 0.14), "name": str(R0["name"]), "finish": "gloss",
			"visual_type": str(vehicles[cid].get("visualType", cid)), "ai": {"skill": float(R0["skill"]), "lane": 1.2 * (1.0 if k == 0 else -1.0), "aggr": 0.6},
			"livery": 1 + (int(cfg["stage"]) + k) % 5, "accent": Color(str(R0.get("accent", "#1b2a6b" if Color(str(R0["paint"])).get_luminance() > 0.6 else "#f5f5f2")))})
	return out

## Dónde se coloca cada auto al armar la etapa: [x, z, yaw]
static func start_pose(track, i: int, cfg: Dictionary) -> Array:
	var anchor: int = track.i_start
	if cfg.get("intro", false) == true:
		var si: int = track.idx_at(float(cfg["s_load"]))
		return track.pose_at(si + (0 if i == 0 else 40 + i * 12), 1.8 if i == 0 else -1.6)
	if cfg.has("at"):
		var sa: int = track.idx_at(float(cfg["s_load"]))
		return track.pose_at(sa + (0 if i == 0 else -24 - i * 8), 1.8 if i == 0 else -1.6) # el rival atrás
	var lat0: float = float(track.hwa[anchor]) + _lay_at(track, anchor)
	var lane := lat0 * 0.5 + 2.6 # entre las islas de surtidores
	if i == 0:
		return track.pose_at(anchor, lane)
	# el rival en la otra mano de la estación, un poco más adelante
	return track.pose_at(anchor + 3 + (i - 1) * 4, float(track.hwa[anchor]) + 2.0 + float(i - 1) * 0.5)

static func _lay_at(track, i: int) -> float:
	var m := 0.0
	for j in range(maxi(0, i - 30), mini(track.n, i + 31)):
		m = maxf(m, float(track.laya[j]))
	return m

# ───────────────────────── arranque ─────────────────────────
func setup(race) -> void:
	r = race
	track = r.track
	stage = int(r.cfg["stage"])
	S = AdvRoute.STAGES[stage]
	st = AdvData.state(r.profile) if r.profile != null else AdvData.default_state()
	st["started"] = true
	dmg0 = (r.cfg.get("dmg0", (st["damage"] as Dictionary).duplicate()) as Dictionary)
	r.cfg["dmg0"] = dmg0.duplicate()
	if OS.get_cmdline_user_args().has("--advdmg"):
		st["damage"] = {"motor": 0.5, "dir": 0.4, "susp": 0.3} # prueba: auto golpeado
		_dmg_dirty = true
	view = r.player_view()
	s_start = float(track.cum[track.i_start])
	s_end = float(track.cum[track.i_end])
	for k in r.cars.size():
		views.append(r.player_view() if k == 0 else track.make_view())
		prog.append(0.0)
	rival_ids.clear()
	for i in range(1, r.cars.size()):
		rival_ids.append(i)
		rival_mode.append(0.0)
	rival_info = [S["rival"]]
	if S.has("rival2"):
		rival_info.append(S["rival2"])
	for e in track.events:
		if str(e["t"]) == "workshop" and int(e["i"]) > track.i_start and int(e["i"]) < track.i_end:
			ws = e
		if str(e["t"]) == "station" and int(e["i"]) >= track.i_end - 2:
			station_name = str(e["name"])
	hud = AdvHud.new()
	hud.sfx = r.sfx
	r.controls.get_parent().add_child(hud)
	r.controls.get_parent().move_child(hud, r.controls.get_index())
	hud.choice.connect(_on_choice)
	if OS.get_cmdline_user_args().has("--nohud"):
		hud.visible = false
	var cols: Array = []
	for ri in r.rival_info:
		cols.append(ri["color"])
	hud.setup_map(track, cols, r.adv_alt)
	if r.race_hud != null:
		r.race_hud.minimap.visible = false
		r.race_hud.top.visible = false
	for c in r.cars:
		c.wall = 1.0 # límites por tramo (adv_track.wall_l / wall_r)
	for i in rival_ids:
		r.cars[i].driver.enabled = false
	cam_i = maxi(0, CAMS.find(int(r.profile.setting("camera")) if r.profile != null else 1))
	r.cam_rig.set_preset(CAMS[cam_i])
	if r.cfg.get("intro", false) == true:
		_enter("intro")
	elif r.cfg.has("at"):
		# prueba: largar en movimiento a mitad de etapa
		_enter("race")
		for i in rival_ids:
			r.cars[i].driver.enabled = true
	else:
		_enter("brief")

func _enter(s: String) -> void:
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--advlog"):
		print("AVENTURA %s → %s · t=%.1f · prog=%s · fin=%.0f" % [state, s, time, str(prog), s_end])
	state = s
	t = 0.0
	match s:
		"brief":
			lock_input = true
			_hold_player()
			hud.show_race_hud(false)
			hud.cine(true)
			hud.show_brief(stage, rival_info[0], int(st.get("tries", 0)) > 0 and int(st["stage"]) == stage)
			_station_shot(track.i_start)
			_controls(false)
		"intro":
			lock_input = true
			hud.show_race_hud(false)
			hud.cine(true)
			_controls(false)
			# el auto maneja solo por el campo; las cámaras van cambiando
			var pl = r.cars[0]
			pl.driver = AIDriver.new(track.make_view(), pl.phys, {"skill": 0.97, "lane": 1.2})
			# los rivales no aparecen en la presentación: quedan lejos, quietos
			r._finish_physics()
			for i in rival_ids:
				var rc = r.cars[i]
				var far: Array = track.pose_at(maxi(5, track.i_start - 60), 0.0)
				rc.place(float(far[0]), float(far[1]), float(far[2]))
				rc.restart_history(r.sim_t)
				rc.driver = CinePilot.Hold.new()
			_shot({"kind": "rig", "preset": 0})
			hud.big("", "", 0.1)
		"intro_pages":
			hud.fade_to(0.85)
			intro_page = 0
			hud.show_intro_page(0, 5)
		"depart":
			hud.clear_overlay()
			hud.fade_to(0.0)
			hud.cine(true)
			hud.show_race_hud(false)
			_controls(false)
			lock_input = true
			var pl = r.cars[0]
			var cp := CinePilot.new(track.make_view(), pl.phys)
			var s0 := s_start
			cp.lat0 = _player_lat()
			cp.lat1 = 1.8
			cp.s0 = s0 + 4.0
			cp.s1 = s0 + 70.0
			cp.v_max = 15.0
			pl.driver = cp
			for i in rival_ids:
				var rc = r.cars[i]
				rc.visual.visible = true
				var cr := CinePilot.new(track.make_view(), rc.phys)
				cr.lat0 = float(track.hwa[track.i_start]) + 2.0
				cr.lat1 = -1.6 if i == 1 else 1.6
				cr.s0 = s0 + 6.0
				cr.s1 = s0 + 55.0
				cr.v_max = 19.0
				rc.driver = cr
			# cámara: desde el costado del playón, viendo salir los autos
			var p: Vector3 = track.samples[track.i_start + 14]
			var L: Vector3 = track.laterals[track.i_start + 14]
			_shot({"kind": "fixed", "pos": p + L * (float(track.hwa[track.i_start]) + 1.0) * -1.0 + Vector3(0, 1.6, 0), "fov": 52.0})
			r.sfx.play("go")
		"race":
			hud.clear_overlay()
			hud.cine(false)
			hud.fade_to(0.0)
			hud.show_race_hud(true)
			_controls(true)
			lock_input = false
			_shot({})
			r.cam_rig.set_preset(CAMS[cam_i])
			var pl = r.cars[0]
			pl.driver = null
			if r.auto_player:
				# prueba: el auto del jugador lo maneja la IA
				var ap_track = r.adv_alt if (r.adv_alt != null and OS.get_cmdline_user_args().has("--advalt")) else track
				var ap := AIDriver.new(ap_track.make_view(), pl.phys, {"skill": 0.95, "lane": 0.0})
				var allp: Array = []
				for c in r.cars:
					allp.append(c.phys)
				ap.others = allp
				pl.driver = ap
			for i in rival_ids:
				var rc = r.cars[i]
				if not (rc.driver is AIDriver):
					var R0: Dictionary = rival_info[i - 1]
					var ad := AIDriver.new(track.make_view(), rc.phys, {"skill": float(R0["skill"]), "lane": 1.2 * (1.0 if i == 1 else -1.0), "aggr": 0.6})
					rc.driver = ad
				(rc.driver as AIDriver).enabled = true
				var all_phys: Array = []
				for c in r.cars:
					all_phys.append(c.phys)
				(rc.driver as AIDriver).others = all_phys
			if r.cfg.get("intro", false) == true:
				r.cfg.erase("intro")
		"arrive":
			hud.cine(true)
			hud.show_race_hud(false)
			hud.hide_prompt()
			_controls(false)
			lock_input = true
			var pl = r.cars[0]
			var cp := CinePilot.new(track.make_view(), pl.phys)
			var spd := sqrt(pl.phys.vx * pl.phys.vx + pl.phys.vz * pl.phys.vz)
			cp.lat0 = _player_lat()
			var lat0: float = float(track.hwa[track.i_end]) + _lay_at(track, track.i_end)
			cp.lat1 = lat0 * 0.5 + 2.6
			cp.s0 = prog[0] + 10.0
			cp.s1 = s_end - 8.0
			cp.s_stop = s_end
			cp.v_max = clampf(spd, 12.0, 26.0)
			cp.decel = 4.0
			pl.driver = cp
			# cámara junto a los surtidores viendo entrar el auto
			var i_cam: int = track.idx_at(s_end + 14.0)
			var p: Vector3 = track.samples[i_cam]
			var L: Vector3 = track.laterals[i_cam]
			_shot({"kind": "fixed", "pos": p + L * (lat0 + 3.0) + Vector3(0, 1.7, 0), "fov": 48.0, "track": true})
			hud.big("¡LLEGASTE PRIMERO!", station_name, 3.0, Kit_GOLD())
			r.sfx.play("finish")
		"fuel":
			# el auto quedó junto al surtidor: carga combustible (cámara bajita, mirando el surtidor y el auto)
			hud.big("⛽", "Cargando combustible…", 3.0, Kit_GOLD())
			r.sfx.play("coin")
			var ie: int = track.i_end
			var p: Vector3 = track.samples[ie]
			var L: Vector3 = track.laterals[ie]
			var tg: Vector3 = track.tangents[ie]
			var lat0: float = float(track.hwa[ie]) + _lay_at(track, ie)
			_shot({"kind": "dolly", "pos": p + L * (lat0 * 0.5 + 2.6 - 3.3) - tg * 5.5 + Vector3(0, float(track.cy[ie]) - p.y + 1.3, 0), "dir": tg * 0.25, "fov": 46.0})
		"station":
			hud.cine(true)
			station_tab = "sum"
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--advtab="):
					station_tab = a.substr(9) # prueba: abre esa pestaña
			_save_station()
			_show_station()
			_station_shot(track.i_end)
		"lost":
			hud.cine(true)
			hud.show_race_hud(false)
			hud.hide_prompt()
			_controls(false)
			lock_input = true
			_station_shot(track.i_end)
			st["tries"] = int(st.get("tries", 0)) + 1
			_save()
			hud.show_lost(str(rival_info[0]["name"]))
			r.sfx.play("beep")
		"ws_drive":
			hud.hide_prompt()
			hud.cine(true)
			hud.show_race_hud(false)
			_controls(false)
			lock_input = true
			var pl = r.cars[0]
			var cp := CinePilot.new(track.make_view(), pl.phys)
			var spd2 := sqrt(pl.phys.vx * pl.phys.vx + pl.phys.vz * pl.phys.vz)
			var wi: int = ws["i"]
			var s_ws := float(track.cum[wi])
			cp.lat0 = _player_lat()
			cp.lat1 = float(track.hwa[wi]) + _lay_at(track, wi) * 0.75
			cp.s0 = prog[0] + 8.0
			cp.s1 = s_ws - 6.0
			cp.s_stop = s_ws
			cp.v_max = clampf(spd2, 10.0, 24.0)
			cp.decel = 4.5
			pl.driver = cp
			var p: Vector3 = track.samples[mini(wi + 10, track.n - 1)]
			var L: Vector3 = track.laterals[mini(wi + 10, track.n - 1)]
			_shot({"kind": "fixed", "pos": p - L * 2.0 + Vector3(0, 2.0, 0), "fov": 50.0, "track": true})
		"ws_in":
			hud.fade_to(1.0)
		"workshop":
			_put_in_workshop()
			hud.fade_to(0.0)
			ws_busy = ""
			_show_ws()
		"ws_out":
			hud.fade_to(1.0)
			hud.clear_overlay()
		"done":
			hud.cine(true)

## Toma de la estación: desde la ruta, adelante y a la izquierda, viendo el auto bajo la marquesina (se acerca despacio)
func _station_shot(i: int) -> void:
	var j: int = mini(i + 9, track.n - 1)
	var p: Vector3 = track.samples[j]
	var L: Vector3 = track.laterals[j]
	var tg: Vector3 = track.tangents[j]
	var pos := p - L * 1.5 + Vector3(0, float(track.cy[j]) - p.y + 3.4, 0)
	_shot({"kind": "dolly", "pos": pos, "dir": -tg * 0.35 + L * 0.12, "fov": 50.0, "shift": 24.0})

func _controls(on: bool) -> void:
	r.controls.visible = on
	r.controls.set_process_input(on)
	r.controls.set_process_unhandled_input(on)
	if not on:
		r.controls.gas = 0.0
		r.controls.brake = 0.0
		r.controls.steer = 0.0

func _hold_player() -> void:
	r.cars[0].driver = CinePilot.Hold.new()

func _player_lat() -> float:
	var p = r.cars[0].phys
	view.nearest(p.px, p.pz)
	return view.r_lat

static func Kit_GOLD() -> Color:
	return Color(1.0, 0.82, 0.25)

# ───────────────────────── cada cuadro ─────────────────────────
func tick(dt: float) -> void:
	t += dt
	_update_prog()
	if _dbg_go and state == "brief" and t > 1.0:
		_enter("depart")
	match state:
		"intro":
			# guion de cámaras: piloto (6 s) → capó (3 s) → lejos girando (5 s) → dron que sube con el título (5 s)
			if t < 6.0:
				_shot({"kind": "rig", "preset": 0})
			elif t < 9.0:
				_shot({"kind": "rig", "preset": 7})
			elif t < 14.0:
				if str(shot.get("kind", "")) != "orbit":
					_shot({"kind": "orbit", "r": 13.0, "h": 2.0, "w": 0.22, "a0": 0.4})
			elif t < 19.5:
				if str(shot.get("kind", "")) != "drone":
					_shot({"kind": "drone"})
					hud.big("DREAM RACING", "La Ruta de los Sueños", 5.5, Color(1.0, 0.55, 0.15))
			else:
				_enter("intro_pages")
		"depart":
			time += dt
			if prog[0] > s_start + 62.0 or t > 12.0:
				hud.big("¡A CORRER!", str(S["name"]), 1.8, Kit_GOLD())
				r.sfx.play("go")
				_enter("race")
		"race":
			time += dt
			_director(dt)
			_check_workshop()
			_check_end()
		"arrive":
			time += 0.0
			var cp2 = r.cars[0].driver
			_rival_follow(dt)
			if (cp2 is CinePilot and cp2.done and t > 1.5) or t > 14.0:
				_enter("fuel")
		"fuel":
			_rival_follow(dt)
			if t > 3.2:
				_enter("station")
		"station", "lost":
			_rival_follow(dt)
		"ws_drive":
			time += dt
			_director(dt)
			var cp3 = r.cars[0].driver
			if (cp3 is CinePilot and cp3.done) or t > 12.0:
				_enter("ws_in")
		"ws_in":
			time += dt
			_director(dt)
			if t > 0.7:
				_enter("workshop")
		"workshop":
			time += dt
			_director(dt)
			if OS.get_cmdline_user_args().has("--advws"):
				# prueba: repara lo que haya y sale
				var dmg: Dictionary = st["damage"]
				if ws_busy == "" and t > 1.0:
					for part in ["motor", "dir", "susp"]:
						if float(dmg[part]) > 0.05:
							_on_choice("fix_" + part)
							break
					if ws_busy == "" and t > 3.0:
						_on_choice("ws_out")
			if ws_busy != "":
				ws_prog += dt / maxf(0.5, ws_dur)
				if ws_prog >= 1.0:
					(st["damage"] as Dictionary)[ws_busy] = 0.0
					ws_busy = ""
					r.sfx.play("buy")
					_apply_damage_now()
				_show_ws()
			elif int(t * 2.0) != int((t - dt) * 2.0):
				_show_ws()
		"ws_out":
			time += dt
			_director(dt)
			if t > 0.7:
				_leave_workshop()
	_update_hud(dt)
	_update_tunnel_light(dt)

## Avance de cada auto en metros del camino principal. Se mide lo que le falta hasta la estación (así, si el jugador toma
## el ramal de una bifurcación, su avance se compara bien con el del rival que va por el principal).
func _update_prog() -> void:
	for i in r.cars.size():
		var p = r.cars[i].snap
		var v = views[i]
		v.nearest(p.px, p.pz)
		var s := float(v.cum[v.r_idx]) + float(v.r_t) * (float(v.cum[mini(v.r_idx + 1, v.n - 1)]) - float(v.cum[v.r_idx]))
		var rem: float = float(v.cum[v.i_end]) - s
		prog[i] = s_end - rem
	var sp0 := sqrt(r.cars[0].snap.vx * r.cars[0].snap.vx + r.cars[0].snap.vz * r.cars[0].snap.vz)
	if state == "race":
		vmax = maxf(vmax, sp0 * 3.6)

## Director del rival. Hasta el 82 % de la etapa mantiene una distancia «al filo» adelante tuyo (te espera si vas despacio,
## aprieta hasta su máximo si lo alcanzás). En el tramo final corre al ritmo que venías llevando vos (medido contra el perfil
## de velocidad de la ruta) con un margen según la etapa: si en el final manejás mejor que antes, lo pasás.
## Si lo pasás, pelea un rato por recuperar el puesto; nunca choca a propósito (la IA esquiva al de adelante y al de al lado).
const EDGE := [-0.06, -0.05, -0.04, -0.03, -0.02, -0.015, -0.01, -0.005, 0.0, 0.01, 0.025, 0.035]
var hist: Array = [] # [tiempo, metros] del jugador
var _hist_t := 0.0
var ghost: Array = []
var tref := PackedFloat32Array() # tiempo de referencia acumulado (perfil de velocidad del rival) por muestra

func _build_tref() -> void:
	var d = r.cars[rival_ids[0]].driver
	if not (d is AIDriver):
		return
	var pv: PackedFloat32Array = (d as AIDriver).prof["v"]
	tref.resize(track.n)
	tref[0] = 0.0
	for i in range(1, track.n):
		var ds: float = float(track.cum[i]) - float(track.cum[i - 1])
		tref[i] = tref[i - 1] + ds / maxf(3.0, pv[i - 1])

## Ritmo del jugador relativo al perfil de la ruta (1 = el máximo del rival), en los últimos ~70 s
func _player_ratio() -> float:
	if hist.size() < 8 or tref.is_empty():
		return 0.85
	var a: Array = hist[0]
	var b: Array = hist[hist.size() - 1]
	var dt_p: float = float(b[0]) - float(a[0])
	if dt_p < 6.0:
		return 0.85
	var ia: int = track.idx_at(float(a[1]))
	var ib: int = track.idx_at(float(b[1]))
	var dt_ref: float = tref[ib] - tref[ia]
	return clampf(dt_ref / dt_p, 0.45, 1.15)

func _director(dt: float) -> void:
	var frac := clampf((prog[0] - s_start) / maxf(1.0, s_end - s_start), 0.0, 1.0)
	_hist_t += dt
	if _hist_t > 0.5:
		_hist_t = 0.0
		hist.append([time, prog[0]])
		while hist.size() > 140:
			hist.pop_front()
	if tref.is_empty():
		_build_tref()
	while ghost.size() < rival_ids.size():
		ghost.append(-1.0)
	var ratio := _player_ratio()
	var edge: float = EDGE[mini(stage, EDGE.size() - 1)]
	for k in rival_ids.size():
		var i: int = rival_ids[k]
		var d = r.cars[i].driver
		if not (d is AIDriver):
			continue
		var ad: AIDriver = d
		var gap: float = prog[i] - prog[0]
		var boss: bool = (rival_info[k] as Dictionary).get("boss", false) == true
		var b := 1.0
		if frac < 0.82:
			ghost[k] = -1.0
			if gap >= 0.0:
				var want := lerpf(70.0, 25.0, frac / 0.82) * (0.8 if boss else 1.0) + float(k) * 12.0
				b = clampf(1.0 + (want - gap) / 140.0, 0.55, 1.0)
				rival_mode[k] = maxf(0.0, rival_mode[k] - dt)
			else:
				# lo pasaste: pelea por recuperar el puesto un rato; después depende de vos
				if rival_mode[k] <= 0.0 and gap > -40.0:
					rival_mode[k] = 22.0
				rival_mode[k] = maxf(0.0, rival_mode[k] - dt)
				b = (1.04 if boss else 1.03) if (rival_mode[k] > 0.0 and gap > -70.0) else 1.0
		else:
			# tramo final: corre a tu ritmo (más el margen de la etapa)
			if float(ghost[k]) < 0.0:
				ghost[k] = prog[i]
			var gi: int = track.idx_at(float(ghost[k]))
			var gi2: int = mini(gi + 1, track.n - 1)
			var vref: float = (float(track.cum[gi2]) - float(track.cum[gi])) / maxf(0.01, tref[gi2] - tref[gi])
			ghost[k] = float(ghost[k]) + vref * ratio * (1.0 + edge + (0.012 if boss else 0.0)) * dt
			b = clampf(1.0 + (float(ghost[k]) - prog[i]) / 70.0, 0.55, 1.0)
			if gap < 0.0 and gap > -50.0:
				b = minf(1.03, b + 0.02) # pelea codo a codo
		ad.boost = lerpf(ad.boost, b, clampf(dt * 0.8, 0.0, 1.0))

## Mientras el jugador está en la estación o perdió: el rival sigue hasta la estación y estaciona
func _rival_follow(_dt: float) -> void:
	for k in rival_ids.size():
		var i: int = rival_ids[k]
		var rc = r.cars[i]
		if rc.driver is AIDriver and prog[i] > s_end - 170.0:
			var cp := CinePilot.new(track.make_view(), rc.phys)
			var lat0: float = float(track.hwa[track.i_end])
			cp.lat0 = (rc.driver as AIDriver).lat
			cp.lat1 = lat0 + 2.2 + float(k) * 0.6
			cp.s0 = prog[i] + 10.0
			cp.s1 = s_end - 20.0
			cp.s_stop = s_end + 10.0 + float(k) * 9.0
			var spd := sqrt(rc.phys.vx * rc.phys.vx + rc.phys.vz * rc.phys.vz)
			cp.v_max = clampf(spd, 12.0, 25.0)
			cp.decel = 4.0
			rc.driver = cp

func _check_end() -> void:
	# ¿llegó algún rival primero?
	for i in rival_ids:
		if prog[i] >= s_end - 2.0 and prog[i] > prog[0]:
			_enter("lost")
			return
	# el jugador: a 170 m de los surtidores, si va adelante, entra solo a la estación
	if prog[0] >= s_end - 170.0:
		var ahead := true
		for i in rival_ids:
			if prog[i] > prog[0] - 4.0:
				ahead = false
		if ahead:
			result = {"time": time, "margin": prog[0] - _best_rival_prog(), "vmax": vmax}
			_enter("arrive")
		elif prog[0] >= s_end - 30.0:
			# llegada pareja: gana el que va adelante en este momento
			if prog[0] > _best_rival_prog():
				result = {"time": time, "margin": prog[0] - _best_rival_prog(), "vmax": vmax}
				_enter("arrive")
			else:
				_enter("lost")

## Posición del jugador para el mundo del ramal (en metros de esa variante)
func alt_s() -> float:
	var v = views[0]
	var p = r.cars[0].snap
	if int(v.variant) >= 0:
		return float(v.cum[v.r_idx])
	return prog[0]

func _best_rival_prog() -> float:
	var m := -1e9
	for i in rival_ids:
		m = maxf(m, prog[i])
	return m

# ───────────────────────── taller ─────────────────────────
func _check_workshop() -> void:
	if ws.is_empty() or ws_choice == "skip" or ws_choice == "done":
		hud.hide_prompt()
		return
	var s_ws := float(track.cum[int(ws["i"])])
	var left: float = s_ws - float(prog[0])
	if left < -10.0:
		ws_choice = "done"
		hud.hide_prompt()
		return
	if left < 520.0 and ws_choice == "":
		hud.show_prompt("🔧 %s · a %d m" % [str(ws["name"]), int(left)])
		if OS.get_cmdline_user_args().has("--advws"):
			_on_choice("ws_in") # prueba: entra solo al taller
	if ws_choice == "in" and left < 140.0:
		_enter("ws_drive")
	elif ws_choice == "" and left < 40.0:
		ws_choice = "skip"
		hud.hide_prompt()

func _put_in_workshop() -> void:
	r._finish_physics()
	var wi: int = ws["i"]
	var lat0: float = float(track.hwa[wi]) + _lay_at(track, wi)
	var pose: Array = track.pose_at(wi, lat0 + 7.0)
	var pl = r.cars[0]
	_hold_player()
	pl.wall = 0.0
	# de trompa hacia el fondo del galpón (hacia la derecha del camino)
	var L: Vector3 = track.laterals[wi]
	pl.place(float(pose[0]), float(pose[1]), atan2(L.x, L.z))
	pl.restart_history(r.sim_t)
	# cámara adentro del galpón, mirando el auto con el portón de fondo
	var p: Vector3 = track.samples[wi]
	var tg: Vector3 = track.tangents[wi]
	var c := p + L * (lat0 + 12.0) + tg * 5.0 + Vector3(0, track.cy[wi] - p.y + 2.3, 0)
	_shot({"kind": "fixed", "pos": c, "fov": 62.0, "shift": 20.0})

func _leave_workshop() -> void:
	r._finish_physics()
	var wi: int = ws["i"]
	var lat0: float = float(track.hwa[wi]) + _lay_at(track, wi)
	var pose: Array = track.pose_at(wi + 2, lat0 - 1.5)
	var pl = r.cars[0]
	pl.place(float(pose[0]), float(pose[1]), float(pose[2]))
	pl.restart_history(r.sim_t)
	pl.wall = 1.0
	ws_choice = "done"
	hud.fade_to(0.0)
	hud.clear_overlay()
	# sale del playón hacia la ruta y devuelve el control
	var cp := CinePilot.new(track.make_view(), pl.phys)
	var s0 := float(track.cum[wi + 2])
	cp.lat0 = lat0 - 1.5
	cp.lat1 = 1.8
	cp.s0 = s0 + 2.0
	cp.s1 = s0 + 55.0
	cp.v_max = 16.0
	pl.driver = cp
	state = "depart_ws"
	t = 0.0
	_shot({"kind": "rig", "preset": 1})
	var tw := get_tree().create_timer(3.2)
	tw.timeout.connect(func() -> void:
		if state == "depart_ws":
			hud.big("¡DE VUELTA A LA RUTA!", "", 1.5, Kit_GOLD())
			_enter("race"))

func _show_ws() -> void:
	var gap: float = _best_rival_prog() - float(prog[0])
	hud.show_workshop(str(ws["name"]), st, ws_busy, ws_prog, gap)

## El daño cambió (golpe o reparación): se aplica al auto del jugador
func _apply_damage_now() -> void:
	r._finish_physics()
	var pl = r.cars[0]
	var V = pl.phys.V
	var dm := AdvData.damage_mul(st)
	if not _fx_base.has("power"):
		_fx_base = {"power": V.powerScale / maxf(0.01, float(AdvData.damage_mul({"damage": dmg0, "pull": 1.0})["power"])), "gf": V.gripFront / maxf(0.01, float(AdvData.damage_mul({"damage": dmg0, "pull": 1.0})["grip"])), "gr": V.gripRear / maxf(0.01, float(AdvData.damage_mul({"damage": dmg0, "pull": 1.0})["grip"]))}
	V.powerScale = float(_fx_base["power"]) * float(dm["power"])
	V.gripFront = float(_fx_base["gf"]) * float(dm["grip"])
	V.gripRear = float(_fx_base["gr"]) * float(dm["grip"])

## Golpe del jugador (contra el guardarraíl, otro auto o un aterrizaje fuerte): v = velocidad del impacto (m/s)
func on_hit(v: float, kind: String) -> void:
	if state != "race" or v < 2.5:
		return
	var armor := float((st["skills"] as Dictionary).get("armor", 0))
	var k := (v - 2.5) * 0.018 * (1.0 - 0.12 * armor)
	var d: Dictionary = st["damage"]
	match kind:
		"wall":
			d["dir"] = minf(1.0, float(d["dir"]) + k * 0.6)
			d["susp"] = minf(1.0, float(d["susp"]) + k * 0.5)
		"car":
			d["motor"] = minf(1.0, float(d["motor"]) + k * 0.5)
			d["dir"] = minf(1.0, float(d["dir"]) + k * 0.3)
		_:
			d["susp"] = minf(1.0, float(d["susp"]) + k * 0.4)
	if float(st.get("pull", 0.0)) == 0.0 or randf() < 0.1:
		st["pull"] = 1.0 if randf() < 0.5 else -1.0
	if k > 0.03:
		hud.toast("💥 Golpe: el auto tiene daño")
	_dmg_dirty = true

var _dmg_dirty := false

## Antes de cada lote de física (con los hilos parados): daño y volante que tira
func pre_physics() -> void:
	if _dmg_dirty:
		_dmg_dirty = false
		_apply_damage_now()

func steer_pull() -> float:
	if state != "race":
		return 0.0
	return float(AdvData.damage_mul(st)["pull"])

# ───────────────────────── cámara ─────────────────────────
func _shot(s: Dictionary) -> void:
	if s.get("kind", "") == "rig":
		r.cam_rig.set_preset(int(s["preset"]))
		shot = s
		return
	shot = s
	shot_t = 0.0
	if not s.is_empty():
		r.cam_rig.set_preset(1) # que el habitáculo no se esconda (cámara de afuera)

## Devuelve true si la cámara la maneja la aventura este cuadro
var _dbg_top := 0.0
func camera(dt: float) -> bool:
	if _dbg_top == 0.0:
		_dbg_top = -1.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--advtop="):
				_dbg_top = float(a.substr(9)) # prueba: cámara desde arriba a esa altura
	if _dbg_top > 0.0:
		var sp = r.cars[0].snap
		r.cam.position = Vector3(sp.px, sp.py + _dbg_top, sp.pz) + Vector3(sin(sp.yaw), 0, cos(sp.yaw)) * (_dbg_top * 0.6)
		r.cam.look_at(Vector3(sp.px, sp.py, sp.pz) + Vector3(sin(sp.yaw), 0, cos(sp.yaw)) * (_dbg_top * 0.61), Vector3(sin(sp.yaw), 0, cos(sp.yaw)))
		r.cam.fov = 70.0
		r.cam.far = 3000.0
		r.env.fog_enabled = false
		return true
	if shot.is_empty() or str(shot.get("kind", "")) == "rig":
		return false
	shot_t += dt
	var p = r.cars[0].snap
	var cpos := Vector3(p.px, p.py, p.pz)
	var cam: Camera3D = r.cam
	cam.near = 0.15
	_camera_kind(p, cpos, cam)
	# con un panel a la izquierda, el auto se corre a la derecha de la pantalla
	var sh := float(shot.get("shift", 0.0))
	if sh != 0.0:
		cam.rotate_y(deg_to_rad(sh))
	return true

func _camera_kind(p, cpos: Vector3, cam: Camera3D) -> void:
	match str(shot["kind"]):
		"orbit":
			var a: float = float(shot.get("a0", 0.0)) + float(shot.get("w", 0.2)) * shot_t + float(p.yaw)
			var rr := float(shot.get("r", 9.0))
			var pos := cpos + Vector3(sin(a) * rr, float(shot.get("h", 2.5)), cos(a) * rr)
			cam.position = pos
			cam.look_at(cpos + Vector3(0, 0.6, 0))
			cam.fov = 50.0
		"fixed":
			var pos2: Vector3 = shot["pos"]
			cam.position = pos2
			cam.look_at(cpos + Vector3(0, 0.6, 0))
			cam.fov = float(shot.get("fov", 50.0))
		"dolly":
			var p0: Vector3 = shot["pos"]
			var dv: Vector3 = shot["dir"]
			cam.position = p0 + dv * minf(shot_t, 25.0)
			cam.look_at(cpos + Vector3(0, 0.8, 0))
			cam.fov = float(shot.get("fov", 50.0))
		"drone":
			var k := clampf(shot_t / 5.5, 0.0, 1.0)
			var fwd := Vector3(sin(p.yaw), 0, cos(p.yaw))
			var pos3 := cpos - fwd * lerpf(8.0, 30.0, k) + Vector3(0, lerpf(3.0, 34.0, k * k), 0)
			cam.position = pos3
			cam.look_at(cpos + fwd * lerpf(4.0, 60.0, k) + Vector3(0, 0.5, 0))
			cam.fov = 55.0

func next_camera() -> String:
	cam_i = (cam_i + 1) % CAMS.size()
	r.cam_rig.set_preset(CAMS[cam_i])
	if r.profile != null:
		r.profile.set_setting("camera", CAMS[cam_i])
	return r.cam_rig.cam_name()

## Túneles: adentro baja la luz del sol y del cielo (las lámparas siguen prendidas)
func _update_tunnel_light(dt: float) -> void:
	var cp: Vector3 = r.cam.global_position
	view.nearest(cp.x, cp.z)
	var inside: bool = track.in_tunnel(view.r_idx) and absf(view.r_lat) < float(track.hwa[view.r_idx]) + 2.0 and cp.y < float(track.cy[view.r_idx]) + 7.0
	tunnel_k = move_toward(tunnel_k, 1.0 if inside else 0.0, dt * 1.6)
	r.set_tunnel_light(tunnel_k)

# ───────────────────────── pantallas ─────────────────────────
func _update_hud(_dt: float) -> void:
	var gap: float = _best_rival_prog() - float(prog[0])
	var col: Color = r.rival_info[1]["color"] if r.rival_info.size() > 1 else Color.RED
	var gap2 := 0.0
	var col2 := Color(0, 0, 0, 0)
	if rival_ids.size() > 1:
		gap = prog[rival_ids[0]] - prog[0]
		gap2 = prog[rival_ids[1]] - prog[0]
		col2 = r.rival_info[2]["color"]
	hud.set_gap(gap, col, str(rival_info[0]["name"]).split(" ")[0] if str(rival_info[0]["name"]).length() > 14 else str(rival_info[0]["name"]), gap2, col2)
	hud.set_info("ETAPA %d/%d · %s" % [stage + 1, AdvRoute.STAGES.size(), str(S["name"])], time, s_end - prog[0])
	hud.set_damage(st["damage"])
	var L: Array = []
	for c in r.cars:
		L.append([c.snap.px, c.snap.pz])
	hud.set_cars(L)

func _show_station() -> void:
	hud.show_station(station_tab, {"stage": stage, "time": result.get("time", time), "margin": result.get("margin", 0.0), "vmax": result.get("vmax", vmax), "station": station_name}, st)

func _save() -> void:
	if r.profile != null:
		r.profile.d["adv"] = st
		r.profile.save()

func _save_station() -> void:
	if finished:
		return
	finished = true
	if int(st["stage"]) <= stage:
		st["stage"] = stage + 1
		st["points"] = int(st["points"]) + AdvData.POINTS_PER_STAGE
	st["tries"] = 0
	var best: Dictionary = st["best"]
	var key := str(stage)
	if not best.has(key) or float(best[key]) > float(result.get("time", time)):
		best[key] = float(result.get("time", time))
	if stage >= AdvRoute.STAGES.size() - 1:
		st["done"] = true
	_save()

func _on_choice(id: String) -> void:
	match id:
		"go":
			_enter("depart")
		"tune":
			station_tab = "tune"
			_brief_tune()
		"brief_back":
			_enter("brief")
		"intro_next":
			intro_page += 1
			if intro_page >= 5:
				st["intro"] = true
				_save()
				_restart_at_station()
			else:
				hud.show_intro_page(intro_page, 5)
		"intro_prev":
			intro_page = maxi(0, intro_page - 1)
			hud.show_intro_page(intro_page, 5)
		"next":
			_save()
			var c := {"type": "adventure", "stage": stage + 1, "back": "adventure"}
			r.restart_with(c)
		"finish":
			_finish_adventure()
		"save_quit", "quit":
			_save()
			r._quit()
		"retry":
			st["damage"] = dmg0.duplicate()
			_save()
			var c2 := {"type": "adventure", "stage": stage, "back": "adventure", "dmg0": dmg0.duplicate()}
			r.restart_with(c2)
		"apply_guide":
			var G: Dictionary = AdvData.GUIDES[mini(stage + 1, AdvData.GUIDES.size() - 1)]
			var tune: Dictionary = st["tune"]
			for k in (G["preset"] as Dictionary):
				tune[k] = float(G["preset"][k])
			if G.has("tires"):
				st["tires"] = str(G["tires"])
			_save()
			hud.toast("✔ Ajuste recomendado aplicado")
			station_tab = "tune"
			_show_station()
		"tune_reset":
			st["tune"] = {}
			st["tires"] = "street"
			_save()
			_refresh_tab()
		"ws_in":
			ws_choice = "in"
			hud.show_prompt("🔧 Entrando al taller…")
		"ws_skip":
			ws_choice = "skip"
			hud.hide_prompt()
		"ws_out":
			if ws_busy == "":
				_save()
				_enter("ws_out")
		_:
			if id.begins_with("tab_"):
				station_tab = id.substr(4)
				_save()
				_show_station()
			elif id.begins_with("tire_"):
				st["tires"] = id.substr(5)
				_save()
				_refresh_tab()
			elif id.begins_with("skill_"):
				var sid := id.substr(6)
				var sk: Dictionary = st["skills"]
				var lvl := int(sk.get(sid, 0))
				var c3 := AdvData.cost(lvl + 1)
				if lvl < AdvData.MAX_LEVEL and int(st["points"]) >= c3:
					sk[sid] = lvl + 1
					st["points"] = int(st["points"]) - c3
					_save()
					r.sfx.play("buy")
				_refresh_tab()
			elif id.begins_with("fix_"):
				var part := id.substr(4)
				var v := float((st["damage"] as Dictionary)[part])
				var base := {"motor": 9.0, "dir": 6.0, "susp": 7.0}
				ws_busy = part
				ws_prog = 0.0
				ws_dur = ceilf(float(base[part]) * v / 0.5 + 2.0)
				_show_ws()

func _refresh_tab() -> void:
	if state == "brief":
		_brief_tune()
	else:
		_show_station()

## Ajuste desde la pantalla de salida (antes de la etapa): se aplica reiniciando la etapa con el auto nuevo
func _brief_tune() -> void:
	state = "brief"
	var body: VBoxContainer = hud._panel("⚙ AJUSTE DEL AUTO", 0.6)
	hud._text(body, "Los cambios se aplican al salir de la estación.", 16, Color(0.62, 0.68, 0.76))
	hud.tune_page(body, st)
	hud._row_buttons(body, [["✔ LISTO", "tune_done", true]])
	if not hud.choice.is_connected(_tune_done):
		hud.choice.connect(_tune_done)

func _tune_done(id: String) -> void:
	if id != "tune_done":
		return
	_save()
	# reinicia la etapa para armar el auto con el ajuste nuevo
	var c := {"type": "adventure", "stage": stage, "back": "adventure", "dmg0": dmg0.duplicate()}
	r.restart_with(c)

func _restart_at_station() -> void:
	var c := {"type": "adventure", "stage": stage, "back": "adventure"}
	r.restart_with(c)

func _finish_adventure() -> void:
	st["done"] = true
	_save()
	if r.profile != null:
		var pf: RefCounted = r.profile
		if not pf.owns(AdvData.CAR):
			pf.give(AdvData.CAR)
		var cs: Dictionary = pf.d["owned"][AdvData.CAR]
		cs["paint"] = AdvData.PAINT.duplicate()
		pf.earn(50000.0)
		pf.save()
	hud.show_final({"reward": 50000})
