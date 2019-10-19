-- Dependencies. --
assert(ig, "igturtle API requires ig API")

-- Position abstraction. --
local Position = {}

function Position:makePosition(o)
    setmetatable(o, self)
    self.__index = self
    return o
end

function Position:new()
    local o = {x=0, y=0, z=0}
    return self:makePosition(o)
end

function Position:copy()
    local o = self:new()
    o.x, o.y, o.z = self.x, self.y, self.z
    return o
end

function Position:distanceTo(other)
    return math.abs(self.x - other.x) + math.abs(self.y - other.y) +
           math.abs(self.z - other.z)
end

function Position:add(other)
    self.x = self.x + other.x
    self.y = self.y + other.y
    self.z = self.z + other.z
end

-- Orientation abstraction. --
local Orientation = {
    -- Change in position when moving "forward" in given orientation. --
    FORWARD = {
        {x=0, y=1, z=0},
        {x=1, y=0, z=0},
        {x=0, y=-1, z=0},
        {x=-1, y=0, z=0}
    },
    -- Change in position when moving "backward" in given orientation. --
    BACK = {
        {x=0, y=-1, z=0},
        {x=-1, y=0, z=0},
        {x=0, y=1, z=0},
        {x=1, y=0, z=0}
    }
}

function Orientation:new()
    local o = {orient=1}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Orientation:copy()
    local o = self:new()
    o.orient = self.orient
    return o
end

function Orientation:turnLeft()
    if self.orient == 1 then
        self.orient = 4
    else
        self.orient = self.orient - 1
    end
end

function Orientation:turnRight()
    if self.orient == 4 then
        self.orient = 1
    else
        self.orient = self.orient + 1
    end
end

-- Turtle singleton. --
local IgTurtle = {
    pos = Position:new(),
    fuelPos = Position:makePosition{x=1, y=0, z=0},
    orient = Orientation:new()
}

-- Determines if turtle has enough fuel to reach refuelling station. --
function IgTurtle:refuelInRange()
    return turtle.getFuelLevel() > self.pos:distanceTo(self.fuelPos)
end

function IgTurtle:forward()
    -- Check if a block is in the way.  If so, remove it. --
    if turtle.inspect() then
        turtle.dig()
    end
    -- Move into position and record movement. --
    local successfulMove = {turtle.forward()}
    if successfulMove[1] then
        self.pos:add(Orientation.FORWARD[self.orient.orient])
    end
    return unpack(successfulMove)
end

function IgTurtle:back()
    -- Move into position and record movement. --
    local successfulMove = {turtle.back()}
    if successfulMove[1] then
        self.pos:add(Orientation.BACK[self.orient.orient])
    end
    return unpack(successfulMove)
end

function IgTurtle:up()
    -- Check if a block is in the way.  If so, remove it. --
    if turtle.inspectUp() then
        turtle.digUp()
    end
    -- Move into position and record movement. --
    local successfulMove = {turtle.up()}
    if successfulMove[1] then
        self.pos:add({x=0,y=0,z=1})
    end
    return unpack(successfulMove)
end

function IgTurtle:down()
    -- Check if a block is in the way.  If so, remove it. --
    if turtle.inspectDown() then
        turtle.digDown()
    end
    -- Move into position and record movement. --
    local successfulMove = {turtle.down()}
    if successfulMove[1] then
        self.pos:add({x=0,y=0,z=-1})
    end
    return unpack(successfulMove)
end

function IgTurtle:turnRight()
    local successfulMove = {turtle.turnRight()}
    if successfulMove[1] then
        self.orient:turnRight()
    end
    return unpack(successfulMove)
end

function IgTurtle:turnLeft()
    local successfulMove = {turtle.turnLeft()}
    if successfulMove[1] then
        self.orient:turnLeft()
    end
    return unpack(successfulMove)
end

function IgTurtle:turnToFace(orient)
    if (orient - self.orient.orient) % 4 > 2 then
        while self.orient.orient ~= orient do
            self:turnLeft()
        end
    else
        while self.orient.orient ~= orient do
            self:turnRight()
        end
    end
end

