extends SceneTree
func _initialize(): call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("res://build")
 DisplayServer.window_set_size(Vector2i(1600,900))
 var game=load("res://Main.tscn").instantiate();root.add_child(game)
 await process_frame
 game.set_process(false)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/prep-screen.png")
 game.practice=true;game.reset_game();game.sun=800
 for row in range(5):
  for key in ["sunflower","pea","wallnut","sweetpea","megapuff"]:game.cooldowns[key]=0
  game.place("sunflower",0,row)
  game.place("sweetpea" if row==1 else ("megapuff" if row==3 else "pea"),2,row)
  game.place("wallnut",4,row)
  game.add_zombie(row,"giant" if row==4 else ("cone" if row==1 else "basic"),1260+row*23)
 game.start_game();game.wave=3;game.wave_timer=999;game.sky_timer=999
 for i in range(120):game.tick(1.0/60)
 game.selected="sweetpea";game.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/combat-screen.png")
 print("VISUAL SMOKE: prep and combat rendered")
 game.queue_free();await process_frame;quit()
