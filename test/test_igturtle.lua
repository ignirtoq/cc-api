ig = require "ig.ig"
iggeo = require "ig.iggeo"
igturtle = require "ig.igturtle"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"
local utils = require "test.testutils"


-- Mock CC turtle module. --
turtle = {}


local function test_startPos()
    local pos = igturtle.getPos()

    utils.assertPosEqual(pos, {x=0, y=0, z=0})
    assert(pos.orient == 0, "expected pos.orient=0")
end


local function _moveTemplate(dir, posChange, inspect, dig)
    local oldPos, pos, ret

    -- Reset position. --
    oldPos = igturtle.getPos()

    -- All checks false. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{with={}, thenReturn={false}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{with={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{with={}, thenReturn={false}}

    ret = igturtle[dir](igturtle)
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(0)
    turtle[dir]:assertCallCount(1)
    pos = igturtle.getPos()
    utils.assertPosEqual(pos, oldPos)

    -- Inspect returns true, so dig should be called. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{with={}, thenReturn={true}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{with={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{with={}, thenReturn={false}}

    ret = igturtle[dir](igturtle)
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(1)
    turtle[dir]:assertCallCount(1)
    pos = igturtle.getPos()
    utils.assertPosEqual(pos, oldPos)

    -- Successful move. --
    turtle[inspect] = Mock()
    turtle[inspect]:whenCalled{with={}, thenReturn={false}}
    turtle[dig] = Mock()
    turtle[dig]:whenCalled{with={}, thenReturn={}}
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{with={}, thenReturn={true}}

    assert(igturtle[dir](igturtle) == true, string.format(
        "expected igturtle.%s() to return true", dir
    ))
    turtle[inspect]:assertCallCount(1)
    turtle[dig]:assertCallCount(0)
    turtle[dir]:assertCallCount(1)
    pos = igturtle.getPos()
    oldPos:add(posChange)
    utils.assertPosEqual(pos, oldPos)
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
    oldPos = igturtle.getPos()

    -- Failed move. --
    turtle.back = Mock()
    turtle.back:whenCalled{with={}, thenReturn={false}}
    pos = igturtle.getPos()
    oldy = pos.y

    ret = igturtle.back()
    assert(ret == false, string.format(
        "expected %s, got %s", tostring(false), tostring(ret)
    ))

    pos = igturtle.getPos()
    assert(pos.y == oldy, string.format(
        "expected %d, got %d", oldy, pos.y
    ))

    -- Successful move. --
    turtle.back = Mock()
    turtle.back:whenCalled{with={}, thenReturn={true}}
    pos = igturtle.getPos()
    oldy = pos.y

    ret = igturtle.back()
    assert(ret == true, string.format(
        "expected %s, got %s", tostring(true), tostring(ret)
    ))
    pos = igturtle.getPos()
    oldPos:add{x=0, y=0, z=-1}
    utils.assertPosEqual(pos, oldPos)
end


local function test_turn(dir, newOrient)
    utils.assertOrientEqual(igturtle.getPos(), {orient=0})

    -- Failed move. --
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{with={}, thenReturn={false}}
    assert(not igturtle[dir](igturtle))
    turtle[dir]:assertCallCount(1)
    utils.assertOrientEqual(igturtle.getPos(), {orient=0})

    -- Successful move. --
    turtle[dir] = Mock()
    turtle[dir]:whenCalled{with={}, thenReturn={true}}
    assert(igturtle[dir](igturtle))
    turtle[dir]:assertCallCount(1)
    utils.assertOrientEqual(igturtle.getPos(), {orient=newOrient})

    -- Reset position. --
    igturtle.setHome()
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
    igturtle.turnToFace(start)
    igturtle.turnLeft:assertCallCount(0)
    igturtle.turnRight:assertCallCount(0)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle.turnToFace((start + 1) % 4)
    igturtle.turnLeft:assertCallCount(1)
    igturtle.turnRight:assertCallCount(0)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle.turnToFace((start + 2) % 4)
    igturtle.turnLeft:assertCallCount(0)
    igturtle.turnRight:assertCallCount(2)

    igturtle._orient.orient = start
    igturtle.turnLeft = Spy(igturtle.turnLeft)
    igturtle.turnRight = Spy(igturtle.turnRight)
    igturtle.turnToFace((start + 3) % 4)
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


local function test_goTo()
    local function setupMocksForGoTo()
        turtle.getFuelLevel = Mock()
        turtle.getFuelLevel:whenCalled{with={}, thenReturn={math.huge}}

        igturtle.forward = Mock()
        igturtle.back = Mock()
        igturtle.up = Mock()
        igturtle.down = Mock()
        igturtle.turnRight = Mock()
        igturtle.turnLeft = Mock()
        igturtle.turnToFace = Mock()

        igturtle._pos = iggeo.Position:clone{x=0, y=0, z=0}
        igturtle._orient.orient = 0
    end
    local function addToPos(movement)
        igturtle._pos = igturtle._pos + iggeo.Position:clone(movement)
    end

    local _forward = igturtle.forward
    local _back = igturtle.back
    local _up = igturtle.up
    local _down = igturtle.down
    local _right = igturtle.turnRight
    local _left = igturtle.turnLeft
    local _face = igturtle.turnToFace
    local upSideEffect = ig.partial(addToPos, {x=0, y=1, z=0})
    local retval, forwardSideEffect

    -- No movement --
    setupMocksForGoTo()
    igturtle.forward:whenCalled{with={}, thenReturn={false}}
    igturtle.back:whenCalled{with={}, thenReturn={false}}
    igturtle.up:whenCalled{with={}, thenReturn={false}}
    igturtle.down:whenCalled{with={}, thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.LEFT},
                                   thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.RIGHT},
                                   thenReturn={false}}

    retval = igturtle.goTo(0, 0, 0)
    assert(retval, string.format(
        "expected %s, got %s", tostring(true), tostring(retval)
    ))
    turtle.getFuelLevel:assertCallCount(1)
    igturtle.forward:assertCallCount(0)
    igturtle.back:assertCallCount(0)
    igturtle.up:assertCallCount(0)
    igturtle.down:assertCallCount(0)
    igturtle.turnToFace:assertCallCount(0)

    -- Failed movement --
    setupMocksForGoTo()
    igturtle.forward:whenCalled{with={}, thenReturn={false}}
    igturtle.back:whenCalled{with={}, thenReturn={false}}
    igturtle.up:whenCalled{with={}, thenReturn={false}}
    igturtle.down:whenCalled{with={}, thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.LEFT},
                                   thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.RIGHT},
                                   thenReturn={false}}

    retval = igturtle.goTo(0, 10, 0)
    assert(not retval, string.format(
        "expected %s, got %s", tostring(false), tostring(retval)
    ))
    turtle.getFuelLevel:assertCallCount(1)
    igturtle.forward:assertCallCount(0)
    igturtle.back:assertCallCount(0)
    igturtle.up:assertCallCount(1)
    igturtle.down:assertCallCount(0)
    igturtle.turnToFace:assertCallCount(0)

    -- Successful movement up --
    setupMocksForGoTo()
    igturtle.forward:whenCalled{with={}, thenReturn={false}}
    igturtle.back:whenCalled{with={}, thenReturn={false}}
    igturtle.up:whenCalled{with={}, thenReturn={true},
                           sideEffect=upSideEffect}
    igturtle.down:whenCalled{with={}, thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.LEFT},
                                   thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.RIGHT},
                                   thenReturn={false}}

    retval = igturtle.goTo(0, 10, 0)
    assert(retval, string.format(
        "expected %s, got %s", tostring(false), tostring(retval)
    ))
    turtle.getFuelLevel:assertCallCount(1)
    igturtle.forward:assertCallCount(0)
    igturtle.back:assertCallCount(0)
    igturtle.up:assertCallCount(10)
    igturtle.down:assertCallCount(0)
    igturtle.turnToFace:assertCallCount(0)

    -- Successful movement with turn --
    setupMocksForGoTo()
    forwardSideEffect = ig.partial(addToPos, {x=-1, y=0, z=0})
    igturtle.forward:whenCalled{with={}, thenReturn={true},
                                sideEffect=forwardSideEffect}
    igturtle.back:whenCalled{with={}, thenReturn={false}}
    igturtle.up:whenCalled{with={}, thenReturn={false}}
    igturtle.down:whenCalled{with={}, thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.LEFT},
                                   thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.RIGHT},
                                   thenReturn={false}}

    retval = igturtle.goTo(-1, 0, 0)
    assert(retval, string.format(
        "expected %s, got %s", tostring(true), tostring(retval)
    ))
    turtle.getFuelLevel:assertCallCount(1)
    igturtle.forward:assertCallCount(1)
    igturtle.back:assertCallCount(0)
    igturtle.up:assertCallCount(0)
    igturtle.down:assertCallCount(0)
    igturtle.turnToFace:assertCallMatches{arguments={igturtle.RIGHT}}

    -- Successful movement with turn --
    setupMocksForGoTo()
    forwardSideEffect = ig.partial(addToPos, {x=1, y=0, z=0})
    igturtle.forward:whenCalled{with={}, thenReturn={true},
                                sideEffect=forwardSideEffect}
    igturtle.back:whenCalled{with={}, thenReturn={false}}
    igturtle.up:whenCalled{with={}, thenReturn={false}}
    igturtle.down:whenCalled{with={}, thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.LEFT},
                                   thenReturn={false}}
    igturtle.turnToFace:whenCalled{with={igturtle.RIGHT},
                                   thenReturn={false}}

    retval = igturtle.goTo(1, 0, 0)
    assert(retval, string.format(
        "expected %s, got %s", tostring(true), tostring(retval)
    ))
    turtle.getFuelLevel:assertCallCount(1)
    igturtle.forward:assertCallCount(1)
    igturtle.back:assertCallCount(0)
    igturtle.up:assertCallCount(0)
    igturtle.down:assertCallCount(0)
    igturtle.turnToFace:assertCallMatches{arguments={igturtle.LEFT}}

    -- Reset methods --
    igturtle.forward = _forward
    igturtle.back = _back
    igturtle.up = _up
    igturtle.down = _down
    igturtle.turnRight = _right
    igturtle.turnLeft = _left
    igturtle.turnToFace = _face
