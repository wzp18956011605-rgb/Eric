extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("res://build")
 DisplayServer.window_set_size(Vector2i(1600,900))
 var game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.practice=true;game.reset_game();game.sun=10000;game.sound_enabled=false
 for row in range(5):
  for key in game.CARDS:game.cooldowns[key]=0
  game.place("sunflower",0,row)
  game.place("pea" if row==0 else ("sweetpea" if row==2 else ("megapuff" if row==3 else "snowpea")),2,row)
  game.place("wallnut",4,row)
  var z=game.add_zombie(row,"giant" if row==4 else ("bucket" if row==1 else ("cone" if row==2 else "basic")),1380+row*20)
  if row==1:z.hp=550
  if row==2:z.hp=290
 game.place("torchwood",5,0)
 game.start_game();game.wave=5;game.wave_timer=999;game.sky_timer=999
 game.use_food(game.plant_at(2,0));game.use_food(game.plant_at(4,1));game.use_food(game.plant_at(5,0))
 for i in range(65):game.tick(1.0/60)
 game.selected="pea";game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/power-screen.png")
 print("POWER RENDER: original clips, armor and blue fire rendered")
 game.queue_free();await process_frame;quit()
