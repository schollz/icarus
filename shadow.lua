-- shadow v0.0.1

engine.name="Shadow"
shadow=include("shadow/lib/shadow")
local MusicUtil=require "musicutil"
local Formatters=require 'formatters'
local feedback_temp=0
local vol_current=0
local vol_target=0

function init()
  skeys=shadow:new()
  -- osc input 
  osc.event = osc_in
  clock.run(redraw_clock) 
end


function enc(k,d)
  if k==2 then 
    params:delta("lpf",d)
  elseif k==3 then 
    params:delta("feedback",d)
  end
end

function key(k,z)
  if k==2 then
    if z==1 then
      feedback_temp=params:get("feedback")
      params:set("feedback",0.85)
    else
      params:set("feedback",feedback_temp)
    end
  end

end

function redraw_clock() -- our grid redraw clock
  while true do -- while it's running...
    -- have this clock move target volume to current volume
    vol_current = vol_current+sign(vol_target-vol_current)/10
    clock.sleep(1/30) -- refresh
    redraw()
  end
end

function redraw()
  screen.clear()
  local rfilter = util.linlin(0,18000,2,144,params:get("lpf"))
  local rfeedback = util.linlin(0.9,1.5,0,16,params:get("feedback"))
  local rvolume = util.linlin(0,1,0,rfilter+16,vol_current)
  local rlow = rfeedback
  local rhigh = rfeedback+rvolume
  for i=rhigh,rlow,-1 do
    local ll=math.floor(util.linlin(rlow,rhigh,14,1,i))
    screen.level(ll)
    i = i*math.pow(2.1,1/ll)
    screen.circle(64,32,i)
    screen.fill()
  end
  screen.level(15)
  screen.circle(64,32,rfeedback)
  screen.fill()

  screen.update()
end

function rerun()
  norns.script.load(norns.state.script)
end

function sign(x)
  if x>0 then
    return 1
  elseif x<0 then
    return-1
  else
    return 0
  end
end


--
-- osc
-- 
function osc_in(path, args, from)
  vol_target = util.linlin(0,0.15,0,1,args[2])
end