ig = require "src.ig"
iggeo = require "src.iggeo"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"
local utils = require "test.testutils"


local function test_posNew()
    local p1 = iggeo.Position:new()

    local fields = {x=true, y=true, z=true}
    for key, value in pairs(p1) do
        assert(fields[key], "unexpected field of pos: "..key)
        assert(value == 0, string.format(
            "unexpected field value of pos: %s", tostring(value)))
    end
end


local function test_posClone()
    local base = {x=1, y=2, z=3}
    local clone = iggeo.Position:clone(base)

    utils.assertPosEqual(base, clone)
end


local function test_posFromGps()
    local gps = {10, 20, 30}
    local pos = iggeo.Position:fromGps(gps)

    assert(gps[1] == pos.x, string.format("%d != %d", gps[1], pos.x))
    assert(gps[2] == pos.y, string.format("%d != %d", gps[2], pos.y))
    assert(gps[3] == pos.z, string.format("%d != %d", gps[3], pos.z))
end


local function test_posCopy()
    local base = iggeo.Position:new()
    base.x, base.y, base.z = 101, 202, 303
    local copy = base:copy()

    utils.assertPosEqual(base, copy)
end


local function test_posDistanceTo()
    local p1, p2, actDist, expDist

    -- straight line --
    p1 = iggeo.Position:clone{x=2, y=2, z=2}
    p2 = iggeo.Position:clone{x=-2, y=2, z=2}
    expDist = 4
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

    -- right angle --
    p1 = iggeo.Position:clone{x=2, y=2, z=2}
    p2 = iggeo.Position:clone{x=0, y=0, z=2}
    expDist = 4
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

    -- movement in 3D --
    p1 = iggeo.Position:clone{x=2, y=2, z=2}
    p2 = iggeo.Position:clone{x=0, y=0, z=0}
    expDist = 6
    actDist = p1:distanceTo(p2)

    assert(actDist == expDist, string.format("%d != %d", actDist, expDist))

end


local function test_posAdd()
    local p1 = iggeo.Position:clone{x=1, y=2, z=3}
    local p2 = iggeo.Position:clone{x=2, y=4, z=6}

    p1:add(p2)

    utils.assertPosEqual(p1, {x=3, y=6, z=9})
end


local function test_posSub()
    local p1 = iggeo.Position:clone{x=1, y=2, z=3}
    local p2 = iggeo.Position:clone{x=2, y=4, z=6}

    p1:sub(p2)

    utils.assertPosEqual(p1, {x=-1, y=-2, z=-3})
end


local function test_posSum()
    local p1 = iggeo.Position:clone{x=1, y=2, z=3}
    local p2 = iggeo.Position:clone{x=2, y=4, z=6}
    local sum = iggeo.Position.sum(p1, p2)

    utils.assertPosEqual(sum, {x=3, y=6, z=9})
end


local function test_posDifference()
    local p1 = iggeo.Position:clone{x=1, y=2, z=3}
    local p2 = iggeo.Position:clone{x=2, y=4, z=6}
    local diff = iggeo.Position.difference(p1, p2)

    utils.assertPosEqual(diff, {x=-1, y=-2, z=-3})
end


local function test_posEq()
    local p1 = iggeo.Position:clone{x=1, y=1, z=1}
    local p1a = iggeo.Position:clone{x=1, y=1, z=1}
    local p2 = iggeo.Position:clone{x=2, y=2, z=2}

    assert(p1 == p1a, 'expected p1 == p1a')
    assert(p1 ~= p2, 'expected p1 ~= p2')
end


local function test_orientNew()
    local o1 = iggeo.Orientation:new()

    local fields = {orient=true}
    for key, value in pairs(o1) do
        assert(fields[key], "unexpected field of orient: "..key)
        assert(value == 0, string.format(
            "unexpected field value of orient: %s", tostring(value)))
    end
end


local function test_orientClone()
    local base = {orient=1}
    local clone = iggeo.Orientation:clone(base)

    utils.assertOrientEqual(base, clone)
end


local function test_orientCopy()
    local base = iggeo.Orientation:new()
    base.orient = 4
    local copy = base:copy()

    utils.assertOrientEqual(base, copy)
end


