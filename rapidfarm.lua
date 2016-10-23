args = {...}
-- Check for API --
if not ig then
  local dirExists = fs.exists("/ig") or fs.makeDir("/ig") or fs.exists("/ig")
  assert(dirExists, "Error creating directory for Ignirtoq's API")
  local ig = fs.open("/ig/ig","w")
  ig.write(http.get("https://raw.githubusercontent.com/ignirtoq/cc-api/master/ig.lua").readAll())
  ig.close()
  assert(os.loadAPI("/ig/ig"),"Error loading API")
end
-- Get options --
dir = args[1] or "forward"
-- Direction functions --
local _inspect = {forward = turtle.inspect, down = turtle.inspectDown}
local _dig = {forward = turtle.dig, down = turtle.digDown}
local _place = {forward = turtle.place, down = turtle.placeDown}
local function harvest()
  if igturtle.findEmptyItemSlot() then
    _dig[dir]()
    _place[dir]()
  else ig.waitFor(igturtle.findEmptyItemSlot) end
end
local data
while true do
  data = {_inspect[dir]()}
  assert(data[1], "No crop found in front of turtle.")
  if data[2].metadata == 7 then harvest() end
  sleep(.25)
end
