-- icarus v0.0.1

engine.name="Icarus"
icarus=include("icarus/lib/icarus")
local MusicUtil=require "musicutil"
local Formatters=require 'formatters'
local feedback_temp=0
local vol_current=0
local vol_target=0

function init()
  skeys=icarus:new()

  setup_midi()
  -- osc input
  osc.event=osc_in
  clock.run(redraw_clock)
end

function setup_midi()
  -- get list of devices
  local mididevice={}
  local mididevice_list={"none"}
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
        if (data[1]==144 or data[1]==128) then
          tab.print(data)
          if data[1]==144 and data[3]>0 then
            -- TODO make this separate
            skeys:on(data[2])
            -- skeys:on({name=available_instruments[instrument_current].id,midi=data[2],velocity=data[3]})
          elseif data[1]==128 or data[3]==0 then
            skeys:off(data[2])
            -- skeys:off({name=available_instruments[instrument_current].id,midi=data[2]})
          end
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


  if #mididevice_list>1 then
    params:set("midi",2)
  end
end


function enc(k,d)
  if k==1 then
    params:delta("lpf",d)
  elseif k==2 then 
    params:delta("delaytime",d)
  elseif k==3 then
    params:delta("feedback",d)
  end
end

function key(k,z)
  -- TODO: press k2 to activate momentary delay
  if k==3 then
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
    vol_current=vol_current+sign(vol_target-vol_current)/10
    clock.sleep(1/30) -- refresh
    redraw()
  end
end

function redraw()
  screen.clear()

  -- make the sun curve in the sky based on delay time
  local delay_range=params:get_range("delaytime")
  local rdelay=util.linlin(delay_range[1],delay_range[2],-90,90,params:get("delaytime"))
  local center={64,32}
  local rpos={center[1]+32*math.sin(math.rad(rdelay)),center[2]+32*math.cos(math.rad(rdelay))}
  local rfeedback=util.linlin(0.9,1.5,0,16,params:get("feedback"))
  local rvolume=util.linlin(0,1,0,144,vol_current)
  local rlow=rfeedback
  local rhigh=rfeedback+rvolume
  for i=rhigh,rlow,-1 do
    local ll=math.floor(util.linlin(rlow,rhigh,14,1,i))
    screen.level(ll)
    i=i*math.pow(2.1,1/ll)
    screen.circle(rpos[1],rpos[2],i)
    screen.fill()
  end
  screen.level(15)
  screen.circle(rpos[1],rpos[2],rfeedback)
  screen.fill()
  -- the ocean
  local rfilter=util.linlin(0,18000,0,64,params:get("lpf"))
  screen.level(15)
  screen.rect(0,rfilter,65,65)
  -- draw reflection of the sun in the water
  screen.level(10)
  for level,i in ipairs({2,4,6,8,10,12,14}) do
    screen.level(11-level)
    screen.move(rpos[1]-rfeedback/i,rfilter+i)
    screen.line(rpos[1]+rfeedback/i,rfilter+i)
  end
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
function osc_in(path,args,from)
  vol_target=util.linlin(0,0.15,0,1,args[2])
end
 