ig = require "src.ig"
iggeo = require "src.iggeo"
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


local function test_globalOrientFromForwardMotion()
    local start = igturtle.Position:new()
    assert(
        igturtle:_globalOrientFromForwardMotion(start, {x=1, y=0, z=0})
            == igturtle.EAST,
        "expected orientation to be EAST"
    )
    assert(
        igturtle:_globalOrientFromForwardMotion(start, {x=0, y=0, z=-1})
            == igturtle.NORTH,
        "expected orientation to be NORTH"
    )
    assert(
        igturtle:_globalOrientFromForwardMotion(start, {x=-1, y=0, z=0})
            == igturtle.WEST,
        "expected orientation to be WEST"
    )
    assert(
        igturtle:_globalOrientFromForwardMotion(start, {x=0, y=0, z=1})
            == igturtle.SOUTH,
        "expected orientation to be SOUTH"
    )
end


local function test_setGps()
    local origin = igturtle.Position:new()
    local testGps = {1, 2, 3}
    local expected = igturtle.Position:clone({x=-1, y=-2, z=-3})
    igturtle._pos = origin:copy()

    assert(igturtle._globalPosDiff == origin,
           string.format(
               "expected %s, got %s", tostring(origin),
               tostring(igturtle._globalPosDiff)
           ))
    igturtle:setGps(testGps)
    assert(igturtle._globalPosDiff == expected,
           string.format(
               "expected %s, got %s", tostring(expected),
               tostring(igturtle._globalPosDiff)
           ))
end


local function test_verifyGps()
    local origin = igturtle.Position:new()
    igturtle._pos = origin:copy()
    igturtle._globalPosDiff = origin:copy()

    local got = igturtle:_verifyGps({0, 0, 0})
    assert(got, string.format("expected %s, got %s", tostring(true),
                              tostring(got)))
    got = igturtle:_verifyGps({1, 0, 0})
    assert(not got, string.format("expected %s, got %s", tostring(false),
                                  tostring(got)))
end


test_startPos()
test_forward()
test_back()
test_up()
test_down()
test_turnRight()
test_turnLeft()
test_turnToFace()
test_globalOrientFromForwardMotion()
test_setGps()
test_verifyGps()
