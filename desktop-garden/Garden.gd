extends Control
## All combat runs on a fixed timestep; presentation never decides damage.
const STEP = 1.0 / 60.0
const ORIGIN = Vector2(346, 224)
const CELL = Vector2(126, 110)
const ROWS = 5
const COLS = 9
const DATA = {
 "sunflower": {"name":"向日葵", "cost":50, "cool":7.5, "hp":300.0, "rate":24.0, "damage":0.0, "color":"f7c94e", "desc":"每 24 秒产生 25 阳光。"},
 "pea": {"name":"豌豆射手", "cost":75, "cool":7.5, "hp":300.0, "rate":1.425, "damage":20.0, "color":"83c969", "desc":"发射 20 伤害的直线豌豆。"},
 "wallnut": {"name":"坚果", "cost":50, "cool":20.0, "hp":4000.0, "rate":99.0, "damage":0.0, "color":"c59c68", "desc":"4000 生命，阻挡前方僵尸。"},
 "snowpea": {"name":"寒冰射手", "cost":175, "cool":5.0, "hp":300.0, "rate":1.425, "damage":20.0, "color":"8bdaec", "desc":"50% 概率冻结 1 秒，否则减速 50% 10 秒。原型冻结时长，待对照。"},
 "sweetpea": {"name":"甜豌豆", "cost":350, "cool":20.0, "hp":300.0, "rate":1.425, "damage":40.0, "color":"f38fbe", "desc":"直击 40，附近溅射 10；减速 50% 持续 2 秒。大招立即发射穿透糖弹。"},
 "megapuff": {"name":"机枪喷", "cost":0, "cool":7.5, "hp":150.0, "rate":1.425, "damage":20.0, "color":"b8a1e3", "desc":"每轮连射 4 发，射程 3 格；存活 30 秒。普通小喷仍可在后续加入。"},
 "torchwood": {"name":"火炬树桩", "cost":175, "cool":5.0, "hp":2000.0, "rate":99.0, "damage":0.0, "color":"ed995e", "desc":"普通豌豆经过后伤害翻倍。火焰命中冰减速目标增伤 25%，随后解冻。"},
 "squash": {"name":"倭瓜", "cost":50, "cool":20.0, "hp":1000.0, "rate":99.0, "damage":600.0, "color":"a3c45f", "desc":"近距离触发，两次砸击，各 600 伤害，随后离场。"}
}
const CARDS = ["sunflower", "pea", "wallnut", "snowpea", "sweetpea", "megapuff", "torchwood", "squash"]
var font = preload("res://assets/ui-font.ttc")
var sweet_texture = preload("res://assets/sweetpea.png")
var mega_texture = preload("res://assets/megapuff.png")
var sweet_region: Rect2
var mega_region: Rect2
var plants: Array = []
var zombies: Array = []
var bullets: Array = []
var effects: Array = []
var suns: Array = []
var mowers: Array = []
var cooldowns: Dictionary = {}
var pending: Array = []
var rng = RandomNumberGenerator.new()
var selected = ""
var shovel = false
var food_mode = false
var sun = 275
var food = 3
var phase = "prep"
var paused = false
var help_open = false
var practice = false
var sim_time = 0.0
var accumulator = 0.0
var wave = 0
var wave_timer = 8.0
var sky_timer = 7.0
var next_id = 0
var kills = 0
var wins = 0
var message = "先布置防线，准备好后点击「开始防守」"
var message_time = 6.0
var hover = Vector2(-100, -100)
var elapsed_ui = 0.0
var confirm_restart = false
var profile_path = "user://desktop_profile.cfg"

func _ready():
 sweet_region = sweet_texture.get_image().get_used_rect()
 mega_region = mega_texture.get_image().get_used_rect()
 rng.seed = 82917
 var cfg = ConfigFile.new()
 if cfg.load(profile_path) == OK:
  wins = int(cfg.get_value("progress", "wins", 0))
 reset_game()

func reset_game():
 plants.clear(); zombies.clear(); bullets.clear(); effects.clear(); suns.clear(); pending.clear(); mowers.clear()
 cooldowns.clear()
 for key in CARDS: cooldowns[key] = 0.0
 for r in range(ROWS): mowers.append({"row":r, "x":ORIGIN.x-46, "state":"ready"})
 sun = 1000 if practice else 275
 food = 3; selected = ""; shovel = false; food_mode = false
 phase = "prep"; paused = false; wave = 0; sim_time = 0; wave_timer = 8; sky_timer = 7; kills = 0; accumulator = 0; next_id = 0
 message = "先布置防线，准备好后点击「开始防守」"; message_time = 6

