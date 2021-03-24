-- modulate for samples
--

local MusicUtil=require "musicutil"
local Formatters=require 'formatters'

local Shadow={}

local VOICE_NUM=4

local function current_time()
  return os.time()
end


function Shadow:new(args)
  local l=setmetatable({},{__index=Shadow})
  local args=args==nil and {} or args
  l.debug = args.debug

  -- get list of devices
  local mididevice = {}
  local mididevice_list = {"none"}
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
        if mididevice[name].active == false then 
          do return end
        end
        if (data[1]==144 or data[1]==128) then
          tab.print(data)
          if data[1]==144 and data[3] > 0 then
            -- TODO make this separate
            l:on(data[2])
            -- skeys:on({name=available_instruments[instrument_current].id,midi=data[2],velocity=data[3]})
          elseif data[1]==128 or data[3] == 0 then
            l:off(data[2])
            -- skeys:off({name=available_instruments[instrument_current].id,midi=data[2]})
          end
        end
      end
    end
  end
  tab.print(mididevice_list)

  l.voice={} -- list of voices and how hold they are
  for i=1,VOICE_NUM do
    l.voice[i]={age=current_time(),active={name="",midi=0}}
  end

  local debounce_delaytime=0

  params:add_group("SHADOW",11)
  local filter_freq=controlspec.new(40,18000,'exp',0,18000,'Hz')
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
  params:add {
    type='control',
    id="amp",
    name="amp",
  controlspec=controlspec.new(0,10,'lin',0,1.0,'amp')}
  params:set_action("amp",function(v)
    engine.amp(v)
  end)
  params:add {
    type='control',
    id="pan",
    name="pan",
  controlspec=controlspec.new(-1,1,'lin',0,0)}
  params:set_action("pan",function(v)
    engine.pan(v)
  end)
  params:add {
    type='control',
    id="attack",
    name="attack",
  controlspec=controlspec.new(0,10,'lin',0,0.5,'s')}
  params:set_action("attack",function(v)
    engine.attack(v)
  end)
  params:add {
    type='control',
    id="decay",
    name="decay",
  controlspec=controlspec.new(0,10,'lin',0,1,'s')}
  params:set_action("decay",function(v)
    engine.decay(v)
  end)
  params:add {
    type='control',
    id="sustain",
    name="sustain",
  controlspec=controlspec.new(0,2,'lin',0,0.9,'amp')}
  params:set_action("sustain",function(v)
    engine.sustain(v)
  end)
  params:add {
    type='control',
    id="release",
    name="release",
  controlspec=controlspec.new(0,10,'lin',0,5,'s')}
  params:set_action("release",function(v)
    engine.release(v)
  end)
  params:add {
    type='control',
    id='lpf',
    name='low-pass filter',
    controlspec=filter_freq,
    formatter=Formatters.format_freq
  }
  params:set_action("lpf",function(v)
    engine.lpf(v)
  end)
  params:add {
    type='control',
    id="feedback",
    name="feedback",
  controlspec=controlspec.new(0.5,1.5,'lin',0,1.0,'',0.01/1)}
  params:set_action("feedback",function(v)
    engine.feedback(v)
  end)
  params:add {
    type='control',
    id="delaytime",
    name="delay time",
  controlspec=controlspec.new(15,30,'lin',0,25,'x100 s',0.01/15)}
  params:set_action("delaytime",function(v)
    engine.delaytime(v/100)
    -- debounce_delaytime=v
  end)
  params:add {
    type='control',
    id="portamento",
    name="portamento",
  controlspec=controlspec.new(0,3,'lin',0,0.1,'s',0.1/3)}
  params:set_action("portamento",function(v)
    engine.portamento(v)
  end)
  params:bang()

  if #mididevice_list > 1 then
    params:set("midi",2)
  end

  clock.run(function()
    local debounce_delaytime_0=0
    while true do -- while it's running...
      clock.sleep(0.1) -- refresh
      if debounce_delaytime > 0 then 
          if debounce_delaytime_0==debounce_delaytime then
            print("setting delaytime "..debounce_delaytime)
            engine.delaytime(debounce_delaytime)
            debounce_delaytime=0
          end
          debounce_delaytime_0=debounce_delaytime
      end
    end
  end) 
  return l
end

function Shadow:reset()
  for i,_ in ipairs(self.voice) do
    self.voice[i]={age=current_time(),note=0} -- reset voices
  end
end

function Shadow:on(note,velocity)
  voice=self:get_voice(note)
  engine.shadowon(
    voice,
    MusicUtil.note_num_to_freq(note)  
  )
  return voice
end

function Shadow:off(note)
  -- find the voice being used for this one
  for i,voice in ipairs(self.voice) do
    if voice.note==note then
      -- this is the one!
      if self.debug then 
        print("shadow: turning off "..note)
      end
      self.voice[i].age=current_time()
      self.voice[i].note=0
      engine.shadowoff(i)
      do return end
    end
  end
end

function Shadow:get_voice(note)
  local oldest={i=0,age=current_time()}

  -- gets voice if its already a note
  for i,voice in ipairs(self.voice) do
    if voice.note==note then
      oldest={i=i,age=voice.age}
    end
  end

  -- gets voice based on the oldest that is not being used
  if oldest.i==0 then
    for i,voice in ipairs(self.voice) do
      if voice.age<oldest.age and voice.note==0 then
        oldest={i=i,age=voice.age}
      end
    end
    -- found none - now just take the oldest
    if oldest.i==0 then
      for i,voice in ipairs(self.voice) do
        if voice.age<oldest.age then
          oldest={i=i,age=voice.age}
        end
      end
      -- still found none, just take the first
      if oldest.i == 0 then 
        oldest.i = 1
      end
    end
  end

  -- turn off voice
  oldest.i=1
  engine.shadowoff(oldest.i)
  self.voice[oldest.i].age=current_time()
  self.voice[oldest.i].note=note
  return oldest.i
end


return Shadow
