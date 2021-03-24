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
  l.debug=args.debug

  l.voice={} -- list of voices and how hold they are
  for i=1,VOICE_NUM do
    l.voice[i]={age=current_time(),note=0}
  end

  local debounce_delaytime=0

  params:add_group("SHADOW",11)
  local filter_freq=controlspec.new(40,18000,'exp',0,18000,'Hz')
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
  params:add {
    type='control',
    id="destruction",
    name="destruction",
  controlspec=controlspec.new(0,3,'lin',0,0.0,'s',0.1/3)}
  params:set_action("destruction",function(v)
    engine.destruction(v)
  end)
  params:bang()

  clock.run(function()
    local debounce_delaytime_0=0
    while true do -- while it's running...
      clock.sleep(0.1) -- refresh
      if debounce_delaytime>0 then
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
      -- TODO: make this behavior optional
      if self.voice[i].feedback~=nil and self.voice[i].feedback>1 then
        params:set("feedback",self.voice[i].feedback)
      end
      self.voice[i].age=current_time()
      self.voice[i].note=0
      engine.shadowoff(i)
      do return end
    end
  end
end

function Shadow:get_voice(note)
  local oldest={i=0,age=0}

  -- gets voice if its already a note
  for i,voice in ipairs(self.voice) do
    if voice.note==note then
      print("voice note "..i..note)
      oldest={i=i,age=voice.age}
    end
  end

  -- gets voice based on the newest that is not being used
  if oldest.i==0 then
    for i,voice in ipairs(self.voice) do
      print(i,voice.age,oldest.age,voice.note)
      if voice.age>oldest.age and (voice.note==0 or voice.note==nil) then
        print("newest voice "..i)
        oldest={i=i,age=voice.age}
      end
    end
    -- found none - now just take the oldest
    if oldest.i==0 then
      print("just taking newest")
      for i,voice in ipairs(self.voice) do
        if voice.age>oldest.age then
          oldest={i=i,age=voice.age}
        end
      end
      -- still found none, just take the first
      if oldest.i==0 then
        oldest.i=1
      end
    end
  end

  -- turn off voice
  -- oldest.i=1
  print("using voice "..oldest.i)
  engine.shadowoff(oldest.i)
  self.voice[oldest.i].age=current_time()
  self.voice[oldest.i].note=note
  if params:get("feedback")>1 then
    self.voice[oldest.i].feedback=params:get("feedback")
  end
  params:set("feedback",0.9)
  return oldest.i
end


return Shadow