func _process(delta):
 elapsed_ui += delta
 hover = get_local_mouse_position()
 if not paused and not help_open and phase in ["prep", "play"]:
  accumulator += minf(delta, 0.20)
  while accumulator >= STEP:
   tick(STEP)
   accumulator -= STEP
 queue_redraw()

func cell_at(pos: Vector2) -> Vector2i:
 return Vector2i(floori((pos.x-ORIGIN.x)/CELL.x), floori((pos.y-ORIGIN.y)/CELL.y))

func center_at(col, row) -> Vector2:
 return ORIGIN + Vector2((col+0.5)*CELL.x, (row+0.5)*CELL.y)

func plant_at(col, row):
 for p in plants:
  if p.col == col and p.row == row and p.hp > 0: return p
 return null

func notify(text_value):
 message = text_value; message_time = 4.0

func choose(key):
 selected = key; shovel = false; food_mode = false

func place(key, col, row) -> bool:
 if phase not in ["prep", "play"] or col < 0 or col >= COLS or row < 0 or row >= ROWS: return false
 if plant_at(col, row) != null: return false
 var def = DATA[key]
 if sun < def.cost or cooldowns[key] > 0: return false
 sun -= def.cost; cooldowns[key] = def.cool
 next_id += 1
 plants.append({"id":next_id, "key":key, "col":col, "row":row, "hp":def.hp, "maxhp":def.hp, "timer":2.0 if key == "sunflower" else 0.3, "age":0.0, "flash":0.0, "burst":0, "burst_timer":0.0, "squash_hits":0, "squash_time":-1.0})
 return true

func _gui_input(event):
 if event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_RIGHT:
   selected = ""; shovel = false; food_mode = false; return
  if event.button_index != MOUSE_BUTTON_LEFT: return
  var pos = event.position
  if help_open:
   help_open = false; return
  if Rect2(1278, 34, 86, 44).has_point(pos): paused = not paused; return
  if Rect2(1378, 34, 86, 44).has_point(pos): help_open = true; return
  if Rect2(1478, 34, 86, 44).has_point(pos):
   if confirm_restart or phase in ["won", "lost", "prep"]: reset_game(); confirm_restart = false
   else: confirm_restart = true; notify("再点一次「重开」开始新的一局")
   return
  if paused: return
  if phase in ["won", "lost"]:
   if Rect2(650, 520, 300, 64).has_point(pos): reset_game()
   return
  for s in suns:
   if s.ttl > 0 and s.pos.distance_to(pos) < 34:
    sun += 25; s.ttl = -1; spark(pos, Color("ffdc72"), 7); return
  for i in range(CARDS.size()):
   if card_rect(i).has_point(pos): choose(CARDS[i]); return
  if Rect2(28, 726, 128, 48).has_point(pos): shovel = not shovel; food_mode = false; selected = ""; return
  if Rect2(168, 726, 128, 48).has_point(pos): food_mode = not food_mode; shovel = false; selected = ""; return
  if phase == "prep" and Rect2(1114, 800, 364, 62).has_point(pos): start_game(); return
  if phase == "prep" and Rect2(30, 804, 264, 40).has_point(pos): practice = not practice; reset_game(); return
  var cell = cell_at(pos)
  if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS: return
  var p = plant_at(cell.x, cell.y)
  if shovel:
   if p != null: p.hp = 0; spark(center_at(cell.x, cell.y), Color("c8e6bb"), 5)
  elif food_mode:
   if p != null: use_food(p)
  elif selected != "":
   if not place(selected, cell.x, cell.y): notify("阳光不足、卡片冷却中，或这个格子已有植物")

func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_ESCAPE:
  if help_open: help_open = false
  elif selected != "" or shovel or food_mode: selected = ""; shovel = false; food_mode = false
  else: paused = not paused
 elif event.keycode in [KEY_SPACE, KEY_P]: paused = not paused
 elif event.keycode == KEY_X: shovel = not shovel; selected = ""; food_mode = false
 elif event.keycode == KEY_F: food_mode = not food_mode; selected = ""; shovel = false
 elif event.keycode == KEY_ENTER and phase == "prep": start_game()
 elif event.keycode >= KEY_1 and event.keycode <= KEY_8: choose(CARDS[event.keycode-KEY_1])
 elif event.keycode == KEY_F11:
  var mode = DisplayServer.window_get_mode()
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func start_game():
 phase = "play"; wave_timer = 4.0; notify("防线已就位。僵尸即将到来！")

