-- Turtle movement and position functions. --
local _pos = {x = 0, y = 0, z = 0, orient = 0}
local _posFuel = {x = 1, y = 0, z = 0}

-- Calculates taxi-cab distance from current location to specified location. --
local function _distanceTo(x, y, z)
  assert(type(x) == "number" and type(y) == "number" and type(z) == "number",
         "Requires valid x, y, and z arguments.")
  return math.abs(_pos.x - x) + math.abs(_pos.y - y) + math.abs(_pos.z - z)
end

-- Determines if turtle has enough fuel to reach refuelling station. --
local function _refuelInRange()
  assert(type(x) == "number" and type(y) == "number" and type(z) == "number",
         "Requires valid x, y, and z arguments.")
  local fuelLevel = turtle.getFuelLevel()
  local distToFuel = _distanceTo(_posFuel.x, _posFuel.y, _posFuel.z)
  return fuelLevel > distToFuel
end

function forward()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspect() then
    turtle.dig()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.forward()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.y = _pos.y + 1
    elseif _pos.orient == 1 then
      _pos.x = _pos.x + 1
    elseif _pos.orient == 2 then
      _pos.y = _pos.y - 1
    elseif _pos.orient == 3 then
      _pos.x = _pos.x - 1
    end
  end
  return unpack(successfulMove)
end

function back()
  -- Move into position and record movement. --
  local successfulMove = {turtle.back()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.y = _pos.y - 1
    elseif _pos.orient == 1 then
      _pos.x = _pos.x - 1
    elseif _pos.orient == 2 then
      _pos.y = _pos.y + 1
    elseif _pos.orient == 3 then
      _pos.x = _pos.x + 1
    end
  end
  return unpack(successfulMove)
end

function up()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspectUp() then
    turtle.digUp()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.up()}
  if successfulMove[1] then
    _pos.z = _pos.z + 1
  end
  return unpack(successfulMove)
end

function down()
  -- Check if a block is in the way.  If so, remove it. --
  if turtle.inspectDown() then
    turtle.digDown()
  end
  -- Move into position and record movement. --
  local successfulMove = {turtle.down()}
  if successfulMove[1] then
    _pos.z = _pos.z - 1
  end
  return unpack(successfulMove)
end

function turnRight()
  local successfulMove = {turtle.turnRight()}
  if successfulMove[1] then
    if _pos.orient == 3 then
      _pos.orient = 0
    else
      _pos.orient = _pos.orient + 1
    end
  end
  return unpack(successfulMove)
end

function turnLeft()
  local successfulMove = {turtle.turnLeft()}
  if successfulMove[1] then
    if _pos.orient == 0 then
      _pos.orient = 3
    else
      _pos.orient = _pos.orient - 1
    end
  end
  return unpack(successfulMove)
end

function faceOrientation(orient)
  if (orient - _pos.orient) % 4 > 2 then
    while _pos.orient ~= orient do
      turnLeft()
    end
  else
    while _pos.orient ~= orient do
      turnRight()
    end
  end
  return true
end

function goTo(x, y, z)
  assert(type(x) == "number" and type(y) == "number",
         "Must supply both x and y coordinates.")
  z = z or _pos.z
  -- Verify we have enough fuel to get there. --
  if turtle.getFuelLevel() < _distanceTo(x,y,z) then
    return false, "Not enough fuel."
  end
  local successfulMove
  -- Move in z-direction first. --
  if _pos.z ~= z then
    local zDirUp = _pos.z > z and 0 or 1
    while _pos.z ~= z do
      successfulMove = zDirUp == 1 and {up()} or {down()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Move in y-direction. --
  if _pos.y ~= y then
    if _pos.y > y then faceOrientation(2) else faceOrientation(0) end
    while _pos.y ~= y do
      successfulMove = {forward()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Move in x-direction. --
  if _pos.x ~= x then
    if _pos.x > x then faceOrientation(3) else faceOrientation(1) end
    while _pos.x ~= x do
      successfulMove = {forward()}
      if not successfulMove[1] then return unpack(successfulMove) end
    end
  end
  -- Face in the starting direction. --
  faceOrientation(0)
  return true
end

function goHome()
  goTo(0,0,0)
end

function setHome()
  _pos.x = 0
  _pos.y = 0
  _pos.z = 0
  _pos.orient = 0
end

-- Empty a turtle's inventory into an inventory below it. --
-- Optional argument can be an array of slots to ignore.                      --
-- Restores the selected slot to slot selected when function was called.      --
function emptyInventoryDown(keepslots)
  local oldSlot = turtle.getSelectedSlot()
  local slotsToKeep = {}
  -- Pull out the values and use as keys. --
  if keepslots then
    for _, i in ipairs(keepslots) do
      slotsToKeep[i] = true
    end
  end
  for i = 1,16 do
    if not slotsToKeep[i] and turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.dropDown()
    end
  end
  turtle.select(oldSlot)
end

-- Find slot containing to itemName.  Returns false on failure. --
function findItemSlot(itemName, damage)
  local data, found, slot = nil, false, 0
  while slot < 16 and not found do
    slot = slot + 1
    data = turtle.getItemDetail(slot)
    if data then
      found = data.name == itemName
      if damage then found = found and data.damage == damage end
    end
  end
  return found and slot
end

-- Find the first empty slot.  Returns false on failure. --
function findEmptyItemSlot()
  local slot, empty = 0, false
  while slot < 16 and not empty do
    slot = slot + 1
    empty = turtle.getItemCount(slot) < 1
  end
  return empty and slot
end
