extends SceneTree
func _initialize():call_deferred("run")
func run():
 DisplayServer.window_set_size(Vector2i(1600,900))
 var game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.world="egypt";game.reset_game();game.deck=["sunflower","pea","wallnut","cabbage","bloomerang","mine","bonk","gravebuster"];game.sun=100000
 for row in range(5):
  game.cooldowns.sunflower=0;game.place("sunflower",0,row)
  var key=["cabbage","bloomerang","mine","bonk","wallnut"][row]
  game.place(key,2,row)
  game.add_zombie(row,["basic","cone","bucket","giant","basic"][row],1310)
 game.place("gravebuster",6,0);game.start_game();game.wave_timer=999;game.sky_timer=999
 for i in range(55):game.tick(1.0/60)
 game.selected="cabbage";game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/egypt-screen.png")
 game.phase="prep";game.draft_deck=game.deck.duplicate();game.chooser_open=true;game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://build/chooser-screen.png")
 print("EXPANSION VISUAL SMOKE: Egypt and chooser rendered")
 game.queue_free();await process_frame;await create_timer(0.2).timeout;quit()
