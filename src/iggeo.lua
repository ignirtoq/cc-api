-- Dependencies. --
assert(ig, "iggeo API requires ig API")

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


----------------
-- Public API --
----------------
if not ig.isCC() then
    return {Position=Position, Orientation=Orientation}
end