func add_zombie(row, kind = "basic", xpos = 1515.0):
 var stats = {"basic":[200.0,16.0,80.0], "cone":[560.0,14.0,85.0], "bucket":[1280.0,12.0,90.0], "giant":[3600.0,9.0,180.0]}[kind]
 next_id += 1
 var z = {"id":next_id, "row":row, "kind":kind, "x":xpos, "hp":stats[0], "maxhp":stats[0], "speed":stats[1], "bite":stats[2], "slow":0.0, "freeze":0.0, "stalled":0.0, "attack":0.0, "flash":0.0, "anim":rng.randf_range(0,6.28)}
 zombies.append(z)
 return z

func make_wave():
 wave += 1
 var count = 3+wave
 for i in range(count):
  var kind = "basic"
  if wave >= 3 and i % 3 == 1: kind = "cone"
  if wave >= 5 and i % 4 == 2: kind = "bucket"
  if wave in [6, 9] and i == count-1: kind = "giant"
  pending.append({"at":sim_time+i*1.65, "row":rng.randi_range(0,4), "kind":kind})
 wave_timer = 26.0 if wave % 3 else 32.0
 notify("一大波僵尸！第 %d 面旗" % int(ceil(wave/3.0)) if wave % 3 == 0 else "第 %d / 9 波" % wave)

func tick(dt):
 sim_time += dt
 message_time -= dt
 for key in cooldowns: cooldowns[key] = maxf(0, cooldowns[key]-dt)
 for fx in effects:
  fx.ttl -= dt; fx.pos += fx.vel*dt
 effects = effects.filter(func(x): return x.ttl > 0)
 for s in suns:
  s.ttl -= dt; s.pos.y = minf(s.target_y, s.pos.y+50*dt)
 suns = suns.filter(func(x): return x.ttl > 0)
 if phase != "play": return
 sky_timer -= dt
 if sky_timer <= 0:
  sky_timer = 8.0; spawn_sun(Vector2(rng.randf_range(420,1400), 120), rng.randf_range(300,700))
 wave_timer -= dt
 if wave_timer <= 0 and wave < 9: make_wave()
 for spawn in pending:
  if spawn.at <= sim_time:
   add_zombie(spawn.row, spawn.kind); spawn.at = INF
 pending = pending.filter(func(x): return x.at != INF)
 for p in plants:
  if p.hp <= 0: continue
  p.age += dt; p.flash = maxf(0,p.flash-dt); p.timer -= dt
  if p.key == "megapuff" and p.age >= 30:
   p.hp = 0; spark(center_at(p.col,p.row),Color("cdb7ec"),8); continue
  if p.key == "sunflower" and p.timer <= 0:
   p.timer = DATA.sunflower.rate
   var spot = center_at(p.col,p.row)
   spawn_sun(spot-Vector2(0,44),spot.y+8)
  elif p.key == "squash": tick_squash(p,dt)
  elif p.key in ["pea","snowpea","sweetpea","megapuff"]:
   var pos = center_at(p.col,p.row)
   var range_px = CELL.x*3 if p.key == "megapuff" else 1700.0
   var target = zombies.any(func(z): return z.hp > 0 and z.row == p.row and z.x > pos.x-25 and z.x-pos.x < range_px)
   if target and p.timer <= 0:
    p.timer = DATA[p.key].rate
    if p.key == "megapuff": p.burst = 4; p.burst_timer = 0.0
    else: fire(p)
   if p.burst > 0:
    p.burst_timer -= dt
    if p.burst_timer <= 0:
     fire(p); p.burst -= 1; p.burst_timer = 0.085
 for b in bullets: tick_bullet(b,dt)
 bullets = bullets.filter(func(b): return b.alive and b.x < 1560 and b.travel < b.range)
 for z in zombies:
  if z.hp <= 0: continue
  z.flash = maxf(0,z.flash-dt); z.slow = maxf(0,z.slow-dt); z.stalled = maxf(0,z.stalled-dt); z.freeze = maxf(0,z.freeze-dt); z.anim += dt
  if z.freeze > 0: continue
  var victim = null
  for p in plants:
   if p.hp > 0 and p.row == z.row and absf(z.x-center_at(p.col,p.row).x) < 47:
    victim = p; break
  var speed_factor = 0.5 if z.slow > 0 or z.stalled > 0 else 1.0
  if victim != null:
   victim.hp -= z.bite*dt*speed_factor; z.attack = 1
  else:
   z.x -= z.speed*dt*speed_factor; z.attack = 0
  if z.x < ORIGIN.x-15:
   var mower = mowers[z.row]
   if mower.state == "ready": mower.state = "active"; notify("第 %d 行的割草机出动！" % (z.row+1))
   elif mower.state == "spent": phase = "lost"
 for mower in mowers:
  if mower.state == "active":
   mower.x += 720*dt
   for z in zombies:
    if z.row == mower.row and z.x <= mower.x+42 and z.hp > 0: hurt(z,z.hp,Color("ffdf78"))
   if mower.x > 1550: mower.state = "spent"
 plants = plants.filter(func(p): return p.hp > 0)
 zombies = zombies.filter(func(z): return z.hp > 0)
 if wave == 9 and pending.is_empty() and zombies.is_empty() and phase == "play":
  phase = "won"; wins += 1; save_progress()