function IgTurtle:goTo(dest)
    local pos = self.pos
    if turtle.getFuelLevel() < pos:distanceTo(dest) then
        return false, "not enough fuel"
    end

    local successfulMove
    -- z-direction --
    if pos.z ~= dest.z then
        local zDirUp = pos.z > dest.z and 0 or 1
        while pos.z ~= dest.z do
            successfulMove = zDirUp == 1 and {self:up()} or {self:down()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
    -- y-direction --
    if pos.y ~= dest.y then
        if pos.y > dest.y then self:turnToFace(3) else self:turnToFace(1) end
        while pos.y ~= dest.y do
            successfulMove = {self:forward()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
    -- x-direction --
    if pos.x ~= dest.x then
        if pos.x > dest.x then self:turnToFace(4) else self:turnToFace(2) end
        while pos.x ~= dest.x do
            successfulMove = {self:forward()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
end

function IgTurtle:goHome()
    self:goTo{x=0,y=0,z=0}
end

-- Sets the home position of the turtle to its current position. --
function IgTurtle:setHome()
    self.pos = Position:new()
    self.orient = Orientation:new()
end

-- Sets the location of the fuel source. --
-- Should be set after every call to setHome().                               --
function IgTurtle:setRefuel(pos)
    pos = (type(pos) == "table" and pos.x and pos.y and pos.z) and pos or self.pos
    self.fuelPos = Position:makePosition(pos):copy()
end

-- Refuel the turtle. --
-- Sends the turtle to the refuel station to get fuel and refuel itself.      --
-- Turtle returns to previous position after refueling.                       --
-- If the "enderfuel" option is provided, will place the ender chest in the   --
-- slot specified, pull fuel out of it, and pick it up again.                 --
function IgTurtle:refuel(options)
    options = options or {}
    local oldPos = self.pos:copy()
    if options.enderfuel then
        self:refuelFromEnderChest(options.enderfuel)
    else
        local emptySlot = self:findEmptyItemSlot()
        self:goTo(self.fuelPos)
        assert(emptySlot, "no empty slot available for refueling")
        self:refuelHere(emptySlot)
        self:goTo(oldPos)
    end
end

-- Refuel using the ender chest in the specified slot. --
function IgTurtle:refuelFromEnderChest(chestSlot)
    turtle.select(chestSlot)
    turtle.placeDown()
    self:refuelHere(chestSlot)
    turtle.digDown()
end

-- Refuel using the specified empty slot and fuel from an inventory below. --
function IgTurtle:refuelHere(emptySlot)
    turtle.select(emptySlot)
    turtle.suckDown(16)
    if not turtle.refuel() then
        print("No fuel available from fuel source.")
        print("Waiting for fuel.")
        ig.waitFor(turtle.refuel)
    end
end

-- Empty a turtle's inventory into an inventory below it. --
-- Optional argument can be an array of slots to ignore.                      --
-- Restores the selected slot to slot selected when function was called.      --
function IgTurtle:emptyInventoryDown(keepslots)
  local oldSlot = turtle.getSelectedSlot()
  local slotsToKeep = ig.arrayToSet(keepslots or {})
  for i = 1,16 do
    if not slotsToKeep[i] and turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.dropDown()
    end
  end
  turtle.select(oldSlot)
end

-- Find slot containing to itemName.  Returns false on failure. --
function IgTurtle:findItemSlot(itemName, damage)
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
function IgTurtle:findEmptyItemSlot()
  local slot, empty = 0, false
  while slot < 16 and not empty do
    slot = slot + 1
    empty = turtle.getItemCount(slot) < 1
  end
  return empty and slot
end

----------------
-- Public API --
----------------
function forward()
    return IgTurtle:forward()
end

function back()
    return IgTurtle:back()
end

function up()
    return IgTurtle:up()
end

function down()
    return IgTurtle:down()
end

function turnRight()
    return IgTurtle:turnRight()
end

function turnLeft()
    return IgTurtle:turnLeft()
end

local _faceOrientation_deprecation_printed = false

function faceOrientation(orient)
    if not _faceOrientation_deprecation_printed then
        print('igturtle.faceOrientation() is deprecated')
        print('use igturtle.turnToFace() from now on')
        _faceOrientation_deprecation_printed = true
    end
    return IgTurtle:turnToFace(orient)
end

function turnToFace(orient)
    return IgTurtle:turnToFace(orient)
end

function getPos()
    local pos = IgTurtle.pos:copy()
    pos.orient = IgTurtle.orient.orient
    return pos
end

function goTo(x, y, z)
    if type(x) == "table" then
        assert(type(x.x) == "number" and type(x.y) == "number",
               "goTo() table argument requires numerical x and y members")
        z = x.z or IgTurtle.pos.z
        y = x.y
        x = x.x
    end
    assert(type(x) == "number" and type(y) == "number",
           "goTo() requires both x and y coordinates as numbers")
    z = z or IgTurtle.pos.z
    return IgTurtle:goTo{x=x, y=y, z=z}
end

function goHome()
    return IgTurtle:goHome()
end

function setHome()
    return IgTurtle:setHome()
end

function setRefuel(pos)
    if type(pos) == "table" then
        assert(pos.x and pos.y and pos.z,
               "setRefuel() argument must be table with x, y, and z members")
    else pos = nil end
    return IgTurtle:setRefuel(pos)
end

function refuel(options)
    return IgTurtle:refuel(options)
end

function emptyInventoryDown(keepslots)
    return IgTurtle:emptyInventoryDown(keepslots)
end

function findItemSlot(itemName, damage)
    return IgTurtle:findItemSlot(itemName, damage)
end

function findEmptyItemSlot()
    return IgTurtle:findEmptyItemSlot()
end
