extends RefCounted
## Displays baked original PAM transforms. Simulation remains independent of rendering.
var actors: Dictionary = {}
var textures: Dictionary = {}
const ROOT = "res://assets/animations/"

func _init():
 for filename in DirAccess.get_files_at(ROOT):
  if not filename.ends_with(".json"):continue
  var key=filename.trim_suffix(".json")
  var path=ROOT+key+".json"
  if not FileAccess.file_exists(path): continue
  var data=JSON.parse_string(FileAccess.get_file_as_string(path))
  if not data is Dictionary or not data.has("clips") or not data.has("bounds"):continue
  actors[key]=data
  for atlas in data.atlases:
   if not textures.has(atlas): textures[atlas]=load(ROOT+atlas)

func has_actor(key): return actors.has(key)

func has_clip(key,clip):return actors.has(key) and actors[key].clips.has(clip)

func clip_name(key,pose):
 var data=actors[key]
 var aliases={"idle":data.idle,"attack":"special_stage1" if key=="megapuff" else "attack","special":"special","damage":"damage","damage2":"damage2","damage3":"damage3","size_up":"size_up","walk":"walk","eat":"eat","die":"die","smash_left":"smash_left"}
 var name=aliases.get(pose,pose)
 return name if data.clips.has(name) else data.idle

func duration(key,pose):
 if not actors.has(key):return 0.0
 var data=actors[key];return data.clips[clip_name(key,pose)].frames.size()/float(data.rate)

func action_cues(key,pose):
 if not actors.has(key):return []
 var data=actors[key];var clip=data.clips[clip_name(key,pose)];var cues=[]
 for frame in clip.events:
  for cmd in clip.events[frame]:
   if cmd[0] in ["use_action","use_special"]:cues.append(float(frame)/float(data.rate))
 cues.sort();return cues

func draw_actor(canvas,key,pos,display_scale,clock,pose="idle",tint=Color.WHITE,mirror=false):
 var data=actors[key];var name=clip_name(key,pose);var frames=data.clips[name].frames
 if key=="gravebuster" and pose=="idle" and clock==0:clock=0.5
 var frame_number=int(maxf(clock,0)*float(data.rate))
 if pose=="die":frame_number=mini(frame_number,frames.size()-1)
 else:frame_number%=frames.size()
 var bounds=data.bounds
 var base_key=key.trim_prefix("egypt_")
 var target_height=112.0 if base_key=="zombie" or base_key.begins_with("cone") or base_key.begins_with("bucket") else (162.0 if base_key=="giant" else 92.0)
 var sc=display_scale*target_height/maxf(1,bounds[3]-bounds[1])
 var anchor=Vector2((bounds[0]+bounds[2])/2.0,bounds[3])
 var axis=Vector2(-sc if mirror else sc,sc)
 var root_transform=Transform2D(0.0,axis,0.0,pos+Vector2(0,30*display_scale)-anchor*axis)
 for part in frames[frame_number]:
  var image=data.images[int(part[0])]
  var trans=Transform2D(Vector2(part[1],part[2]),Vector2(part[3],part[4]),Vector2(part[5],part[6]))
  canvas.draw_set_transform_matrix(root_transform*trans)
  var color_value=Color(part[7],part[8],part[9],part[10])*tint
  canvas.draw_texture_rect_region(textures[data.atlases[int(image[0])]],Rect2(0,0,image[5],image[6]),Rect2(image[1],image[2],image[3],image[4]),color_value)
 canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
