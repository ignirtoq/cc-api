-- Mock CC turtle module. --
turtle = {}


ig = require "src.ig"
iglogging = require "src.iglogging"
iggeo = require "src.iggeo"
igturtle = require "src.igturtle"
igfarm = require "src.igfarm"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"
local utils = require 'test.testutils'


local function test_createPathFromSides()
    local expsize
    local path
    local exppath
    local igturtGetPos = igturtle.getPos
    local igturtGetOrient = igturtle.getOrient

    local function setupMocks()
        local pos = iggeo.Position:new()
        local orient = iggeo.Orientation:new()
        igturtle.getPos = Mock()
        igturtle.getPos:whenCalled{with={}, thenReturn={pos}}
        igturtle.getOrient = Mock()
        igturtle.getOrient:whenCalled{with={}, thenReturn={orient}}
    end

    -- Default --
    setupMocks()
    expsize = 3*3
    exppath = {
        {x=0, y=0, z=1},
        {x=-1, y=0, z=1},
        {x=-2, y=0, z=1},
        {x=-2, y=0, z=2},
        {x=-1, y=0, z=2},
        {x=0, y=0, z=2},
        {x=0, y=0, z=3},
        {x=-1, y=0, z=3},
        {x=-2, y=0, z=3}
    }
    path = igfarm.createPathFromSides()
    assert(#path == expsize, string.format(
        "expected %d, got %d", expsize, #path
    ))
    utils.assertPosArrayEqual(exppath, path)

    -- Custom square side --
    setupMocks()
    expsize = 2*2
    exppath = {
        {x=0, y=0, z=1},
        {x=-1, y=0, z=1},
        {x=-1, y=0, z=2},
        {x=0, y=0, z=2}
    }
    path = igfarm.createPathFromSides(2)
    assert(#path == expsize, string.format(
        "expected %d, got %d", expsize, #path
    ))
    utils.assertPosArrayEqual(exppath, path)

    -- Negative square side --
    setupMocks()
    expsize = 3*3
    exppath = {
        {x=0, y=0, z=1},
        {x=1, y=0, z=1},
        {x=2, y=0, z=1},
        {x=2, y=0, z=2},
        {x=1, y=0, z=2},
        {x=0, y=0, z=2},
        {x=0, y=0, z=3},
        {x=1, y=0, z=3},
        {x=2, y=0, z=3}
    }
    path = igfarm.createPathFromSides(-3)
    assert(#path == expsize, string.format(
        "expected %d, got %d", expsize, #path
    ))
    utils.assertPosArrayEqual(exppath, path)

    -- Negative length, positive width --
    setupMocks()
    expsize = 3*3
    exppath = {
        {x=0, y=0, z=1},
        {x=1, y=0, z=1},
        {x=2, y=0, z=1},
        {x=2, y=0, z=2},
        {x=1, y=0, z=2},
        {x=0, y=0, z=2},
        {x=0, y=0, z=3},
        {x=1, y=0, z=3},
        {x=2, y=0, z=3}
    }
    path = igfarm.createPathFromSides(-3, 3)
    assert(#path == expsize, string.format(
        "expected %d, got %d", expsize, #path
    ))
    utils.assertPosArrayEqual(exppath, path)

    -- Negative length, negative width --
    setupMocks()
    expsize = 3*3
    exppath = {
        {x=0, y=0, z=1},
        {x=1, y=0, z=1},
        {x=2, y=0, z=1},
        {x=2, y=0, z=2},
        {x=1, y=0, z=2},
        {x=0, y=0, z=2},
        {x=0, y=0, z=3},
        {x=1, y=0, z=3},
        {x=2, y=0, z=3}
    }
    path = igfarm.createPathFromSides(-3, -3)
    assert(#path == expsize, string.format(
        "expected %d, got %d", expsize, #path
    ))
    utils.assertPosArrayEqual(exppath, path)

    igturtle.getPos = igturtGetPos
    igturtle.getOrient = igturtGetOrient
end


local function test_farmGeneric()
    local igturtFindItemSlot = igturtle.findItemSlot
    local igturtEmptyInventoryDown = igturtle.emptyInventoryDown
    local igturtRefuel = igturtle.refuel
    local oldFollowPath = igturtle.followPath
    local callback

    local function setupMocks()
        turtle.select = Mock()
        turtle.select:whenCalled{with={1}, thenReturn={}}
        turtle.getFuelLevel = Mock()
        turtle.refuel = Mock()
        turtle.suckDown = Mock()
        turtle.suckDown:whenCalled{with={}, thenReturn={true}}

        igturtle.findItemSlot = function() end
        igturtle.emptyInventoryDown = function() end
        igturtle.refuel = Mock()
        igturtle.refuel:whenCalled{with={}, thenReturn={}}
    end

    -- No callback throws error --
    assert(not pcall(igfarm.farmGeneric))

    -- Check fuel --
    setupMocks()
    turtle.getFuelLevel:whenCalled{with={}, thenReturn={0}}
    turtle.refuel:whenCalled{with={1}, thenReturn={true}}
    igturtle.followPath = function() return function() end end
    callback = function() end

    igfarm.farmGeneric{callback=callback}

    turtle.getFuelLevel:assertCallCount(1)
    turtle.refuel:assertCallCount(1)

    -- Loop once --
    setupMocks()
    turtle.getFuelLevel:whenCalled{with={}, thenReturn={1000}}
    turtle.refuel:whenCalled{with={1}, thenReturn={true}}
    igturtle.followPath = function()
        return function(_, i)
            if i > 0 then return end
            return i+1, _
        end, {}, 0
    end
    callback = function() end

    igfarm.farmGeneric{callback=callback}

    turtle.getFuelLevel:assertCallCount(2)
    turtle.refuel:assertCallCount(0)
    igturtle.refuel:assertCallCount(0)
    turtle.suckDown:assertCallCount(1)

    -- Loop once and refuel --
    setupMocks()
    turtle.getFuelLevel:whenCalled{with={}, thenReturn={1000}}
    turtle.getFuelLevel:whenCalled{with={}, thenReturn={0}}
    turtle.getFuelLevel:whenCalled{with={}, thenReturn={1000}}
    turtle.refuel:whenCalled{with={1}, thenReturn={true}}
    igturtle.followPath = function()
        return function(_, i)
            if i > 0 then return end
            return i+1, _
        end, {}, 0
    end
    callback = {
        args={},
        __call=function(self, ...) table.insert(self.args, {...}) end
    }
    setmetatable(callback, callback)

    igfarm.farmGeneric{callback=callback}

    assert(#callback.args == 1, string.format(
        "expected %d, got %d", 1, #callback.args
    ))
    turtle.getFuelLevel:assertCallCount(3)
    turtle.refuel:assertCallCount(0)
    igturtle.refuel:assertCallCount(1)
    turtle.suckDown:assertCallCount(1)

    -- Reset igturtle module --
    igturtle.findItemSlot = igturtFindItemSlot
    igturtle.emptyInventoryDown = igturtEmptyInventoryDown
    igturtle.refuel = igturtRefuel
end


test_createPathFromSides()
test_farmGeneric()
