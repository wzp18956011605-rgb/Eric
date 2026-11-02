extends SceneTree
var checks=0
var failures=[]
func check(value,message):
 checks+=1
 if not value:failures.append(message);push_error(message)
func _initialize():call_deferred("run")
func run():
 var anim=load("res://OriginalAnimations.gd").new()
 for key in ["sunflower","pea","wallnut","snowpea","sweetpea","megapuff","torchwood","squash","zombie","cone","bucket","giant"]:
  var valid=anim.has_actor(key)
  if valid:
   var data=anim.actors[key]
   valid=data.rate>0 and data.images.size()>0 and data.clips[data.idle].frames.size()>1
   for clip in data.clips.values():
    for frame in clip.frames:
     for part in frame:
      valid=valid and part.size()==11 and part[0]>=0 and part[0]<data.images.size()
      for v in part:valid=valid and is_finite(float(v))
  check(valid,"original animation data valid: "+key)
 var cues=anim.action_cues("megapuff","attack")
 check(cues.size()==4,"original Mega Puff attack has four use_action cues")
 check(cues[0]>=0 and cues[-1]<anim.duration("megapuff","attack"),"attack cues fit original clip duration")
 check(anim.clip_name("pea","missing_clip")=="idle","unknown animation falls back to idle")
 check(anim.actors.cone.bounds==anim.actors.zombie.bounds and anim.actors.bucket.bounds==anim.actors.zombie.bounds,"armor variants preserve body anchor and scale")
 var game=load("res://Main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
 game.practice=true;game.reset_game();game.phase="play";game.wave_timer=1000;game.sky_timer=1000
 game.place("megapuff",0,0);game.plants[0].timer=0;game.add_zombie(0,"giant",game.center_at(0,0).x+320)
 game.tick(1.0/60)
 check(game.bullets.is_empty(),"attack begins without firing before original animation cue")
 for i in range(40):game.tick(1.0/60)
 check(game.bullets.size()==4,"original cue timeline emits all four shots once")
 print("ANIMATION TESTS: ",checks," checks, ",failures.size()," failures")
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
