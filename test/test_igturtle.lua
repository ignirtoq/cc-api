ig = require "src.ig"
igturtle = require "src.igturtle"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"

-- Mock CC turtle module. --
turtle = {}


local function assertPosEqual(p1, p2)
    assert(p1.x == p2.x, string.format("%d != %d", p1.x, p2.x))
    assert(p1.y == p2.y, string.format("%d != %d", p1.y, p2.y))
    assert(p1.z == p2.z, string.format("%d != %d", p1.z, p2.z))
end


local function assertOrientEqual(o1, o2)
    assert(o1.orient == o2.orient, string.format(
        "%d != %d", o1.orient, o2.orient
    ))
end


local function test_posNew()
    local p1 = igturtle.Position:new()

    local fields = {x=true, y=true, z=true}
    for key, value in pairs(p1) do
        assert(fields[key], "unexpected field of pos: "..key)
        assert(value == 0, string.format(
            "unexpected field value of pos: %s", tostring(value)))
    end
end


local function test_posClone()
    local base = {x=1, y=2, z=3}
    local clone = igturtle.Position:clone(base)

    assertPosEqual(base, clone)
end


local function test_posFromGps()
    local gps = {10, 20, 30}
    local pos = igturtle.Position:fromGps(gps)

    assert(gps[1] == pos.x, string.format("%d != %d", gps[1], pos.x))
    assert(gps[2] == pos.y, string.format("%d != %d", gps[2], pos.y))
    assert(gps[3] == pos.z, string.format("%d != %d", gps[3], pos.z))
end


local function test_posCopy()
    local base = igturtle.Position:new()
    base.x, base.y, base.z = 101, 202, 303
    local copy = base:copy()

    assertPosEqual(base, copy)
end


local function test_posDistanceTo()
    local p1, p2, actDist, expDist

    -- straight line --
    p1 = igturtle.Position:clone{x=2, y=2, z=2}
    p2 = igturtle.Position:clone{x=-2, y=2, z=2}
    expDist = 4
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

    -- right angle --
    p1 = igturtle.Position:clone{x=2, y=2, z=2}
    p2 = igturtle.Position:clone{x=0, y=0, z=2}
    expDist = 4
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

    -- movement in 3D --
    p1 = igturtle.Position:clone{x=2, y=2, z=2}
    p2 = igturtle.Position:clone{x=0, y=0, z=0}
    expDist = 6
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

end


local function test_posAdd()
    local p1 = igturtle.Position:clone{x=1, y=2, z=3}
    local p2 = igturtle.Position:clone{x=2, y=4, z=6}

    p1:add(p2)

    assertPosEqual(p1, {x=3, y=6, z=9})
end


local function test_posSub()
    local p1 = igturtle.Position:clone{x=1, y=2, z=3}
    local p2 = igturtle.Position:clone{x=2, y=4, z=6}

    p1:sub(p2)

    assertPosEqual(p1, {x=-1, y=-2, z=-3})
end


local function test_posSum()
    local p1 = igturtle.Position:clone{x=1, y=2, z=3}
    local p2 = igturtle.Position:clone{x=2, y=4, z=6}
    local sum = igturtle.Position.sum(p1, p2)

    assertPosEqual(sum, {x=3, y=6, z=9})
end


local function test_posDifference()
    local p1 = igturtle.Position:clone{x=1, y=2, z=3}
    local p2 = igturtle.Position:clone{x=2, y=4, z=6}
    local diff = igturtle.Position.difference(p1, p2)

    assertPosEqual(diff, {x=-1, y=-2, z=-3})
end


local function test_posEq()
    local p1 = igturtle.Position:clone{x=1, y=1, z=1}
    local p1a = igturtle.Position:clone{x=1, y=1, z=1}
    local p2 = igturtle.Position:clone{x=2, y=2, z=2}

    assert(p1 == p1a, 'expected p1 == p1a')
    assert(p1 ~= p2, 'expected p1 ~= p2')
end


local function test_orientNew()
    local o1 = igturtle.Orientation:new()

    local fields = {orient=true}
    for key, value in pairs(o1) do
        assert(fields[key], "unexpected field of orient: "..key)
        assert(value == 0, string.format(
            "unexpected field value of orient: %s", tostring(value)))
    end
end


local function test_orientClone()
    local base = {orient=1}
    local clone = igturtle.Orientation:clone(base)

    assertOrientEqual(base, clone)
end


local function test_orientCopy()
    local base = igturtle.Orientation:new()
    base.orient = 4
    local copy = base:copy()

    assertOrientEqual(base, copy)
end


local function test_orientAdd()
    local o = igturtle.Orientation:new()
    local o1 = igturtle.Orientation:clone{orient=1}
    local o2 = igturtle.Orientation:clone{orient=2}

    o:add(o1)
    assertOrientEqual(o, o1)

    o:add(o1)
    assertOrientEqual(o, o2)

    o:add(o2)
    assertOrientEqual(o, igturtle.Orientation:new())
end


local function test_orientSub()
    local o = igturtle.Orientation:new()
    local o1 = igturtle.Orientation:clone{orient=1}

    o:sub(o1)
    assertOrientEqual(o, {orient=3})
end


local function test_orientSum()
    local o1 = igturtle.Orientation:clone{orient=1}
    local o2 = igturtle.Orientation:clone{orient=2}

    assertOrientEqual(o1 + o2, {orient=3})
end


local function test_orientDifference()
    local o1 = igturtle.Orientation:clone{orient=1}
    local o2 = igturtle.Orientation:clone{orient=2}

    assertOrientEqual(o1 - o2, {orient=3})
end


