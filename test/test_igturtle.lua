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


local function test_startPos()
    local pos = igturtle:getPos()

    assert(pos.x == 0, "expected pos.x=0")
    assert(pos.y == 0, "expected pos.y=0")
    assert(pos.z == 0, "expected pos.z=0")
    assert(pos.orient == 0, "expected pos.orient=1")
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


test_startPos()
test_forward()
test_back()
test_up()
test_down()
test_turnRight()
test_turnLeft()