func tick_squash(p,dt):
 var x = center_at(p.col,p.row).x
 if p.squash_time < 0:
  if zombies.any(func(z): return z.hp > 0 and z.row == p.row and absf(z.x-x) < 115): p.squash_time = 0.4
 else:
  p.squash_time -= dt
  if p.squash_time <= 0:
   for z in zombies:
    if z.hp > 0 and z.row == p.row and absf(z.x-x) < 150: hurt(z,600,Color("c4e894"))
   spark(Vector2(x,center_at(p.col,p.row).y+20),Color("c4e894"),12)
   p.squash_hits += 1; p.squash_time = 0.55
   if p.squash_hits >= 2: p.hp = 0

func spawn_sun(pos,target_y):
 suns.append({"pos":pos,"target_y":target_y,"ttl":12.0})

func fire(p, power = false):
 var pos = center_at(p.col,p.row)
 var damage = 1800.0 if power else DATA[p.key].damage
 var range_px = 3*CELL.x if p.key == "megapuff" and not power else 1800.0
 var b = {"x":pos.x+32, "y":pos.y-21, "row":p.row, "origin":pos.x, "travel":0.0, "range":range_px, "damage":damage, "kind":p.key, "frozen":p.key == "snowpea" and rng.randf() < 0.5, "fire":false, "power":power, "hit":[], "alive":true}
 bullets.append(b); p.flash = 0.16

func tick_bullet(b,dt):
 if not b.alive: return
 var old_x = b.x
 b.x += 420*dt; b.travel += 420*dt
 if b.kind == "pea" and not b.fire:
  for p in plants:
   var px = center_at(p.col,p.row).x
   if p.hp > 0 and p.key == "torchwood" and p.row == b.row and old_x <= px and b.x >= px:
    b.fire = true; b.damage *= 2; break
 # Swept collision, sorted front-to-back: no tunnelling at low frame rates.
 var candidates = zombies.filter(func(z): return z.hp > 0 and z.row == b.row and z.x+24 >= old_x and z.x-24 <= b.x and z.id not in b.hit)
 candidates.sort_custom(func(a,c): return a.x < c.x)
 for z in candidates:
  var dmg = b.damage
  if b.fire:
   if z.slow > 0: dmg *= 1.25
   z.slow = 0; z.freeze = 0
  elif b.kind == "snowpea":
   if b.frozen: z.freeze = maxf(z.freeze,1.0)
   else: z.slow = maxf(z.slow,10.0)
  elif b.kind == "sweetpea" and not b.power:
   z.stalled = maxf(z.stalled,2.0)
   for nearby in zombies:
    if nearby.id != z.id and nearby.hp > 0 and absf(nearby.x-z.x) < 95 and abs(nearby.row-z.row) <= 1:
     hurt(nearby,10,Color("f6a0d1"))
  hurt(z,dmg,Color("ffb577") if b.fire else Color("f5f3c9"))
  b.hit.append(z.id)
  if not b.power:
   b.alive = false; break

func hurt(z,damage,color_value):
 var alive_before = z.hp > 0
 z.hp -= damage; z.flash = 0.12
 var spot = Vector2(z.x,center_at(0,z.row).y-25)
 effects.append({"pos":spot,"vel":Vector2(0,-25),"ttl":0.65,"max":0.65,"text":str(snappedf(damage,0.1)),"color":color_value,"size":18})
 if alive_before and z.hp <= 0:
  kills += 1; spark(spot,Color("a9c4a3"),5)