local function test_orientTurnLeft()
    assertOrientEqual(
        igturtle.Orientation:clone({orient=0}):turnLeft(),
        {orient=1}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=1}):turnLeft(),
        {orient=2}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=2}):turnLeft(),
        {orient=3}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=3}):turnLeft(),
        {orient=0}
    )
end


local function test_orientTurnRight()
    assertOrientEqual(
        igturtle.Orientation:clone({orient=0}):turnRight(),
        {orient=3}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=1}):turnRight(),
        {orient=0}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=2}):turnRight(),
        {orient=1}
    )
    assertOrientEqual(
        igturtle.Orientation:clone({orient=3}):turnRight(),
        {orient=2}
    )
end


local function test_orientEq()
    assert(
        igturtle.Orientation:clone{orient=1} ==
        igturtle.Orientation:clone{orient=1},
        'expected orientation to be equal'
    )
end


local function test_startPos()
    local pos = igturtle:getPos()

    assertPosEqual(pos, {x=0, y=0, z=0})
    assert(pos.orient == 0, "expected pos.orient=0")
end


local function _moveTemplate(dir, posChange, inspect, dig)
    local oldPos, pos, ret

    -- Reset position. --
    oldPos = igturtle:getPos()

    -- All checks false. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{when={}, thenReturn={false}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{when={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{when={}, thenReturn={false}}

    ret = igturtle[dir](igturtle)
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(0)
    turtle[dir]:assertCallCount(1)
    pos = igturtle:getPos()
    assertPosEqual(pos, oldPos)

    -- Inspect returns true, so dig should be called. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{when={}, thenReturn={true}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{when={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{when={}, thenReturn={false}}

    ret = igturtle[dir](igturtle)
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(1)
    turtle[dir]:assertCallCount(1)
    pos = igturtle:getPos()
    assertPosEqual(pos, oldPos)

    -- Successful move. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{when={}, thenReturn={false}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{when={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{when={}, thenReturn={true}}

    assert(igturtle[dir](igturtle) == true, string.format(
        "expected igturtle:%s() to return true", dir
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(0)
    turtle[dir]:assertCallCount(1)
    pos = igturtle:getPos()
    oldPos:add(posChange)
    assertPosEqual(pos, oldPos)
end


local function test_forward()
    _moveTemplate('forward', {x=0, y=0, z=1}, 'inspect', 'dig')
end

local function test_up()
    _moveTemplate('up', {x=0, y=1, z=0}, 'inspectUp', 'digUp')
end

local function test_down()
    _moveTemplate('down', {x=0, y=-1, z=0}, 'inspectDown', 'digDown')
end


local function test_back()
    local oldPos, pos, ret

    -- Reset position. --
    oldPos = igturtle:getPos()

    -- Failed move. --
    turtle.back = Mock()
    turtle.back:whenCalled{when={}, thenReturn={false}}
    pos = igturtle:getPos()
    oldy = pos.y

    ret = igturtle:back()
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))

    pos = igturtle:getPos()
    assert(pos.y == oldy, string.format(
        "expected %d, got %d", oldy, pos.y
    ))

    -- Successful move. --
    turtle.back = Mock()
    turtle.back:whenCalled{when={}, thenReturn={true}}
    pos = igturtle:getPos()
    oldy = pos.y

    ret = igturtle:back()
    assert(ret == true, string.format(
        "expected %s, got %s", tostring(true), tostring(ret)
    ))
    pos = igturtle:getPos()
    oldPos:add{x=0, y=0, z=-1}
    assertPosEqual(pos, oldPos)
end


local function test_turn(dir, newOrient)
    assertOrientEqual(igturtle:getPos(), {orient=0})

    -- Failed move. --
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{when={}, thenReturn={false}}
    assert(not igturtle[dir](igturtle))
    turtle[dir]:assertCallCount(1)
    assertOrientEqual(igturtle:getPos(), {orient=0})

    -- Successful move. --
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{when={}, thenReturn={true}}
    assert(igturtle[dir](igturtle))
    turtle[dir]:assertCallCount(1)
    assertOrientEqual(igturtle:getPos(), {orient=newOrient})

    -- Reset position. --
    igturtle:setHome()
end


local function test_turnRight()
    test_turn('turnRight', 3)
end


local function test_turnLeft()
    test_turn('turnLeft', 1)
end


local function turnToFace_template(start)
    local tl, tr = igturtle.turnLeft, igturtle.turnRight

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle:turnToFace(start)
    igturtle.turnLeft:assertCallCount(0)
    igturtle.turnRight:assertCallCount(0)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle:turnToFace((start + 1) % 4)
    igturtle.turnLeft:assertCallCount(1)
    igturtle.turnRight:assertCallCount(0)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle:turnToFace((start + 2) % 4)
    igturtle.turnLeft:assertCallCount(0)
    igturtle.turnRight:assertCallCount(2)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle:turnToFace((start + 3) % 4)
    igturtle.turnLeft:assertCallCount(0)
    igturtle.turnRight:assertCallCount(1)

    igturtle.turnLeft, igturtle.turnRight = tl, tr
end


local function test_turnToFace()
    turnToFace_template(0)
    turnToFace_template(1)
    turnToFace_template(2)
    turnToFace_template(3)
end


test_posNew()
test_posClone()
test_posFromGps()
test_posCopy()
test_posDistanceTo()
test_posAdd()
test_posSub()
test_posSum()
test_posDifference()
test_posEq()
test_orientNew()
test_orientClone()
test_orientCopy()
test_orientAdd()
test_orientSub()
test_orientSum()
test_orientDifference()
test_orientTurnLeft()
test_orientTurnRight()
test_orientEq()
test_startPos()
test_forward()
test_back()
test_up()
test_down()
test_turnRight()
test_turnLeft()
test_turnToFace()
