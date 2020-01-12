-- Dependencies. --
local ig = ig or require("ig.ig")
assert(ig, "iggeo API requires ig API")

-- Position abstraction. --
local _Position = {}
local _PositionMt = getmetatable(_Position) or {}
setmetatable(_Position, _PositionMt)


function _Position:new()
    return ig.clone(_Position, {x=0, y=0, z=0})
end

function _Position:clone(p)
    return ig.clone(_Position, {x=p.x, y=p.y, z=p.z})
end

function _Position:fromGps(g)
    return ig.clone(_Position, {x=g[1], y=g[2], z=g[3]})
end


function _Position:copy()
    return ig.clone(_Position, {x=self.x, y=self.y, z=self.z})
end


function _Position:distanceTo(other)
    return math.abs(self.x - other.x) + math.abs(self.y - other.y) +
           math.abs(self.z - other.z)
end


function _Position:add(other)
    self.x = self.x + other.x
    self.y = self.y + other.y
    self.z = self.z + other.z
    return self
end


function _Position:sub(other)
    self.x = self.x - other.x
    self.y = self.y - other.y
    self.z = self.z - other.z
    return self
end


function _Position.sum(a, b)
    return _Position:clone(a):add(b)
end


function _Position.difference(a, b)
    return _Position:clone(a):sub(b)
end


_PositionMt.__add = _Position.sum
_PositionMt.__sub = _Position.difference
_PositionMt.__tostring = ig.tableToString
_PositionMt.__eq = function(a, b) return a.x==b.x and a.y==b.y and a.z==b.z end


-- Orientation abstraction. --
local _Orientation = {
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
local _OrientationMt = getmetatable(_Orientation) or {}
setmetatable(_Orientation, _OrientationMt)


function _Orientation:new()
    return ig.clone(_Orientation, {orient=0})
end


function _Orientation:clone(o)
    return ig.clone(_Orientation, {orient=o.orient})
end


function _Orientation:copy()
    return ig.clone(_Orientation, {orient=self.orient})
end


function _Orientation:add(other)
    self.orient = (self.orient + other.orient) % 4
    return self
end


function _Orientation:sub(other)
    self.orient = (self.orient - other.orient) % 4
    return self
end


function _Orientation.sum(a, b)
    return _Orientation:clone(a):add(b)
end


function _Orientation.difference(a, b)
    return _Orientation:clone(a):sub(b)
end


function _Orientation:turnLeft()
    return self:add{orient=1}
end


function _Orientation:turnRight()
    return self:sub{orient=1}
end


function _Orientation:getForwardPos(pos, distance)
    pos = pos ~= nil and _Position:clone(pos) or _Position:new()
    distance = distance or 1
    assert(distance >= 0, "distance must be non-negative")
    for _ = 1, distance, 1 do
        pos:add(self.FORWARD_POS_CHANGE[self.orient])
    end
    return pos
end


function _Orientation:getLeftPos(pos, distance)
    return self:copy():turnLeft():getForwardPos(pos, distance)
end


function _Orientation:getRightPos(pos, distance)
    return self:copy():turnRight():getForwardPos(pos, distance)
end


function _Orientation:getBackPos(pos, distance)
    return self:copy():turnRight():turnRight():getForwardPos(pos, distance)
end


_OrientationMt.__add = _Orientation.sum
_OrientationMt.__sub = _Orientation.difference
_OrientationMt.__tostring = ig.tableToString
_OrientationMt.__eq = function(a, b) return a.orient==b.orient end


-- Path through space abstraction
local _Path = {}
local _PathMt = getmetatable(_Path) or {}
setmetatable(_Path, _PathMt)


function _Path:new()
    return ig.clone(_Path, {})
end


function _Path:clone(p)
    return ig.clone(_Path, ig.extendTable({}, p))
end


function _Path:append(p)
    table.insert(self, p)
    return self
end


function _Path:pop()
    assert(#self > 0, 'path is empty: no elements to pop')
    local p = self[#self]
    self[#self] = nil
    return p
end


function _Path:iter(args)
    args = args or {}
    local start = args.start or 1
    local loop = args.loop ~= nil and args.loop or false
    local index = start - 1
    return function()
        index = index + 1
        if loop and self[index] == nil then
            index = start
        end
        return self[index]
    end
end


-- Given a starting corner and an opposite corner, generates a zig-zag        --
-- space-filling path.  Not guaranteed to end at the opposite corner, but     --
-- will touch it.                                                             --
function _Path:generateSpaceFilling(start, opposite)
    assert(ig.instanceOf(start, _Position)
           and ig.instanceOf(opposite, _Position),
           'start and opposite must be Position objects')
    local diff = opposite - start
    -- Length of each side of the rectangular prism --
    local length = _Position:clone{
        x=math.abs(diff.x)+1,
        y=math.abs(diff.y)+1,
        z=math.abs(diff.z)+1
    }
    -- Overall sign of motion for each dimension --
    local d = _Position:clone{
        x = diff.x >= 0 and 1 or -1,
        y = diff.y >= 0 and 1 or -1,
        z = diff.z >= 0 and 1 or -1
    }
    local volume = length.x * length.y * length.z
    -- Variable to store sign calculations for faster-incrementing dimensions --
    local sign
    -- Variable to store relative motion for each iteration --
    local step
    -- Output array to be cloned into a Path --
    local path = {_Position:clone(start)}

    -- Iteration order (slow to fast): y, z, x --
    -- We iterate through the whole volume less the startig position, which we
    -- get for free.  With zero-based iteration (it mades the modulus formulas
    -- nicer) we subtract another from the volume, leaving volume-2.
    for t = 0, volume-2, 1 do
        if t % (length.x*length.z) == (length.x*length.z - 1) then
            -- Step in the slowest (y) direction --
            step = {x=0, y=d.y, z=0}
        elseif t % length.x == length.x - 1 then
            -- Step in middle (z) direction --
            sign = (-1)^math.floor(t/(length.x*length.z))
            step = {x=0, y=0, z=sign*d.z}
        else
            -- Step in fastest (x) direction --
            sign = (-1)^math.floor(t/length.x)
            step = {x=sign*d.x, y=0, z=0}
        end
        path[#path+1] = path[#path] + step
    end

    return _Path:clone(path)
end


_PathMt.__call = _Path.iter


----------------
-- Public API --
----------------
if ig.isCC() then
    Position = _Position
    Orientation = _Orientation
    Path = _Path
else
    return {
        Position=_Position,
        Orientation=_Orientation,
        Path=_Path
    }
end