func spark(pos,color_value,count):
 for i in range(count): effects.append({"pos":pos,"vel":Vector2(rng.randf_range(-55,55),rng.randf_range(-70,35)),"ttl":0.45,"max":0.45,"text":"","color":color_value,"size":rng.randf_range(2,5)})

func use_food(p):
 if food <= 0: notify("本局能量豆已用完"); return
 food -= 1; food_mode = false
 if p.key in ["pea","snowpea","sweetpea","megapuff"]: fire(p,true)
 elif p.key == "sunflower":
  for i in range(6):
   var spot = center_at(p.col,p.row)+Vector2((i-2.5)*16,-30)
   spawn_sun(spot,spot.y+60)
 else:
  p.hp = p.maxhp; spark(center_at(p.col,p.row),Color("bde99c"),14)
 notify("能量豆发动！")

func save_progress():
 var cfg = ConfigFile.new(); cfg.set_value("progress","wins",wins); cfg.save(profile_path)

func card_rect(i) -> Rect2:
 return Rect2(28+(i%2)*140,224+int(i/2)*118,128,104)

func box(rect: Rect2, color_value: Color, radius = 12, border = Color.TRANSPARENT):
 var style = StyleBoxFlat.new(); style.bg_color = color_value
 style.corner_radius_top_left=radius; style.corner_radius_top_right=radius; style.corner_radius_bottom_left=radius; style.corner_radius_bottom_right=radius
 if border.a > 0:
  style.border_color=border; style.set_border_width_all(2)
 draw_style_box(style,rect)

func label_at(text_value,pos,size=20,color_value=Color("e6eddc")):
 draw_string(font,pos,str(text_value),HORIZONTAL_ALIGNMENT_LEFT,-1,size,color_value)

