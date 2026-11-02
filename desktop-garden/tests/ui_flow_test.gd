extends SceneTree
var game
var checks=0
var failures=[]
func check(value,message):
 checks+=1
 if not value:failures.append(message);push_error(message)
func click(pos,button=MOUSE_BUTTON_LEFT):
 var event=InputEventMouseButton.new();event.position=pos;event.button_index=button;event.pressed=true;game._gui_input(event)
func _initialize():call_deferred("run")
func run():
 game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false);game.profile_path="user://test_profile.cfg"
 var was_sound=game.sound_enabled
 click(Vector2(1200,50));check(game.sound_enabled!=was_sound,"sound button toggles mute")
 click(Vector2(1200,50));check(game.sound_enabled==was_sound,"sound button restores prior state")
 click(game.card_rect(1).get_center());check(game.selected=="pea","card selects plant")
 click(game.center_at(1,2));check(game.plants.size()==1,"grid click places selected plant")
 click(Vector2(0,0),MOUSE_BUTTON_RIGHT);check(game.selected=="","right click clears selection")
 click(Vector2(1200,820));check(game.phase=="play","start button begins match")
 click(Vector2(1300,50));check(game.paused,"pause button pauses match")
 var count=game.plants.size();click(game.center_at(3,3));check(game.plants.size()==count,"paused game ignores planting")
 click(Vector2(1300,50));check(not game.paused,"pause button resumes match")
 game.spawn_sun(Vector2(600,400),400);var old=game.sun;click(Vector2(600,400));check(game.sun==old+25,"collecting sun adds exactly 25")
 click(Vector2(600,400));check(game.sun==old+25,"same sun cannot be collected twice before next tick")
 click(Vector2(200,745));check(game.food_mode,"plant food button toggles mode")
 click(game.center_at(1,2));check(game.food==2 and game.plants[0].pf_active,"plant food consumes charge and starts original burst")
 click(Vector2(50,745));click(game.center_at(1,2));game.tick(1.0/60);check(game.plants.is_empty(),"shovel removes plant")
 # Full deterministic match exercises all nine waves and the giant spawns.
 game.practice=true;game.reset_game();game.sun=100000
 for row in range(5):
  for col in range(6):
   game.cooldowns.sweetpea=0;game.place("sweetpea",col,row)
 game.start_game();game.profile_path="user://test_profile.cfg"
 for i in range(60*500):
  if game.phase in ["won","lost"]:break
  game.tick(1.0/60)
 check(game.phase=="won" and game.wave==9,"complete nine-wave match reaches win")
 check(game.kills==72,"all 72 scheduled enemies resolved")
 print("UI / MATCH TESTS: ",checks," checks, ",failures.size()," failures")
 game.queue_free();await process_frame;await create_timer(0.1).timeout;quit(0 if failures.is_empty() else 1)
