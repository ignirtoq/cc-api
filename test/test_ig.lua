local ig = require "src.ig"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"


local function MockGlobal(name)
    local orig = _G[name]
    local m = Mock(orig)
    m._original = orig
    function m:clear()
        _G[name] = self._original
    end
    return m
end


local function SpyGlobal(name)
    local orig = _G[name]
    local s = Spy(orig)
    s._original = orig
    function s:clear()
        _G[name] = self._original
    end
    return s
end


local function assertArraysEqual(a, b)
    local i
    assert(#a == #b, string.format(
        "arrays different lengths: %d != %d", #a, #b
    ))

    for i = 1,#a,1 do
        assert(a[i] == b[i], string.format(
            "arrays have different values at %d: %s != %s",
            i, tostring(a[i]), tostring(b[i])
        ))
    end
end


local function assertTablesEqual(a, b)
    local i
    local akeys, bkeys = {}, {}
    for k, _ in pairs(a) do table.insert(akeys, k) end
    for k, _ in pairs(b) do table.insert(bkeys, k) end
    assert(#akeys == #bkeys, string.format(
        "tables have different sizes: %d != %d", #akeys, #bkeys
    ))
    for i = 1,#akeys,1 do
        assert(a[akeys[i]] == b[akeys[i]], string.format(
            "tables have different values for %s: %s != %s",
            tostring(akeys[i]), tostring(a[akeys[i]]),
            tostring(b[akeys[i]])
        ))
    end
end


local function _copyNoIndex(tbl)
    local new = {}
    for k, v in pairs(tbl) do repeat
        if k == '__index' then
            break  -- continue
        end
        new[k] = v
    until true end
    return new
end


local function test_empty()
    local emptyTable = {}
    local nonemptyTable = {1}
    next = SpyGlobal('next')

    next:assertCallCount(0)
    assert(ig.empty(emptyTable))
    next:assertCallCount(1)
    assert(not ig.empty(nonemptyTable))
    next:assertCallCount(2)

    next:clear()
end


local function test_waitFor()
    local _sleep = os.sleep

    -- Pass through. --
    local function done() return true end

    os.sleep = Mock(os.sleep)
    assert(ig.waitFor(done))
    os.sleep:assertCallCount(0)

    -- Fail once. --
    local x = 0
    local function failOnce()
        x = x+1
        if x == 2 then
            return true
        else
            return false
        end
    end

    os.sleep = Mock(os.sleep)
    os.sleep:whenCalled{with={ValueMatcher.anyNumber}, thenReturn={}}
    assert(ig.waitFor(failOnce))
    os.sleep:assertCallCount(1)

    -- Not a function. --
    assert(not pcall(ig.waitFor, nil))

    os.sleep = _sleep
end


local function test_arrayToSet()
    local tbl = {}
    assertTablesEqual(
        ig.arrayToSet({'a', 1, true, tbl}),
        {['a']=true, [1]=true, [true]=true, [tbl]=true}
    )
end


local function test_numericalSetToArray()
    local tbl = {}
    assertTablesEqual(
        ig.numericalSetToArray{[1]=true, [2]=true, [3]=true},
        {1, 2, 3}
    )
    assertTablesEqual(
        ig.numericalSetToArray{[0]=true, [1]=true, [2]=true, [3]=true},
        {0, 1, 2, 3}
    )
    assertTablesEqual(
        ig.numericalSetToArray{[3]=true},
        {3}
    )
end


local function test_valuesToArray()
    local tbl, str = {}, 'hello'
    local map = {a=1, [true]=false, [tbl]=str}
    local mapLen = 3

    local arr = ig.valuesToArray(map)
    -- Values can come in any order in the array, so the best we can do is
    -- verify the array length and turn the array to a set and check the
    -- values.
    assert(#arr == mapLen, string.format(
        "unexpected array length: %d != %d", #arr, mapLen
    ))
    assertTablesEqual(
        ig.arrayToSet(arr),
        {[1]=true, [false]=true, [str]=true}
    )
end


local function test_extendTable()
    local tbl = {}
    local function func() end
    local arrOnly1 = {1, 'hello', true}
    local arrOnly2 = {true, tbl, func}
    local noArr1 = {a=1, b=2}
    local noArr2 = {c=3, d=4, [0]='hi'}
    local general = {1, 2, buckle='myShoe'}
    local actual, expected

    -- Basic case --
    expected = {1, 'hello', true, true, tbl, func}
    actual = ig.extendTable({}, arrOnly1, arrOnly2)

    assertArraysEqual(expected, actual)

    -- No array part case --
    expected = {}
    actual = ig.extendTable({}, noArr1, noArr2)

    assertTablesEqual(expected, actual)

    -- General case, only copy array part --
    expected = {1, 2}
    actual = ig.extendTable({}, general)

    assertArraysEqual(expected, actual)
    -- Also test as a table to ensure no map part is copied.
    assertTablesEqual(expected, actual)

    -- One array, one map --
    expected = {unpack(arrOnly1)}
    actual = ig.extendTable({}, arrOnly1, noArr1)

    assertTablesEqual(expected, actual)

    -- Not an array --
    expected = {}
    actual = ig.extendTable({}, 1)

    assertTablesEqual(expected, actual)

end


local function test_clone()
    local existing, new

    -- Basic case --
    existing = {a=true}
    new = {}

    assert(new.a == nil, "expected new.a=nil")
    ig.clone(existing, new)
    assert(new.a == true, "expected new.a=true")
    assert(_copyNoIndex(new).a == nil, "expected copy(new).a=nil")

    assert(new.b == nil, "expected new.b=nil")
    existing.b = true
    assert(new.b == true, "expected new.b=true")
    assert(_copyNoIndex(new).b == nil, "expected copy(new).b=nil")
    new.b = 1
    assert(new.b == 1, "expected new.b=1")
    assert(existing.b == true, "expected existing.b=true")
    assert(_copyNoIndex(new).b == 1, "expected copy(new).b=1")
    new.b = nil
    assert(new.b == true, "expected new.b=true")

    -- Not a table --
    assert(not pcall(ig.clone, 1))
    assert(not pcall(ig.clone, {}, 1))
    assert(not pcall(ig.clone, 1, {}))
end


local function test_require()

    -- No-op for "modules" that exist. --
    _G['test'] = 1
    assert(pcall(ig.require, 'test'))
    _G['test'] = nil

end


test_empty()
test_waitFor()
test_arrayToSet()
test_numericalSetToArray()
test_valuesToArray()
test_extendTable()
test_clone()
test_require()
