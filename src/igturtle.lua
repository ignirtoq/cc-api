-- Dependencies. --
assert(ig, "igturtle API requires ig API")

-- Position abstraction. --
local Position = {}
local _PositionMt = getmetatable(Position) or {}
setmetatable(Position, _PositionMt)


function Position:new()
    return ig.clone(Position, {x=0, y=0, z=0})
end

function Position:clone(p)
    return ig.clone(Position, {x=p.x, y=p.y, z=p.z})
end

function Position:fromGps(g)
    return ig.clone(Position, {x=g[1], y=g[2], z=g[3]})
end


function Position:copy()
    return ig.clone(Position, {x=self.x, y=self.y, z=self.z})
end


function Position:distanceTo(other)
    return math.abs(self.x - other.x) + math.abs(self.y - other.y) +
           math.abs(self.z - other.z)
end


function Position:add(other)
    self.x = self.x + other.x
    self.y = self.y + other.y
    self.z = self.z + other.z
    return self
end


function Position:sub(other)
    self.x = self.x - other.x
    self.y = self.y - other.y
    self.z = self.z - other.z
    return self
end


function Position.sum(a, b)
    return Position:clone(a):add(b)
end


function Position.difference(a, b)
    return Position:clone(a):sub(b)
end


_PositionMt.__add = Position.sum
_PositionMt.__sub = Position.difference
_PositionMt.__tostring = ig.tableToString
_PositionMt.__eq = function(a, b) return a.x==b.x and a.y==b.y and a.z==b.z end


-- Orientation abstraction. --
local Orientation = {
    -- Change in position when moving "forward" in given orientation. --
    FORWARD_POS_CHANGE = {
        [0]={x=0, y=0, z=1},
        {x=1, y=0, z=0},
        {x=0, y=0, z=-1},
        {x=-1, y=0, z=0}
    },
    -- Change in position when moving "backward" in given orientation. --
    BACK_POS_CHANGE = {
        [0]={x=0, y=0, z=-1},
        {x=-1, y=0, z=0},
        {x=0, y=0, z=1},
        {x=1, y=0, z=0}
    }
}
local _OrientationMt = getmetatable(Orientation) or {}
setmetatable(Orientation, _OrientationMt)


function Orientation:new()
    return ig.clone(Orientation, {orient=0})
end


function Orientation:clone(o)
    return ig.clone(Orientation, {orient=o.orient})
end


function Orientation:copy()
    return ig.clone(Orientation, {orient=self.orient})
end


function Orientation:add(other)
    self.orient = (self.orient + other.orient) % 4
    return self
end


function Orientation:sub(other)
    self.orient = (self.orient - other.orient) % 4
    return self
end


function Orientation.sum(a, b)
    return Orientation:clone(a):add(b)
end


function Orientation.difference(a, b)
    return Orientation:clone(a):sub(b)
end


function Orientation:turnLeft()
    return self:add{orient=1}
end


function Orientation:turnRight()
    return self:sub{orient=1}
end


_OrientationMt.__add = Orientation.sum
_OrientationMt.__sub = Orientation.difference
_OrientationMt.__tostring = ig.tableToString
_OrientationMt.__eq = function(a, b) return a.orient==b.orient end


-- Turtle singleton. --
local IgTurtle = {
    -- Local coordinate data --
    _pos = Position:new(),
    _orient = Orientation:new(),
    _home = Position:new(),
    _fuelPos = ig.clone(Position, {x=1, y=0, z=0}),
    -- Global coordinate data --
    _globalPosDiff = Position:new(),
    _globalOrientDiff = Orientation:new(),
    -- Orientation constants --
    FORWARD = 0,
    LEFT = 1,
    BACKWARD = 2,
    RIGHT = 3,
    -- GPS orientation constants --
    EAST = 0,
    NORTH = 1,
    WEST = 2,
    SOUTH = 3
}


function IgTurtle:getPos()
    local pos = self._pos:copy()
    pos.orient = self._orient.orient
    return pos
end


function IgTurtle:getOrient()
    return self.orient:copy()
end


function IgTurtle:getRefuelPos()
    local pos = self._fuelPos:copy()
    pos.orient = self._orient.orient
    return pos
end


-- Determines if turtle has enough fuel to reach refuelling station. --
function IgTurtle:refuelInRange()
    return turtle.getFuelLevel() > self._pos:distanceTo(self._fuelPos)
end


function IgTurtle:forward()
    -- Check if a block is in the way.  If so, remove it. --
    if turtle.inspect() then
        turtle.dig()
    end
    -- Move into position and record movement. --
    local successfulMove = {turtle.forward()}
    if successfulMove[1] then
        self._pos:add(Orientation.FORWARD_POS_CHANGE[self._orient.orient])
    end
    return unpack(successfulMove)
end


function IgTurtle:back()
    -- Move into position and record movement. --
    local successfulMove = {turtle.back()}
    if successfulMove[1] then
        self._pos:add(Orientation.BACK_POS_CHANGE[self._orient.orient])
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
        self._pos:add({x=0,y=1,z=0})
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
        self._pos:add({x=0,y=-1,z=0})
    end
    return unpack(successfulMove)
end


function IgTurtle:turnRight()
    local successfulMove = {turtle.turnRight()}
    if successfulMove[1] then
        self._orient:turnRight()
    end
    return unpack(successfulMove)
end