end


local function test_getPos()
    local testPos = iggeo.Position:clone{x=3.14, y=159, z=265}
    local oldPos = igturtle._pos
    igturtle._pos = testPos
    utils.assertPosEqual(igturtle.getPos(), testPos)
    igturtle._pos = oldPos
end


local function test_getOrient()
    local testOrient = iggeo.Orientation:clone{orient=5}
    local oldOrient = igturtle._orient
    igturtle._orient = testOrient
    utils.assertOrientEqual(igturtle.getOrient(), testOrient)
    igturtle._orient = oldOrient
end


local function test_getHome()
    local testHome = iggeo.Position:clone{x=3.14, y=159, z=265}
    local oldHome = igturtle._home
    igturtle._home = testHome
    utils.assertPosEqual(igturtle.getHome(), testHome)
    igturtle._home = oldHome
end


local function test_globalOrientFromForwardMotion()
    local start = igturtle.Position:new()
    assert(
        igturtle._globalOrientFromForwardMotion(start, {x=1, y=0, z=0})
            == igturtle.EAST,
        "expected orientation to be EAST"
    )
    assert(
        igturtle._globalOrientFromForwardMotion(start, {x=0, y=0, z=-1})
            == igturtle.NORTH,
        "expected orientation to be NORTH"
    )
    assert(
        igturtle._globalOrientFromForwardMotion(start, {x=-1, y=0, z=0})
            == igturtle.WEST,
        "expected orientation to be WEST"
    )
    assert(
        igturtle._globalOrientFromForwardMotion(start, {x=0, y=0, z=1})
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
    igturtle.setGps(testGps)
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

    local got = igturtle._verifyGps({0, 0, 0})
    assert(got, string.format("expected %s, got %s", tostring(true),
                              tostring(got)))
    got = igturtle._verifyGps({1, 0, 0})
    assert(not got, string.format("expected %s, got %s", tostring(false),
                                  tostring(got)))
end


local function test_followPath()
    local function setupMockGoTo(path)
        igturtle.goTo = Mock()
        for pos in path() do
            igturtle.goTo:whenCalled{with={pos}, thenReturn={true}}
        end
    end

    local path, old_goTo, turtlePathIt
    old_goTo = igturtle.goTo
    path = iggeo.Path:clone{
        iggeo.Position:clone{x=0, y=0, z=0},
        iggeo.Position:clone{x=1, y=0, z=0},
        iggeo.Position:clone{x=1, y=1, z=0}
    }

    -- Path assertion --
    assert(not pcall(igturtle.followPath),
           'expected error when followPath() called with nil')
    assert(pcall(igturtle.followPath, path),
           'expected no error when followPath() called with path')

    -- Actual iteration --
    setupMockGoTo(path)
    for ind, pos in ig.enumerate(igturtle.followPath(path)) do
        igturtle.goTo:assertCallCount(1)
        igturtle.goTo:assertCallMatches({with=pos})
        utils.assertPosEqual(pos, path[ind])
        setupMockGoTo(path)
    end

    -- Reset mocked object(s) --
    igturtle.goTo = old_goTo
end


test_startPos()
test_forward()
test_back()
test_up()
test_down()
test_turnRight()
test_turnLeft()
test_turnToFace()
test_goTo()
test_getPos()
test_getOrient()
test_getHome()
test_globalOrientFromForwardMotion()
test_setGps()
test_verifyGps()
test_followPath()
