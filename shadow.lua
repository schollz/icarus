-- shadow v0.0.1

engine.name="Shadow"
shadow=include("shadow/lib/shadow")
local MusicUtil=require "musicutil"
local Formatters=require 'formatters'

function init()
  skeys=shadow:new()
  -- osc input 
  osc.event = osc_in
  clock.run(redraw_clock) 
end


function enc(k,d)

end

function key(k,z)

end

function redraw_clock() -- our grid redraw clock
  while true do -- while it's running...
    clock.sleep(1/30) -- refresh
    redraw()
  end
end

function redraw()
  screen.clear()

  screen.update()
end

function rerun()
  norns.script.load(norns.state.script)
end

--
-- osc
-- 
function osc_in(path, args, from)
  -- print("------")
  -- print(path)
  -- tab.print(args)
  -- print(from)
end