local function test_orientAdd()
    local o = iggeo.Orientation:new()
    local o1 = iggeo.Orientation:clone{orient=1}
    local o2 = iggeo.Orientation:clone{orient=2}

    o:add(o1)
    utils.assertOrientEqual(o, o1)

    o:add(o1)
    utils.assertOrientEqual(o, o2)

    o:add(o2)
    utils.assertOrientEqual(o, iggeo.Orientation:new())
end


local function test_orientSub()
    local o = iggeo.Orientation:new()
    local o1 = iggeo.Orientation:clone{orient=1}

    o:sub(o1)
    utils.assertOrientEqual(o, {orient=3})
end


local function test_orientSum()
    local o1 = iggeo.Orientation:clone{orient=1}
    local o2 = iggeo.Orientation:clone{orient=2}

    utils.assertOrientEqual(o1 + o2, {orient=3})
end


local function test_orientDifference()
    local o1 = iggeo.Orientation:clone{orient=1}
    local o2 = iggeo.Orientation:clone{orient=2}

    utils.assertOrientEqual(o1 - o2, {orient=3})
end


local function test_orientTurnLeft()
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=0}):turnLeft(),
        {orient=1}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=1}):turnLeft(),
        {orient=2}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=2}):turnLeft(),
        {orient=3}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=3}):turnLeft(),
        {orient=0}
    )
end


local function test_orientTurnRight()
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=0}):turnRight(),
        {orient=3}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=1}):turnRight(),
        {orient=0}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=2}):turnRight(),
        {orient=1}
    )
    utils.assertOrientEqual(
        iggeo.Orientation:clone({orient=3}):turnRight(),
        {orient=2}
    )
end


