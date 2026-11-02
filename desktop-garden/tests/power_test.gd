extends SceneTree
var game
var checks=0
var failures=[]
func check(ok,message):
 checks+=1
 if not ok:failures.append(message);push_error(message)
func clean():
 game.practice=true;game.reset_game();game.sun=10000;game.phase="play";game.wave_timer=999;game.sky_timer=999
func steps(seconds):
 for i in range(ceili(seconds*60)):game.tick(1.0/60)
func put(key,col=0,row=0):
 game.cooldowns[key]=0;game.place(key,col,row);return game.plants[-1]
func _initialize():call_deferred("run")
func run():
 game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 for key in ["pea","snowpea"]:
  clean();var p=put(key);p.timer=999;game.use_food(p)
  steps(p.pf_on+2.02)
  check(p.pf_remaining==0 and game.bullets.size()==60,key+" plant food emits 60 shots")
  check(game.bullets.all(func(b):return b.damage==20 and not b.power),key+" burst uses regular damage without piercing")
 clean();var p=put("megapuff");var other=put("megapuff",1,1);p.age=29;other.age=28;p.timer=999;other.timer=999
 game.use_food(p)
 check(p.age==0 and other.age==0,"Mega plant food resets all Mega lifetimes")
 steps(p.pf_on+2.02)
 check(p.pf_remaining==0 and game.bullets.size()==30,"Mega plant food emits 30 shots")
 check(game.bullets.all(func(b):return b.range==1800),"Mega food shots have extended range")
 clean();p=put("sunflower");p.timer=999;game.use_food(p);steps(2.1)
 check(game.suns.size()==6,"Sunflower food emits six suns")
 check(game.suns.all(func(s):return s.value==40),"Sunflower food uses large 40-value suns")
 clean();p=put("wallnut");p.hp=1000;game.use_food(p)
 check(p.hp==4000 and p.shield==8000,"Wallnut food repairs and adds 8000 shield")
 game.damage_plant(p,1000)
 check(p.hp==4000 and p.shield==7000,"shield absorbs damage first")
 game.damage_plant(p,7500)
 check(p.hp==3500 and p.shield==0,"damage spills through depleted shield")
 clean();var pea=put("pea");var torch=put("torchwood",1,0);game.use_food(torch)
 var z=game.add_zombie(0,"basic",game.center_at(1,0).x+60)
 game.fire(pea);game.tick_bullet(game.bullets[0],0.5)
 check(torch.torch_blue and z.hp==140,"blue torch triples pea damage")
 clean();pea=put("pea");torch=put("torchwood",1,0);game.use_food(torch)
 z=game.add_zombie(0,"basic",game.center_at(1,0).x+60);z.slow=10
 game.fire(pea);game.tick_bullet(game.bullets[0],0.5)
 check(z.hp==125 and z.slow==0,"blue fire retains 25 percent ice synergy and thaws")
 clean();p=put("sweetpea");game.use_food(p)
 check(game.bullets.size()==1 and game.bullets[0].power and game.bullets[0].damage==1800,"Sweet food remains one immediate piercing candy")
 var before=game.food;game.use_food(p)
 check(game.food==before,"cannot stack food on an active food animation")
 clean();p=put("snowpea");z=game.add_zombie(0,"basic",1400);other=game.add_zombie(1,"basic",1400);game.use_food(p)
 check(z.slow==10 and other.slow==0,"snow food chill only affects its lane")
 clean();p=put("squash");z=game.add_zombie(3,"giant",1300);game.use_food(p);steps(5)
 check(z.hp==0 and not game.plants.is_empty() and p.squash_phase=="wait" and not p.squash_power,"Squash food slams twice for 1800 then returns home")
 clean();p=put("squash");z=game.add_zombie(0,"giant",game.center_at(0,0).x+70);steps(1.3)
 check(p.airborne and p.squash_phase=="up" and p.visual_y<0,"Squash jumps above ground while using original jump clip")
 clean();z=game.add_zombie(0,"cone",1000)
 check(game.zombie_actor(z)=="cone","intact cone uses full armor")
 z.hp=400;check(game.zombie_actor(z)=="cone_damage_01","cone has first damage visual")
 z.hp=280;check(game.zombie_actor(z)=="cone_damage_02","cone has second damage visual")
 z.hp=200;check(game.zombie_actor(z)=="zombie","depleted armor returns to bare zombie")
 check(game.sounds.size()==7 and game.sounds.values().all(func(v):return not v.is_empty()),"all seven original sound categories loaded")
 check(game.grass_texture.get_width()>0 and game.lawn_texture.get_width()>0,"original lawn textures loaded")
 print("POWER / PRESENTATION TESTS: ",checks," checks, ",failures.size()," failures")
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