func _draw():
 draw_rect(Rect2(0,0,1600,900),Color("111e1b"))
 box(Rect2(18,18,1564,94),Color("1e322b"),20)
 label_at("庭院实验室",Vector2(38,59),29,Color("f2e5bb"))
 label_at("DESKTOP GARDEN  /  原型 0.1",Vector2(40,88),13,Color("93ad9d"))
 draw_circle(Vector2(351,64),23,Color("f4ce64")); label_at(str(sun),Vector2(388,76),34,Color("f6df96"))
 label_at("能量豆  %d" % food,Vector2(535,75),23,Color("b4d994"))
 label_at("击退  %d" % kills,Vector2(723,75),23)
 label_at("胜场  %d" % wins,Vector2(883,75),23,Color("92ae9e"))
 for item in [[1278,"继续" if paused else "暂停"],[1378,"说明"],[1478,"重开"]]:
  box(Rect2(item[0],34,86,44),Color("344b3b"),9)
  label_at(item[1],Vector2(item[0]+19,63),20)
 label_at("草坪 / 晴天",Vector2(346,166),24,Color("f2e5bb"))
 label_at("三面旗 · 九波 · 普通 / 路障 / 铁桶 / 巨人",Vector2(346,195),16,Color("91ab99"))
 var progress = float(wave)/9.0
 box(Rect2(1040,150,439,12),Color("2c4137"),6)
 if progress > 0: box(Rect2(1040,150,439*progress,12),Color("c2d879"),6)
 for i in range(3):
  var xx = 1040+(i+1)*439/3.0
  draw_line(Vector2(xx,144),Vector2(xx,171),Color("d6dab2"),2)
 label_at("准备布阵" if phase=="prep" else "波次 %d / 9" % wave,Vector2(1300,196),18,Color("d6dab2"))
 for row in range(ROWS):
  for col in range(COLS):
   var rect = Rect2(ORIGIN+Vector2(col,row)*CELL,CELL-Vector2(3,3))
   draw_rect(rect,Color("527249") if (row+col)%2==0 else Color("496a43"))
   # Fine lawn blades are static so movement remains easy to read.
   var blade = rect.position+Vector2(18+(col*13)%70,88)
   draw_line(blade,blade+Vector2(-3,-6),Color("6c8855"),1)
   draw_line(blade,blade+Vector2(3,-5),Color("6c8855"),1)
 var hc = cell_at(hover)
 if hc.x>=0 and hc.x<COLS and hc.y>=0 and hc.y<ROWS and phase in ["prep","play"]:
  var valid = plant_at(hc.x,hc.y)==null
  var tint = Color(0.85,0.96,0.65,0.19) if valid else Color(1,0.65,0.50,0.22)
  draw_rect(Rect2(ORIGIN+Vector2(hc)*CELL,CELL-Vector2(3,3)),tint)
  if selected != "" and valid: draw_plant(selected,center_at(hc.x,hc.y),0.6,0,true)
 for mower in mowers:
  if mower.state != "spent": draw_mower(Vector2(mower.x,center_at(0,mower.row).y+10))
 for p in plants:
  var pos = center_at(p.col,p.row)
  draw_plant(p.key,pos,1.0,p.age,p.flash>0)
  if p.hp < p.maxhp: health_bar(pos+Vector2(-32,36),64,p.hp/p.maxhp,Color("a8d67a"))
  if p.key=="megapuff":
   draw_arc(pos+Vector2(0,28),25,-PI/2,-PI/2+TAU*(1-p.age/30),24,Color("c6acec"),2)
 for z in zombies: draw_zombie(z)
 for b in bullets:
  var c = Color("ff9b5b") if b.fire else Color(DATA[b.kind].color)
  draw_circle(Vector2(b.x,b.y),15 if b.power else 7,c)
  draw_circle(Vector2(b.x-2,b.y-2),4,Color(1,1,1,0.45))
  if b.kind=="sweetpea": draw_arc(Vector2(b.x,b.y),9,0,PI*1.6,10,Color("ffe1f0"),2)
 for s in suns: draw_sun(s.pos)
 for fx in effects:
  var color_value = fx.color; color_value.a = clampf(fx.ttl/fx.max,0,1)
  if fx.text=="": draw_circle(fx.pos,fx.size,color_value)
  else: label_at(fx.text,fx.pos,fx.size,color_value)
 for i in range(CARDS.size()): draw_card(i)
 box(Rect2(28,726,128,48),Color("87684a") if shovel else Color("293e32"),10)
 label_at("铲子  X",Vector2(51,758),21)
 box(Rect2(168,726,128,48),Color("577c41") if food_mode else Color("293e32"),10)
 label_at("能量豆 F",Vector2(182,758),21)
 if phase=="prep":
  box(Rect2(30,804,264,40),Color("293e32"),9)
  label_at("练习模式：开" if practice else "练习模式：关",Vector2(54,831),18)
  box(Rect2(1114,800,364,62),Color("c6d77e"),14)
  label_at("开始防守   ENTER",Vector2(1190,840),25,Color("233524"))
 else: label_at("快捷键 1–8 选卡 · 右键取消 · F11 全屏",Vector2(346,840),18,Color("8da693"))
 var inspect_key = selected
 for i in range(CARDS.size()):
  if card_rect(i).has_point(hover): inspect_key=CARDS[i]
 if inspect_key != "":
  label_at(DATA[inspect_key].name+"："+DATA[inspect_key].desc,Vector2(346,794),16,Color("d8dfc7"))
 elif message_time>0: label_at(message,Vector2(346,794),18,Color("e5dba5"))
 label_at("独立桌面引擎 · 固定步长战斗 · 示例素材接入 / 非完整原版复刻",Vector2(346,880),14,Color("718c7b"))
 if paused or help_open or phase in ["won","lost"]: draw_overlay()

func draw_card(i):
 var key = CARDS[i]; var rect = card_rect(i); var d=DATA[key]
 var active = key==selected
 box(rect,Color("304737") if active else Color("24382e"),12,Color("e2d18b") if active else Color("4a624b"))
 draw_plant(key,rect.position+Vector2(38,48),0.48,0,false)
 label_at(str(i+1),rect.position+Vector2(9,20),13,Color("819c88"))
 label_at(d.name,rect.position+Vector2(8,83),16)
 label_at(str(d.cost),rect.position+Vector2(89,27),18,Color("f3da8b"))
 if cooldowns[key]>0:
  var frac = cooldowns[key]/d.cool
  box(Rect2(rect.position,Vector2(rect.size.x,rect.size.y*frac)),Color(0.05,0.10,0.08,0.7),12)
  label_at("%.1fs" % cooldowns[key],rect.position+Vector2(76,55),15)
 if sun<d.cost: draw_rect(rect,Color(0.04,0.08,0.06,0.32))

func health_bar(pos,width,value,color_value):
 box(Rect2(pos,Vector2(width,5)),Color("263127"),2)
 if value>0: box(Rect2(pos,Vector2(width*clampf(value,0,1),5)),color_value,2)

