extends RefCounted
## Egypt obstacles and plant mechanics. Damage is independent of sprite frames.
var game
var graves=[]
var blasts=[]
const NEW_PLANTS=["cabbage","bloomerang","mine","bonk","gravebuster"]
func _init(owner_game):game=owner_game
func reset():
 graves.clear();blasts.clear()
 if game.world!="egypt":return
 for row in range(5):
  game.next_id+=1
  graves.append({"id":game.next_id,"col":[6,5,7,6,5][row],"row":row,"hp":700.0,"maxhp":700.0})
func grave_at(col,row):
 for grave in graves:
  if grave.hp>0 and grave.col==col and grave.row==row:return grave
 return null
func can_place(key,col,row):
 return (grave_at(col,row)!=null) if key=="gravebuster" else (grave_at(col,row)==null)
func position(target):return game.center_at(target.col,target.row).x if target.has("col") else target.x
func targets(row,xpos,reach=1800.0,behind=false):
 var result=[]
 for target in game.zombies+graves:
  if target.hp<=0 or target.row!=row:continue
  var dx=position(target)-xpos
  if (absf(dx)<reach if behind else dx>=-25 and dx<reach):result.append(target)
 result.sort_custom(func(a,b):return absf(position(a)-xpos)<absf(position(b)-xpos))
 return result
func damage(target,amount):
 if target.has("kind"):game.hurt(target,amount,Color("e4f0ac"))
 else:
  target.hp-=amount
  game.spark(game.center_at(target.col,target.row),Color("cdbb8c"),3)
func tick(dt):
 for blast in blasts:blast.age+=dt
 blasts=blasts.filter(func(b):return b.age<game.animations.duration("mine_fx","animation"))
 graves=graves.filter(func(g):return g.hp>0)
func tick_plant(p,dt):
 if p.key not in NEW_PLANTS:return false
 var home=game.center_at(p.col,p.row)
 if p.key=="gravebuster":
  p.pose="attack";p.pose_age=p.age
  var grave=grave_at(p.col,p.row)
  if grave==null:p.hp=0
  elif p.age>=5:grave.hp=0;p.hp=0;game.spark(home,Color("dbc991"),12)
 elif p.key=="mine":
  if p.age<10:
   p.pose="plant_idle";p.pose_age=p.age
  else:
   if p.pose=="plant_idle":p.pose="recover";p.pose_age=0
   if p.pose=="idle":
    if targets(p.row,home.x,85,true).any(func(t):return t.has("kind")):explode(p)
 elif p.key in ["cabbage","bloomerang","bonk"]:
  var options=targets(p.row,home.x,110 if p.key=="bonk" else 1800,p.key=="bonk")
  if p.timer<=0 and not options.is_empty():
   p.timer=game.DATA[p.key].rate;p.pose="attack";p.pose_age=0
   p.shot_cues=game.animations.action_cues(p.key,"attack")
   if p.shot_cues.is_empty():p.shot_cues=[0.1333 if p.key=="bonk" else 0.2]
  while not p.shot_cues.is_empty() and p.pose_age+0.0001>=p.shot_cues[0]:
   p.shot_cues.pop_front()
   options=targets(p.row,home.x,110 if p.key=="bonk" else 1800,p.key=="bonk")
   if options.is_empty():continue
   if p.key=="cabbage":
    var living=options.filter(func(t):return t.has("kind"))
    lob(p,living[0] if not living.is_empty() else options[0],50)
   elif p.key=="bonk":damage(options[0],15);p.flash=0.08;p.facing_left=position(options[0])<home.x
   else:boomerang(p)
 return true
func explode(p):
 var home=game.center_at(p.col,p.row)
 for target in targets(p.row,home.x,95,true):damage(target,1800)
 blasts.append({"pos":home,"age":0.0});p.hp=0;game.play_sound("squash")
func lob(p,target,amount):
 var home=game.center_at(p.col,p.row)
 game.bullets.append({"kind":"cabbage","x":home.x,"y":home.y-36,"row":target.row,"travel":0.0,"range":9999.0,"damage":amount,"fire":false,"blue":false,"power":amount>50,"alive":true,"type":"lob","age":0.0,"start":Vector2(home.x,home.y-36),"end":Vector2(position(target),game.center_at(0,target.row).y-18),"target":target})
 game.play_sound("shoot")
func boomerang(p):
 var home=game.center_at(p.col,p.row)
 game.bullets.append({"kind":"bloomerang","x":home.x+28,"y":home.y-20,"row":p.row,"origin":home.x,"travel":0.0,"range":99999.0,"damage":15.0,"fire":false,"blue":false,"power":false,"alive":true,"type":"boomerang","direction":1,"hit":[],"pause":0.0,"turn":false})
 game.play_sound("shoot")