function IgTurtle:turnLeft()
    local successfulMove = {turtle.turnLeft()}
    if successfulMove[1] then
        self._orient:turnLeft()
    end
    return unpack(successfulMove)
end


function IgTurtle:turnToFace(orient)
    if (orient - self._orient.orient) % 4 < 2 then
        while self._orient.orient ~= orient do
            self:turnLeft()
        end
    else
        while self._orient.orient ~= orient do
            self:turnRight()
        end
    end
end


function IgTurtle:goTo(x, y, z)
    if type(x) == "table" then
        assert(type(x.x) == "number" and type(x.y) == "number",
               "goTo() table argument requires numerical x and y members")
        z = x.z or self._pos.z
        y = x.y
        x = x.x
    end
    assert(type(x) == "number" and type(y) == "number",
           "goTo() requires both x and y coordinates as numbers")
    z = z or IgTurtle._pos.z
    local dest = {x=x, y=y, z=z}
    local pos = self._pos
    if turtle.getFuelLevel() < pos:distanceTo(dest) then
        return false, "not enough fuel"
    end

    local successfulMove
    -- vertical --
    if pos.y ~= dest.y then
        local yDirUp = pos.y > dest.y and 0 or 1
        while pos.y ~= dest.y do
            successfulMove = yDirUp == 1 and {self:up()} or {self:down()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
    -- z-direction --
    if pos.z ~= dest.z then
        if pos.z > dest.z then
            self:turnToFace(self.BACKWARD)
        else
            self:turnToFace(self.FORWARD)
        end
        while pos.z ~= dest.z do
            successfulMove = {self:forward()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
    -- x-direction --
    if pos.x ~= dest.x then
        if pos.x > dest.x then
            self:turnToFace(self.RIGHT)
        else
            self:turnToFace(self.LEFT)
        end
        while pos.x ~= dest.x do
            successfulMove = {self:forward()}
            if not successfulMove[1] then return unpack(successfulMove) end
        end
    end
end


function IgTurtle:goHome()
    self:goTo(self._home)
    self:turnToFace(FORWARD)
end


-- Sets the home position of the turtle to its current position. --
function IgTurtle:setHome()
    self._home = self._pos:copy()
    self._orient = Orientation:new()
end


-- Sets the location of the fuel source. --
-- Should be set after every call to setHome().                               --
function IgTurtle:setRefuel(pos)
    if type(pos) == "table" then
        assert(pos.x and pos.y and pos.z,
               "setRefuel() argument must be table with x, y, and z members")
    else pos = nil end
    if not (type(pos) == "table" and pos.x and pos.y and pos.z) then
        pos = self._pos
    end
    self._fuelPos = ig.clone(Position, pos):copy()
end


-- Refuel the turtle. --
-- Sends the turtle to the refuel station to get fuel and refuel itself.      --
-- Turtle returns to previous position after refueling.                       --
-- If the "enderfuel" option is provided, will place the ender chest in the   --
-- slot specified, pull fuel out of it, and pick it up again.                 --
function IgTurtle:refuel(options)
    options = options or {}
    local oldPos = self._pos:copy()
    if options.enderfuel then
        self:_refuelFromEnderChest(options.enderfuel)
    else
        local emptySlot = self:findEmptyItemSlot()
        self:goTo(self._fuelPos)
        assert(emptySlot, "no empty slot available for refueling")
        self:_refuelHere(emptySlot)
        self:goTo(oldPos)
    end
end


-- Refuel using the ender chest in the specified slot. --
function IgTurtle:_refuelFromEnderChest(chestSlot)
    turtle.select(chestSlot)
    turtle.placeDown()
    self:_refuelHere(chestSlot)
    turtle.digDown()
end


-- Refuel using the specified empty slot and fuel from an inventory below. --
function IgTurtle:_refuelHere(emptySlot)
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
if ig.isCC() then
    forward = ig.partial(IgTurtle.forward, IgTurtle)
    back = ig.partial(IgTurtle.back, IgTurtle)
    up = ig.partial(IgTurtle.up, IgTurtle)
    down = ig.partial(IgTurtle.down, IgTurtle)
    turnRight = ig.partial(IgTurtle.turnRight, IgTurtle)
    turnLeft = ig.partial(IgTurtle.turnLeft, IgTurtle)
    turnToFace = ig.partial(IgTurtle.turnToFace, IgTurtle)
    getPos = ig.partial(IgTurtle.getPos, IgTurtle)
    getRefuelPos = ig.partial(IgTurtle.getRefuelPos, IgTurtle)
    goTo = ig.partial(IgTurtle.goTo, IgTurtle)
    goHome = ig.partial(IgTurtle.goHome, IgTurtle)
    setHome = ig.partial(IgTurtle.setHome, IgTurtle)
    setRefuel = ig.partial(IgTurtle.setRefuel, IgTurtle)
    refuel = ig.partial(IgTurtle.refuel, IgTurtle)
    emptyInventoryDown = ig.partial(IgTurtle.emptyInventoryDown, IgTurtle)
    findItemSlot = ig.partial(IgTurtle.findItemSlot , IgTurtle)
    findEmptyItemSlot = ig.partial(IgTurtle.findEmptyItemSlot, IgTurtle)
    FORWARD = IgTurtle.FORWARD
    RIGHT = IgTurtle.RIGHT
    BACKWARD = IgTurtle.BACKWARD
    LEFT = IgTurtle.LEFT
else
    IgTurtle.Position = Position
    IgTurtle.Orientation = Orientation
    return IgTurtle
end