local function test_orientGetForwardPos()
    local orient = iggeo.Orientation:new()

    -- Default --
    utils.assertPosEqual(
        orient:getForwardPos(),
        {x=0, y=0, z=1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 10),
        {x=0, y=0, z=10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Default with negative distance --
    assert(not pcall(orient.getForwardPos, orient, nil, -10),
           "expected error calling getForwardPos() with negative distance")
    -- Non-default position --
    utils.assertPosEqual(
        orient:getForwardPos({x=1, y=2, z=3}),
        {x=1, y=2, z=4}
    )

    -- After turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getForwardPos(),
        {x=-1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 10),
        {x=-10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getForwardPos({x=1, y=2, z=3}),
        {x=0, y=2, z=3}
    )

    -- After another turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getForwardPos(),
        {x=0, y=0, z=-1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 10),
        {x=0, y=0, z=-10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getForwardPos({x=1, y=2, z=3}),
        {x=1, y=2, z=2}
    )

    -- Last turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getForwardPos(),
        {x=1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 10),
        {x=10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getForwardPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getForwardPos({x=1, y=2, z=3}),
        {x=2, y=2, z=3}
    )
end


local function test_orientGetLeftPos()
    local orient = iggeo.Orientation:new()

    -- Default --
    utils.assertPosEqual(
        orient:getLeftPos(),
        {x=1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 10),
        {x=10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Default with negative distance --
    assert(not pcall(orient.getLeftPos, orient, nil, -10),
           "expected error calling getLeftPos() with negative distance")
    -- Non-default position --
    utils.assertPosEqual(
        orient:getLeftPos({x=1, y=2, z=3}),
        {x=2, y=2, z=3}
    )

    -- After turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getLeftPos(),
        {x=0, y=0, z=1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 10),
        {x=0, y=0, z=10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getLeftPos({x=1, y=2, z=3}),
        {x=1, y=2, z=4}
    )

    -- After another turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getLeftPos(),
        {x=-1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 10),
        {x=-10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getLeftPos({x=1, y=2, z=3}),
        {x=0, y=2, z=3}
    )

    -- Last turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getLeftPos(),
        {x=0, y=0, z=-1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 10),
        {x=0, y=0, z=-10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getLeftPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getLeftPos({x=1, y=2, z=3}),
        {x=1, y=2, z=2}
    )
end


local function test_orientGetRightPos()
    local orient = iggeo.Orientation:new()

    -- Default --
    utils.assertPosEqual(
        orient:getRightPos(),
        {x=-1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 10),
        {x=-10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Default with negative distance --
    assert(not pcall(orient.getRightPos, orient, nil, -10),
           "expected error calling getRightPos() with negative distance")
    -- Non-default position --
    utils.assertPosEqual(
        orient:getRightPos({x=1, y=2, z=3}),
        {x=0, y=2, z=3}
    )

    -- After turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getRightPos(),
        {x=0, y=0, z=-1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 10),
        {x=0, y=0, z=-10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getRightPos({x=1, y=2, z=3}),
        {x=1, y=2, z=2}
    )

    -- After another turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getRightPos(),
        {x=1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 10),
        {x=10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getRightPos({x=1, y=2, z=3}),
        {x=2, y=2, z=3}
    )

    -- Last turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getRightPos(),
        {x=0, y=0, z=1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 10),
        {x=0, y=0, z=10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getRightPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getRightPos({x=1, y=2, z=3}),
        {x=1, y=2, z=4}
    )
end


local function test_orientGetBackPos()
    local orient = iggeo.Orientation:new()

    -- Default --
    utils.assertPosEqual(
        orient:getBackPos(),
        {x=0, y=0, z=-1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 10),
        {x=0, y=0, z=-10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Default with negative distance --
    assert(not pcall(orient.getBackPos, orient, nil, -10),
           "expected error calling getBackPos() with negative distance")
    -- Non-default position --
    utils.assertPosEqual(
        orient:getBackPos({x=1, y=2, z=3}),
        {x=1, y=2, z=2}
    )

    -- After turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getBackPos(),
        {x=1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 10),
        {x=10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getBackPos({x=1, y=2, z=3}),
        {x=2, y=2, z=3}
    )

    -- After another turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getBackPos(),
        {x=0, y=0, z=1}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 10),
        {x=0, y=0, z=10}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getBackPos({x=1, y=2, z=3}),
        {x=1, y=2, z=4}
    )

    -- Last turn --
    orient:turnRight()

    -- Default --
    utils.assertPosEqual(
        orient:getBackPos(),
        {x=-1, y=0, z=0}
    )
    -- Default with added distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 10),
        {x=-10, y=0, z=0}
    )
    -- Default with zero distance --
    utils.assertPosEqual(
        orient:getBackPos(nil, 0),
        {x=0, y=0, z=0}
    )
    -- Non-default position --
    utils.assertPosEqual(
        orient:getBackPos({x=1, y=2, z=3}),
        {x=0, y=2, z=3}
    )
end


local function test_orientEq()
    assert(
        iggeo.Orientation:clone{orient=1} ==
        iggeo.Orientation:clone{orient=1},
        'expected orientation to be equal'
    )
end


local function test_Path_new()
    local newPath = iggeo.Path:new()

    assert(#newPath == 0, 'expected empy path')
end


local function test_Path_clone()
    local path
    local posArray = {
        iggeo.Position:clone{x=1, y=11, z=111},
        iggeo.Position:clone{x=2, y=22, z=222}
    }

    path = iggeo.Path:clone(posArray)
    assert(#path == #posArray, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for ind, val in ipairs(posArray) do
        assert(path[ind] == val, string.format(
            'expected %s, got %s', tostring(val), tostring(path[ind])
        ))
    end
end


local function test_Path_append()
    local expval, pos, path, retval

    pos = iggeo.Position:clone{x=1, y=11, z=111}
    path = iggeo.Path:new()
    expval = 0
    assert(#path == expval, string.format(
        'expected %d, got %d', expval, #path
    ))
    retval = path:append(pos)
    assert(retval == path, 'expected return value of path:append() to be path')
    expval = 1
    assert(#path == expval, string.format(
        'expected %d, got %d', expval, #path
    ))
    utils.assertPosEqual(path[1], pos)
end


local function test_Path_pop()
    local path = iggeo.Path:clone{
        iggeo.Position:clone{x=1, y=11, z=111},
        iggeo.Position:clone{x=2, y=22, z=222}
    }
    local exppos, expval, pos

    expval = 2
    assert(#path == expval, string.format(
        'expected %d, got %d', expval, #path
    ))

    exppos = path[#path]
    expval = 1
    pos = path:pop()
    assert(#path == expval, string.format(
        'expected %d, got %d', expval, #path
    ))
    utils.assertPosEqual(pos, exppos, string.format(
        'expected %s, got %s', tostring(exppos), tostring(pos)
    ))

    exppos = path[#path]
    expval = 0
    pos = path:pop()
    assert(#path == expval, string.format(
        'expected %d, got %d', expval, #path
    ))
    utils.assertPosEqual(pos, exppos, string.format(
        'expected %s, got %s', tostring(exppos), tostring(pos)
    ))

    assert(not pcall(path.pop, path), 'expected path:pop() to throw error')
end


local function test_Path_iter()
    local posArray = {
        iggeo.Position:clone{x=1, y=11, z=111},
        iggeo.Position:clone{x=2, y=22, z=222}
    }
    local path = iggeo.Path:clone(posArray)
    local testArray, maxCount

    -- Basic case --
    testArray = {}
    for pos in path() do
        testArray[#testArray+1] = pos
    end
    utils.assertArraysEqual(posArray, testArray)

    -- With start value --
    testArray = {}
    for pos in path{start=#posArray} do
        testArray[#testArray+1] = pos
    end
    utils.assertArraysEqual({posArray[#posArray]}, testArray)

    -- With loop --
    maxCount = 20
    for count, pos in ig.enumerate(path{loop=true}) do
        utils.assertPosEqual(pos, posArray[((count-1) % 2) + 1])
        if count > maxCount then break end
    end
end


local function test_Path_generateSpaceFilling()
    local function values(arr)
        local fun = ipairs(arr)
        local step = 0
        return function()
            local ind, val = fun(arr, step)
            step = ind
            return val
        end
    end
    local path, posArray, start, opposite

    -- One tile in x --
    start = iggeo.Position:clone{x=0, y=0, z=0}
    opposite = iggeo.Position:clone{x=1, y=0, z=0}
    posArray = {
        {x=0, y=0, z=0},
        {x=1, y=0, z=0}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end

    -- One tile in z --
    start = iggeo.Position:clone{x=0, y=0, z=0}
    opposite = iggeo.Position:clone{x=0, y=0, z=1}
    posArray = {
        {x=0, y=0, z=0},
        {x=0, y=0, z=1}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end

    -- One tile in y --
    start = iggeo.Position:clone{x=0, y=0, z=0}
    opposite = iggeo.Position:clone{x=0, y=1, z=0}
    posArray = {
        {x=0, y=0, z=0},
        {x=0, y=1, z=0}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end

    -- One tile each in x, z --
    start = iggeo.Position:clone{x=0, y=0, z=0}
    opposite = iggeo.Position:clone{x=1, y=0, z=1}
    posArray = {
        {x=0, y=0, z=0},
        {x=1, y=0, z=0},
        {x=1, y=0, z=1},
        {x=0, y=0, z=1}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end

    -- One tile each in x, z in reverse --
    start = iggeo.Position:clone{x=1, y=0, z=1}
    opposite = iggeo.Position:clone{x=0, y=0, z=0}
    posArray = {
        {x=1, y=0, z=1},
        {x=0, y=0, z=1},
        {x=0, y=0, z=0},
        {x=1, y=0, z=0}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end

    -- Simulated (tiny) quarry path --
    start = iggeo.Position:clone{x=0, y=0, z=0}
    opposite = iggeo.Position:clone{x=2, y=-1, z=2}
    posArray = {
        {x=0, y=0, z=0},
        {x=1, y=0, z=0},
        {x=2, y=0, z=0},
        {x=2, y=0, z=1},
        {x=1, y=0, z=1},
        {x=0, y=0, z=1},
        {x=0, y=0, z=2},
        {x=1, y=0, z=2},
        {x=2, y=0, z=2},
        {x=2, y=-1, z=2},
        {x=1, y=-1, z=2},
        {x=0, y=-1, z=2},
        {x=0, y=-1, z=1},
        {x=1, y=-1, z=1},
        {x=2, y=-1, z=1},
        {x=2, y=-1, z=0},
        {x=1, y=-1, z=0},
        {x=0, y=-1, z=0}
    }
    path = iggeo.Path:generateSpaceFilling(start, opposite)
    assert(#posArray == #path, string.format(
        'expected %d, got %d', #posArray, #path
    ))
    for exppos, pathpos in ig.zip(values(posArray), path()) do
        utils.assertPosEqual(exppos, pathpos)
    end
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
test_orientGetForwardPos()
test_orientGetLeftPos()
test_orientGetRightPos()
test_orientGetBackPos()
test_orientEq()
test_Path_new()
test_Path_clone()
test_Path_append()
test_Path_pop()
test_Path_iter()
test_Path_generateSpaceFilling()