func special_bullet(b,dt):
 if not b.has("type"):return false
 if b.type=="lob":
  b.age+=dt
  if b.target.hp>0:b.end.x=position(b.target)
  var fraction=clampf(b.age/1.2,0,1)
  var point=b.start.lerp(b.end,fraction)-Vector2(0,170*sin(PI*fraction))
  b.x=point.x;b.y=point.y
  if fraction>=1:
   b.alive=false
   if b.target.hp>0:damage(b.target,b.damage)
   else:
    var options=targets(b.row,b.end.x,35,true)
    if not options.is_empty():damage(options[0],b.damage)
  return true
 if b.pause>0:
  b.pause-=dt;return true
 if b.turn:b.direction=-1;b.hit.clear();b.turn=false
 var old_x=b.x;b.x+=450*dt*b.direction
 var options=targets(b.row,(old_x+b.x)/2,absf(b.x-old_x)/2+24,true)
 options.sort_custom(func(a,c):return position(a)<position(c) if b.direction>0 else position(a)>position(c))
 for target in options:
  if target.id in b.hit:continue
  damage(target,b.damage);b.hit.append(target.id)
  if b.hit.size()>=4:
   if b.direction>0:b.turn=true;b.pause=0.25
   else:b.alive=false
   break
 if b.direction>0 and b.x>=1510:b.turn=true;b.pause=0.25
 if b.direction<0 and b.x<=b.origin:b.alive=false
 return true
func block_straight(b,old_x):
 var options=graves.filter(func(g):return g.hp>0 and g.row==b.row and position(g)+24>=old_x and position(g)-24<=b.x and g.id not in b.hit)
 options.sort_custom(func(a,c):return a.col<c.col)
 for grave in options:
  var nearer=game.zombies.any(func(z):return z.hp>0 and z.row==b.row and z.x+24>=old_x and z.x<position(grave) and z.id not in b.hit)
  if nearer and not b.power:return false
  damage(grave,b.damage);b.hit.append(grave.id)
  if not b.power:b.alive=false;return true
 return false
func start_power(p):
 if p.key=="cabbage":
  p.pf_loop=game.animations.duration("cabbage","plantfood");p.pf_next=0.3;p.pf_remaining=1
 elif p.key=="bonk":p.pf_loop=3.0;p.pf_remaining=30;p.pf_total=30;p.pf_next=0
 elif p.key=="mine":
  p.age=10;p.pf_remaining=1;p.pf_next=0.1;p.pf_loop=game.animations.duration("mine","plantfood")
func tick_power(p,elapsed):
 if p.key=="cabbage" and p.pf_remaining>0 and elapsed>=p.pf_next:
  p.pf_remaining=0
  for z in game.zombies:
   if z.hp>0:lob(p,z,200)
 elif p.key=="bonk":
  while p.pf_remaining>0 and elapsed+0.0001>=p.pf_next:
   var home=game.center_at(p.col,p.row)
   for target in game.zombies+graves:
    if target.hp>0 and abs(target.row-p.row)<=1 and absf(position(target)-home.x)<96:damage(target,70)
   p.pf_remaining-=1;p.pf_next+=0.1
 elif p.key=="mine" and p.pf_remaining>0 and elapsed>=p.pf_next:
  p.pf_remaining=0
  var spaces=[]
  for row in range(5):
   for col in range(9):
    if game.plant_at(col,row)==null and grave_at(col,row)==null:spaces.append(Vector2i(col,row))
  for i in range(mini(2,spaces.size())):
   var index=game.rng.randi_range(0,spaces.size()-1);var cell=spaces[index];spaces.remove_at(index)
   if game.place("mine",cell.x,cell.y,true):game.plants[-1].age=10;game.plants[-1].pose="idle"
func draw_graves():
 for grave in graves:
  if grave.hp<=0:continue
  var stage=clampi(int((1-grave.hp/700.0)*5),0,4)
  game.animations.draw_actor(game,"grave",game.center_at(grave.col,grave.row),1.0,0,"undamaged" if stage==0 else "damage%d"%stage)
  if grave.hp<700:game.health_bar(game.center_at(grave.col,grave.row)+Vector2(-29,32),58,grave.hp/700.0,Color("d5b88e"))
func draw_effects():
 for blast in blasts:game.animations.draw_actor(game,"mine_fx",blast.pos,1.8,blast.age,"animation")
