-- modulate for samples
--

local MusicUtil=require "musicutil"
local Formatters=require 'formatters'

local Icarus={}

local VOICE_NUM=4

local function current_time()
  return os.time()
end


function Icarus:new(args)
  local l=setmetatable({},{__index=Icarus})
  local args=args==nil and {} or args
  l.debug=args.debug

  l.voice={} -- list of voices and how hold they are
  for i=1,VOICE_NUM do
    l.voice[i]={age=current_time(),note=0}
  end

  local debounce_delaytime=0

  params:add_group("ICARUS",17)
  local filter_freq=controlspec.new(40,18000,'exp',0,18000,'Hz')
  params:add_option("polyphony","polyphony",{"monophonic","polyphonic"},2)
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
    id="sub",
    name="sub",
  controlspec=controlspec.new(0,10,'lin',0,0.5,'amp')}
  params:set_action("sub",function(v)
    engine.sub(v)
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
  controlspec=controlspec.new(0.5,1.5,'lin',0,0.93,'',0.01/1)}
  params:set_action("feedback",function(v)
    engine.feedback(v)
  end)
  params:add_option("pressdisablesfeedback","press disables feedback",{"no","yes"},1)
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
  -- params:add {
  --   type='control',
  --   id="tremelo",
  --   name="tremelo",
  -- controlspec=controlspec.new(0,64,'lin',0,0.0,'8th notes',1/64)}
  -- params:set_action("tremelo",function(v)
  --   engine.tremelo(v/(clock.get_beat_sec()/8))
  -- end)
  params:add {
    type='control',
    id="destruction",
    name="destruction",
  controlspec=controlspec.new(0,30,'lin',0,0.0,'hz',0.1/30)}
  params:set_action("destruction",function(v)
    engine.destruction(v)
  end)
  params:add {
    type='control',
    id="pwmcenter",
    name="pwm center",
  controlspec=controlspec.new(0,1,'lin',0,0.5,'',0.1/1)}
  params:set_action("pwmcenter",function(v)
    engine.pwmcenter(v)
  end)
  params:add {
    type='control',
    id="pwmwidth",
    name="pwm width",
  controlspec=controlspec.new(0,1,'lin',0,0.05,'',0.01/1)}
  params:set_action("pwmwidth",function(v)
    engine.pwmwidth(v)
  end)
  params:add {
    type='control',
    id="pwmfreq",
    name="pwm freq",
  controlspec=controlspec.new(0,200,'lin',0,3,'hz',1/200)}
  params:set_action("pwmfreq",function(v)
    engine.pwmfreq(v)
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

function Icarus:reset()
  for i,_ in ipairs(self.voice) do
    self.voice[i]={age=current_time(),note=0} -- reset voices
  end
end

function Icarus:on(note,velocity)
  voice=self:get_voice(note)
  engine.icaruson(
    voice,
  MusicUtil.note_num_to_freq(note))
  return voice
end

function Icarus:off(note)
  -- find the voice being used for this one
  for i,voice in ipairs(self.voice) do
    if voice.note==note then
      -- this is the one!
      if self.debug then
        print("icarus: turning off "..note)
      end
      if params:get("pressdisablesfeedback")==2 and self.voice[i].feedback~=nil and self.voice[i].feedback>1 and params:get("feedback")==0.9 then
        params:set("feedback",self.voice[i].feedback)
        self.voice[i].feedback=nil
      end
      self.voice[i].age=current_time()
      self.voice[i].note=0
      engine.icarusoff(i)
      do return end
    end
  end
end

function Icarus:get_voice(note)
  local oldest={i=0,age=0}
  if params:get("polyphony")==1 then
    oldest.i=1
  end

  if oldest.i==0 then
    -- gets voice if its already a note
    for i,voice in ipairs(self.voice) do
      if voice.note==note then
        print("voice note "..i..note)
        oldest={i=i,age=voice.age}
      end
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
  engine.icarusoff(oldest.i)
  self.voice[oldest.i].age=current_time()
  self.voice[oldest.i].note=note
  if params:get("pressdisablesfeedback")==2 and params:get("feedback")>1 then
    self.voice[oldest.i].feedback=params:get("feedback")
    params:set("feedback",0.9)
  end
  return oldest.i
end


return Icarus