func draw_sun(pos):
 for i in range(10):
  var a=i*TAU/10+elapsed_ui*0.25
  draw_line(pos+Vector2.from_angle(a)*22,pos+Vector2.from_angle(a)*30,Color("edc655"),3)
 draw_circle(pos,20,Color("f5d666"));draw_circle(pos-Vector2(4,5),13,Color("ffe594"))
 label_at("25",pos+Vector2(-11,7),16,Color("7a612c"))

func draw_plant(key,pos,scale_value,age,flash):
 var sc=float(scale_value)
 draw_set_transform(pos,0,Vector2.ONE*sc)
 draw_ellipse_shadow(Vector2(0,28),Vector2(29,8))
 var c=Color(DATA[key].color)
 var sway=sin(age*2.4)*1.8
 if key in ["sweetpea","megapuff"]:
  var tex=sweet_texture if key=="sweetpea" else mega_texture
  var region=sweet_region if key=="sweetpea" else mega_region
  var height=87.0 if key=="sweetpea" else 91.0
  var width=height*region.size.x/region.size.y
  draw_texture_rect_region(tex,Rect2(-width/2,-height+31,width,height),region,Color(1.15,1.15,1.15) if flash else Color.WHITE)
 elif key in ["pea","snowpea","sunflower"]:
  draw_line(Vector2(0,23),Vector2(sway,-18),Color("6a9f54"),8)
  draw_ellipse_shadow(Vector2(-12,22),Vector2(17,7),Color("85b864"))
  draw_ellipse_shadow(Vector2(12,25),Vector2(18,7),Color("78ab5b"))
  if key=="sunflower":
   for i in range(11): draw_circle(Vector2(sway,-20)+Vector2.from_angle(i*TAU/11)*25,10,c)
   draw_circle(Vector2(sway,-20),22,Color("b37a43"));draw_circle(Vector2(sway,-22),18,Color("d69a56"))
   draw_circle(Vector2(sway-7,-24),2.5,Color("253829"));draw_circle(Vector2(sway+7,-24),2.5,Color("253829"))
   draw_arc(Vector2(sway,-19),9,0.2,PI-0.2,12,Color("513d2b"),2)
  else:
   draw_circle(Vector2(sway,-20),25,c)
   box(Rect2(7+sway,-31,32,23),c,8)
   draw_circle(Vector2(36+sway,-19),10,c.darkened(0.35))
   draw_circle(Vector2(-6+sway,-29),4.5,Color("fcf8df"));draw_circle(Vector2(-5+sway,-29),2.4,Color("172d24"))
 elif key=="wallnut":
  box(Rect2(-27,-48,54,79),Color("9f784e"),24)
  box(Rect2(-24,-46,48,73),c,23)
  draw_circle(Vector2(-10,-16),4,Color("faf3d5"));draw_circle(Vector2(10,-16),4,Color("faf3d5"))
  draw_circle(Vector2(-8,-15),2.2,Color("29372c"));draw_circle(Vector2(12,-15),2.2,Color("29372c"))
  draw_arc(Vector2(0,0),7,0.2,PI-0.2,10,Color("765639"),2)
 elif key=="torchwood":
  box(Rect2(-24,-39,48,70),Color("9d6940"),10)
  for x in [-14,-3,11]: draw_line(Vector2(x,-28),Vector2(x+3,21),Color("c58b52"),3)
  for i in range(4): draw_circle(Vector2(-16+i*11,-43-sin(age*7+i)*6),12,Color("f0aa53"))
  draw_circle(Vector2(0,-53),13,Color("f7d77c"))
  draw_line(Vector2(-14,-10),Vector2(-4,-6),Color("342d23"),4);draw_line(Vector2(6,-6),Vector2(16,-10),Color("342d23"),4)
 else:
  box(Rect2(-30,-43,60,73),c,25)
  draw_line(Vector2(-8,-43),Vector2(0,-58),Color("749943"),5)
  draw_line(Vector2(-21,-16),Vector2(-5,-10),Color("30472d"),4);draw_line(Vector2(7,-10),Vector2(23,-16),Color("30472d"),4)
  draw_line(Vector2(-12,9),Vector2(12,9),Color("425735"),3)
 draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(pos,radii,color_value=Color(0.06,0.12,0.08,0.22)):
 var points=PackedVector2Array()
 for i in range(24): points.append(pos+Vector2(cos(i*TAU/24)*radii.x,sin(i*TAU/24)*radii.y))
 draw_colored_polygon(points,color_value)

