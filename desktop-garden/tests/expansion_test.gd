extends SceneTree
var game
var checks=0
var failures=[]
func check(value,message):
 checks+=1
 if not value:failures.append(message);push_error(message)
func run_for(seconds):
 for i in range(ceili(seconds*60)):game.tick(1.0/60)
func fresh(world="egypt"):
 game.world=world;game.reset_game();game.sun=100000;game.phase="play";game.wave_timer=999;game.sky_timer=999
func click(pos):
 var event=InputEventMouseButton.new();event.position=pos;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;game._gui_input(event)
func _initialize():call_deferred("run")
func run():
 game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.profile_path="user://test_profile.cfg"
 fresh()
 check(game.expansion.graves.size()==5,"Egypt starts with five graves")
 var g=game.expansion.graves[0]
 check(not game.place("pea",g.col,g.row),"graves block ordinary placement")
 check(not game.place("gravebuster",0,0),"gravebuster requires a grave")
 check(game.place("gravebuster",g.col,g.row),"gravebuster can be planted on grave")
 run_for(4.9);check(g.hp==700,"gravebuster does not eat early")
 run_for(0.2);check(g.hp<=0 and game.plants.is_empty(),"gravebuster removes itself and grave at five seconds")
 fresh();g=game.expansion.graves[0];game.place("pea",5,0);game.fire(game.plants[0]);run_for(1)
 check(g.hp==680,"straight pea damages grave")
 var z=game.add_zombie(0,"basic",1400);game.place("cabbage",0,0);game.expansion.lob(game.plants[-1],z,50);run_for(1.21)
 check(z.hp==150,"cabbage lob bypasses grave and deals 50")
 fresh("lawn");game.place("bloomerang",0,0)
 var xs=[]
 for i in range(5):
  var enemy=game.add_zombie(0,"bucket",600+i*100);enemy.speed=0;xs.append(enemy)
 game.plants[0].timer=999;game.expansion.boomerang(game.plants[0]);run_for(5)
 check(xs[0].hp==1250 and xs[3].hp==1250,"boomerang hits first four twice")
 check(xs[4].hp==1280,"boomerang turns after four outgoing hits")
 check(game.bullets.is_empty(),"returned boomerang is removed")
 fresh("lawn");game.place("mine",2,0);z=game.add_zombie(0,"giant",game.center_at(2,0).x);z.speed=0;z.bite=0
 run_for(9.8);check(z.hp==3600,"mine cannot explode before arming")
 run_for(1.2);check(z.hp==1800 and game.plants.is_empty(),"armed mine deals 1800 once and disappears")
 fresh("lawn");game.place("mine",2,2);var mine=game.plants[0];game.use_food(mine);run_for(1.5)
 check(game.plants.size()==3,"mine power creates two clones")
 check(game.plants.all(func(p):return p.age>=10),"mine power arms original and clones")
 check(game.sun==99975 and game.food==2,"mine clones do not charge sun or food")
 var locations=[]
 for p in game.plants:locations.append(Vector2i(p.col,p.row))
 check(locations[0]!=locations[1] and locations[0]!=locations[2] and locations[1]!=locations[2],"mine clones occupy distinct free cells")
 fresh("lawn");game.place("bonk",3,2);z=game.add_zombie(2,"bucket",game.center_at(3,2).x-90);z.speed=0
 run_for(0.5);check(z.hp<1280,"bonk can punch behind itself")
 fresh("lawn");game.place("bonk",3,2);var bonk=game.plants[0];bonk.timer=999
 z=game.add_zombie(1,"giant",game.center_at(3,2).x);z.speed=0
 var far=game.add_zombie(0,"giant",z.x);far.speed=0
 game.use_food(bonk);run_for(4.5)
 check(z.hp==1500,"bonk power performs thirty 70-damage area punches")
 check(far.hp==3600,"bonk power does not reach two lanes away")
 fresh("lawn");game.place("cabbage",0,0);var cabbage=game.plants[0];cabbage.timer=999
 xs=[]
 for row in range(5):
  var enemy=game.add_zombie(row,"bucket",1300);enemy.speed=0;xs.append(enemy)
 game.use_food(cabbage);run_for(2)
 check(xs.all(func(t):return t.hp==1080),"cabbage power hits every lane for 200")
 fresh();game.place("bloomerang",0,0);var before=game.food;game.use_food(game.plants[0])
 check(game.food==before,"unsupported power does not consume food")
 game.reset_game();game.world="lawn";game.reset_game();click(Vector2(700,160))
 check(game.world=="egypt" and "gravebuster" in game.deck,"scene switch selects Egypt deck")
 click(Vector2(870,160));check(game.chooser_open,"chooser opens before start")
 var count=game.draft_deck.size();click(game.chooser_rect(0).get_center());check(game.draft_deck.size()==count-1,"chooser removes a selected card")
 click(game.chooser_rect(0).get_center());check(game.draft_deck.size()==8,"chooser adds a card at end")
 click(game.chooser_rect(4).get_center());check(game.draft_deck.size()==8,"chooser enforces eight slots")
 click(Vector2(1150,760));check(not game.chooser_open and game.deck[-1]=="sunflower","confirm preserves chosen order")
 game.phase="prep";game.plants.clear();game.sun=100000;game.place("gravebuster",6,0);game.shovel=true;click(game.center_at(6,0));game.tick(1.0/60)
 check(game.expansion.grave_at(6,0)!=null,"shoveling a gravebuster leaves the grave")
 for key in ["cabbage","bloomerang","mine","bonk","gravebuster","grave","mine_fx","egypt_zombie","egypt_giant","egypt_cone_damage_02","egypt_bucket_damage_01"]:
  check(game.animations.has_actor(key),"new original animation loaded: "+key)
 print("EXPANSION TESTS: ",checks," checks, ",failures.size()," failures")
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
