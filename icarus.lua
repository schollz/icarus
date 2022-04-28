-- icarus v1.3.0
--
-- I warn you, fly a middle
-- course: go too low & water
-- will weigh you down;
-- go too high and the sun's
-- fire will burn you.
-- keep to the middle way.
--
-- (plug in midi keyboard first)
-- E1 = time
-- E2 = filter
-- E3 = feedback
-- K1,2,3 bounce
-- speeding up time more easily
-- destroys the sun
engine.name="Icarus"
icarus=include("icarus/lib/icarus")
local MusicUtil=require "musicutil"
local Formatters=require 'formatters'
local feedback_temp=0
local vol_current=0
local vol_target=0
local time_change=0
local time_button=false
local filter_change=0
local filter_button=false
local current_time=0

function init()
  skeys=icarus:new()

  setup_midi()
  -- osc input
  osc.event=osc_in
  clock.run(redraw_clock)
end

function keyboard.midi_setup()
  -- setup keyboard code
  os.execute("aconnect -x; aconnect 128:0 14:0; aconnect 14:0 128:0")
  keyboard.midi=midi.connect(1) -- virtual port
end

function keyboard.code(code,value)
  if value==1 then
    keyboard.midi:note_on(string.byte(code),math.random(60,90))
  elseif value==0 then 
    keyboard.midi:note_off(string.byte(code))
  end
end

function setup_midi()
  keyboard.midi_setup()
  
  -- get list of devices
  local mididevice={}
  local mididevice_list={"none"}
  midi_channels={"all"}
  for i=1,16 do
    table.insert(midi_channels,i)
  end
  for _,dev in pairs(midi.devices) do
    if dev.port~=nil then
      local name=string.lower(dev.name)
      table.insert(mididevice_list,name)
      print("adding "..name.." to port "..dev.port)
      mididevice[name]={
        name=name,
        port=dev.port,
        midi=midi.connect(dev.port),
        active=false,
      }
      mididevice[name].midi.event=function(data)
        if mididevice[name].active==false then
          do return end
        end
        local d=midi.to_msg(data)
        --if d.type~="clock" then
        --  tab.print(d)
        --end
        if d.ch~=midi_channels[params:get("midichannel")] and params:get("midichannel")>1 then
          do return end
        end
        if d.type=="note_on" then
          skeys:on(d.note)
        elseif d.type=="note_off" then
          skeys:off(d.note)
        elseif d.type=="pitchbend" then
          local bend_st = (util.round(d.val / 2)) / 8192 * 2 -1 -- Convert to -1 to 1
          engine.bend(bend_st * params:get("bend_range"))
        end
      end
    end
  end
  tab.print(mididevice_list)

  params:add{type="option",id="midi",name="midi in",options=mididevice_list,default=1}
  params:set_action("midi",function(v)
    if v==1 then
      do return end
    end
    for name,_ in pairs(mididevice) do
      mididevice[name].active=false
    end
    mididevice[mididevice_list[v]].active=true
  end)
  params:add{type="option",id="midichannel",name="midi ch",options=midi_channels,default=1}
  params:add_number("bend_range", "bend range", 0, 48, 2)

  if #mididevice_list>1 then
    params:set("midi",2)
  end
end


function enc(k,d)
  if k==1 then
    params:delta("delaytime",d)
    if params:get("delaytime")<0.25 then
       params:delta("destruction",d)
    --   params:set("pressdisablesfeedback",2)
    else
    --   params:set("pressdisablesfeedback",1)
    end
  elseif k==2 then
    params:delta("lpf",-1*sign(d))
  elseif k==3 then
    params:delta("feedback",d)
  end
end

function key(k,z)
  if k==1 then
    time_button=z==1
  elseif k==2 then
    filter_button=z==1
  elseif k==3 then
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
    -- if time button is on, do some shifting
    if time_button then
      time_change=time_change-1
      params:delta("delaytime",3)
    elseif time_change<0 then
      time_change=time_change+1
      params:delta("delaytime",-3)
    end
    if filter_button then
      filter_change=filter_change-1
      params:delta("lpf",-1)
    elseif filter_change<0 then
      filter_change=filter_change+1
      params:delta("lpf",1)
    end
    -- have this clock move target volume to current volume
    if math.abs(vol_target-vol_current)>0.005 then
      vol_current=vol_current+sign(vol_target-vol_current)/200
    end
    -- print(vol_current,vol_target)
    clock.sleep(1/14) -- refresh
    current_time=current_time+1/14
    redraw()
  end
end

function redraw()
  screen.clear()

  -- make the sun curve in the sky based on delay time
  local delay_range={0.05,0.5}
  local rdelay=util.linlin(delay_range[1],delay_range[2],270,90,params:get("delaytime"))
  local center={64,32}
  local rpos={center[1]+40*math.sin(math.rad(rdelay)),center[2]+40*math.cos(math.rad(rdelay))}
  local rfeedback=util.linlin(0.9,1.5,4,20,params:get("feedback"))
  local rvolume=util.linlin(0,1,0,32,vol_current)
  local rlow=rfeedback
  local rhigh=rfeedback+rvolume
  for i=rhigh,rlow,-1 do
    local ll=math.floor(util.linlin(rlow,rhigh,14,1,i))
    screen.level(ll)
    i=i*math.pow(1.5,1/ll)
    screen.circle(rpos[1],rpos[2]+10,i)
    screen.fill()
  end
  screen.level(15)
  screen.circle(rpos[1],rpos[2]+10,rfeedback)
  screen.fill()
  screen.update()
  -- the ocean
  local rfilter=util.linlin(0,18000,20,62,params:get("lpf"))
  -- screen.level(0)
  -- screen.rect(0,rfilter,129,65)
  -- screen.fill()
  -- -- draw reflection of the sun in the water
  -- screen.level(1)
  -- screen.move(0,rfilter)
  -- screen.line(129,rfilter)
  -- screen.stroke()
  -- screen.level(10)
  -- for i=1,10 do
  --   screen.level(11-i)
  --   screen.move(rpos[1]-rfeedback/i*0.8,rfilter+i*2)
  --   screen.line(rpos[1]+rfeedback/i*0.8,rfilter+i*2)
  --   screen.stroke()
  -- end
  local horizon=math.floor(rfilter)
  --cls()
  -- circfill(30,22,15,7)
  screen.update()
  math.randomseed(4)
  screen.level(0)
  screen.rect(0,rfilter,129,65)
  screen.fill()
  for y=0,64 do
    local z=64/(y+1)
    for i=0,z*5 do
      x=(rnd(160)+current_time*160/z)%150-16
      w=cos(rnd()+current_time)*12/z
      if (w>0) then
        local s = screen.peek(math.floor(x),math.floor(horizon-1-y/2), math.floor(x+1),math.floor(horizon-y/2))
        if s ~= nil then
          local pgot = util.clamp(string.byte(s,1),1,15)
          screen.level(pgot+1)
          screen.move(x-w,y+horizon)
          screen.line(x+w,y+horizon)
          screen.stroke()
        end
      end
    end
  end

  screen.update()
end

--- Cos of value
-- Value is expected to be between 0..1 (instead of 0..360)
-- @param x value
function cos(x)
  return math.cos(math.rad(x * 360))
end

function rnd(x)
  if x == 0 then
    return 0
  end
  if (not x) then
    x = 1
  end
  x = x * 100
  x = math.random(x) / 100
  return x
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
function osc_in(path,args,from)
  vol_target=util.linlin(0,0.15,0,1,args[2])
end