func draw_zombie(z):
 var pos=Vector2(z.x,center_at(0,z.row).y)
 var giant=z.kind=="giant"
 var scale_value=1.3 if giant else 1.0
 var bob=sin(z.anim*5)*2 if z.freeze<=0 else 0.0
 draw_set_transform(pos+Vector2(0,bob),0,Vector2.ONE*scale_value)
 draw_ellipse_shadow(Vector2(0,30),Vector2(28,8))
 var skin=Color("b9ccaa") if z.slow<=0 else Color("8dcde0")
 if z.stalled>0: skin=Color("c7aad6")
 if z.flash>0: skin=Color("f9e3c4")
 var walk=sin(z.anim*5)*6 if z.attack==0 else 0.0
 draw_line(Vector2(-9,9),Vector2(-11-walk,27),Color("4b5960"),9)
 draw_line(Vector2(9,9),Vector2(11+walk,27),Color("4b5960"),9)
 draw_line(Vector2(-11-walk,27),Vector2(-24-walk,29),Color("293c39"),8)
 draw_line(Vector2(11+walk,27),Vector2(0+walk,30),Color("293c39"),8)
 box(Rect2(-17,-28,35,41),Color("876e5a") if not giant else Color("7b7566"),7)
 draw_line(Vector2(-13,-18),Vector2(-36,-14+sin(z.anim*4)*3),skin,8)
 draw_circle(Vector2(-5,-46),22,skin)
 draw_circle(Vector2(-15,-50),7,Color("f4edd7"));draw_circle(Vector2(0,-48),6,Color("f4edd7"))
 draw_circle(Vector2(-17,-50),2.8,Color("27382e"));draw_circle(Vector2(-2,-48),2.5,Color("27382e"))
 draw_line(Vector2(-22,-33),Vector2(-3,-30),Color("526349"),4)
 if z.kind=="cone":
  draw_colored_polygon(PackedVector2Array([Vector2(-23,-63),Vector2(13,-63),Vector2(6,-108)]),Color("de9b54"))
  draw_line(Vector2(-18,-74),Vector2(11,-74),Color("f1c582"),5)
 elif z.kind=="bucket": box(Rect2(-28,-88,49,32),Color("abb5aa"),5,Color("7e928c"))
 elif giant:
  draw_line(Vector2(21,-3),Vector2(37,-63),Color("7b5a3e"),12)
  box(Rect2(23,-72,39,25),Color("8c6e4d"),4)
 if z.freeze>0: box(Rect2(-30,-72,58,103),Color(0.55,0.88,1,0.30),10,Color("b2e8fa"))
 draw_set_transform(Vector2.ZERO)
 if z.hp<z.maxhp: health_bar(pos+Vector2(-28,-85 if not giant else -110),56,z.hp/z.maxhp,Color("d9b36f"))

func draw_mower(pos):
 draw_circle(pos+Vector2(-14,10),9,Color("23362e"));draw_circle(pos+Vector2(17,10),9,Color("23362e"))
 box(Rect2(pos-Vector2(24,12),Vector2(49,23)),Color("cb8a60"),6)
 draw_line(pos+Vector2(-15,-8),pos+Vector2(-24,-31),Color("9cae99"),4)

func draw_overlay():
 draw_rect(Rect2(0,0,1600,900),Color(0.03,0.08,0.06,0.76))
 box(Rect2(390,220,820,430),Color("20382b"),24,Color("6e8761"))
 if help_open:
  label_at("操作与原型范围",Vector2(436,279),32,Color("ecdba5"))
  var lines=["点击卡片，再点击草坪种植；点击阳光收集。", "1–8 选卡 · X 铲子 · F 能量豆 · 右键 / Esc 取消", "空格 / P 暂停 · F11 全屏 · 开始前可选练习模式", "每行一辆割草机。九波守住即胜利；再次突破则失败。", "已接入甜豌豆、机枪喷静态素材，其余为临时矢量画面。", "这是独立玩法原型：未实现全部世界、完整动画与原版存档。", "点击任意位置关闭说明。"]
  for i in range(lines.size()): label_at(lines[i],Vector2(436,330+i*39),20)
 else:
  var title="已暂停" if paused else ("防守成功" if phase=="won" else "防线被突破")
  label_at(title,Vector2(661,328),42,Color("ecdba5"))
  label_at("按空格 / P 继续" if paused else "击退 %d 只僵尸 · 完成 %d / 9 波" % [kills,wave],Vector2(604,395),24)
  if not paused:
   box(Rect2(650,520,300,64),Color("c6d77e"),14)
   label_at("再守一局",Vector2(744,563),26,Color("233524"))
