local ig = require "ig.ig"
local Mock = require "test.mock.Mock"
local Spy = require "test.mock.Spy"
local ValueMatcher = require "test.mock.ValueMatcher"
local utils = require "test.testutils"


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

local function values(arr)
    local ind = 0
    return function()
        ind = ind + 1
        if #arr >= ind then
            return arr[ind]
        end
    end
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


local function test_reverseArray()
    utils.assertArraysEqual(ig.reverseArray({}), {})
    utils.assertArraysEqual(ig.reverseArray({1}), {1})
    utils.assertArraysEqual(ig.reverseArray({1, 2}), {2, 1})
    utils.assertArraysEqual(ig.reverseArray({1, 2, 3}), {3, 2, 1})
end


local function test_arrayToSet()
    local tbl = {}
    utils.assertTablesEqual(
        ig.arrayToSet({'a', 1, true, tbl}),
        {['a']=true, [1]=true, [true]=true, [tbl]=true}
    )
end


local function test_numericalSetToArray()
    local tbl = {}
    utils.assertTablesEqual(
        ig.numericalSetToArray{[1]=true, [2]=true, [3]=true},
        {1, 2, 3}
    )
    utils.assertTablesEqual(
        ig.numericalSetToArray{[0]=true, [1]=true, [2]=true, [3]=true},
        {0, 1, 2, 3}
    )
    utils.assertTablesEqual(
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
    utils.assertTablesEqual(
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

    utils.assertArraysEqual(expected, actual)

    -- No array part case --
    expected = {}
    actual = ig.extendTable({}, noArr1, noArr2)

    utils.assertTablesEqual(expected, actual)

    -- General case, only copy array part --
    expected = {1, 2}
    actual = ig.extendTable({}, general)

    utils.assertArraysEqual(expected, actual)
    -- Also test as a table to ensure no map part is copied.
    utils.assertTablesEqual(expected, actual)

    -- One array, one map --
    expected = {unpack(arrOnly1)}
    actual = ig.extendTable({}, arrOnly1, noArr1)

    utils.assertTablesEqual(expected, actual)

    -- Not an array --
    expected = {}
    actual = ig.extendTable({}, 1)

    utils.assertTablesEqual(expected, actual)

end


local function test_partial()
    local expargs, expretval, func, retval, wrapped, wrapped2

    -- No args --
    expargs = {}
    expretval = 'abcd'
    func = Mock():whenCalled{with=expargs, thenReturn={expretval}}

    wrapped = ig.partial(func)
    retval = wrapped()

    assert(retval == expretval, string.format(
        "expected '%s', got '%s'", expretval, retval
    ))
    func:assertCallCount(1)
    func:assertCallMatches{with=expargs}

    -- Wrapped args --
    expargs = {'a', 1}
    expretval = 'abcd'
    func = Mock():whenCalled{with=expargs, thenReturn={expretval}}

    wrapped = ig.partial(func, 'a', 1)
    retval = wrapped()

    assert(retval == expretval, string.format(
        "expected '%s', got '%s'", expretval, retval
    ))
    func:assertCallCount(1)
    func:assertCallMatches{with={'a', 1}}

    -- Args to wrapped --
    expargs = {'a', 1}
    expretval = 'abcd'
    func = Mock():whenCalled{with=expargs, thenReturn={expretval}}

    wrapped = ig.partial(func)
    retval = wrapped(unpack(expargs))

    assert(retval == expretval, string.format(
        "expected '%s', got '%s'", expretval, retval
    ))
    func:assertCallCount(1)
    func:assertCallMatches{with=expargs}

    -- Args to wrapped with args --
    expargs = {'a', 1, 'b', 2}
    expretval = 'abcd'
    func = Mock():whenCalled{with=expargs, thenReturn={expretval}}

    wrapped = ig.partial(func, 'a', 1)
    retval = wrapped('b', 2)

    assert(retval == expretval, string.format(
        "expected '%s', got '%s'", expretval, retval
    ))
    func:assertCallCount(1)
    func:assertCallMatches{with=expargs}

    -- Double wrapped --
    expargs = {'first', 2, 'third', 4}
    expretval = 1234
    func = Mock():whenCalled{with=expargs, thenReturn={expretval}}

    wrapped = ig.partial(func, 'first', 2)
    wrapped2 = ig.partial(wrapped, 'third', 4)
    retval = wrapped2()

    assert(retval == expretval, string.format(
        "expected '%s', got '%s'", expretval, retval
    ))
    func:assertCallCount(1)
    func:assertCallMatches{with=expargs}

end


local function test_iter()
    local array, baseIt, it, itArray

    -- Unwrapped stateless case --
    array = {1, 'a', {}}
    it = {ig.iter(ipairs(array))}
    assert(#it == 1, 'expected single return value from iter()')

    it = it[1]
    itArray = {}
    for _, val in it do
        itArray[#itArray+1] = val
    end

    utils.assertArraysEqual(array, itArray)

    -- Wrapped stateless case --
    array = {'1', {}, 3}
    it = {ig.iter({ipairs(array)})}
    assert(#it == 1, 'expected single return value from iter()')

    it = it[1]
    itArray = {}
    for _, val in it do
        itArray[#itArray+1] = val
    end

    utils.assertArraysEqual(array, itArray)

    -- Unwrapped stateful case --
    array = {{}, 2, 'b'}
    baseIt = values(array)
    it = {ig.iter(baseIt)}
    assert(#it == 1, 'expected single return value from iter()')
    it = it[1]
    assert(it == baseIt, 'expected stateful iterator to match iter() output')

    -- Wrapped stateful case --
    array = {'a', {}, 3}
    baseIt = values(array)
    it = {ig.iter({baseIt})}
    assert(#it == 1, 'expected single return value from iter()')
    it = it[1]
    assert(it == baseIt, 'expected stateful iterator to match iter() output')
end


local function test_zip()
    local it1, it2, it3, it4, arr

    -- Empty case --
    for _ in ig.zip() do
        assert(false, 'no arguments to zip should not enter loop')
    end

    -- Symmetric two-iterator case --
    it1 = values{1, 3, 5}
    it2 = values{2, 4, 6}
    arr = {}
    for val1, val2 in ig.zip(it1, it2) do
        arr[#arr+1] = val1
        arr[#arr+1] = val2
    end
    utils.assertArraysEqual(arr, {1, 2, 3, 4, 5, 6})

    -- Asymmetric two-iterator case --
    it1 = values{1, 3, 5}
    it2 = values{2, 4}
    arr = {}
    for val1, val2 in ig.zip(it1, it2) do
        arr[#arr+1] = val1
        arr[#arr+1] = val2
    end
    utils.assertArraysEqual(arr, {1, 2, 3, 4})

    -- Multi-iterator case --
    it1 = values{'a', 5}
    it2 = values{'b', 6}
    it3 = values{3, 'c'}
    it4 = values{4, 'd'}
    arr = {}
    for v1, v2, v3, v4 in ig.zip(it1, it2, it3, it4) do
        arr[#arr+1] = v1
        arr[#arr+1] = v2
        arr[#arr+1] = v3
        arr[#arr+1] = v4
    end
    utils.assertArraysEqual(arr, {'a', 'b', 3, 4, 5, 6, 'c', 'd'})
end


local function test_enumerate()
    local it, enmArr, indArr, valArr
    local emptyTable = {}
    local testValues = {1, 'a', emptyTable}

    -- Empty case --
    assert(not pcall(ig.enumerate),
           'expected empty enumerate to throw exception')

    -- Basic case --
    it = values(testValues)
    enmArr, valArr = {}, {}
    for enm, val in ig.enumerate(it) do
        enmArr[#enmArr+1] = enm
        valArr[#valArr+1] = val
    end
    utils.assertArraysEqual(valArr, testValues)
    utils.assertArraysEqual(enmArr, {1, 2, 3})

    -- Custom-start case --
    it = values(testValues)
    enmArr, valArr = {}, {}
    for enm, val in ig.enumerate(it, 0) do
        enmArr[#enmArr+1] = enm
        valArr[#valArr+1] = val
    end
    utils.assertArraysEqual(valArr, testValues)
    utils.assertArraysEqual(enmArr, {0, 1, 2})

    -- Multi-value case --
    it = ig.iter(ipairs(testValues))
    enmArr, indArr, valArr = {}, {}, {}
    for enm, ind, val in ig.enumerate(it, 2) do
        enmArr[#enmArr+1] = enm
        indArr[#indArr+1] = ind
        valArr[#valArr+1] = val
    end
    utils.assertArraysEqual(enmArr, {2, 3, 4})
    utils.assertArraysEqual(indArr, {1, 2, 3})
    utils.assertArraysEqual(valArr, testValues)
end


local function test_basename()
    utils.assertEqual(ig.basename('/a/b/c'), 'c')
    utils.assertEqual(ig.basename('/a/b/'), '')
    utils.assertEqual(ig.basename('a/b/'), '')
    utils.assertEqual(ig.basename('a/b'), 'b')
    utils.assertEqual(ig.basename('a'), 'a')
    utils.assertEqual(ig.basename(''), '')
end


local function test_dirname()
    utils.assertEqual(ig.dirname('/a/b/c'), '/a/b/')
    utils.assertEqual(ig.dirname('/a/b/'), '/a/b/')
    utils.assertEqual(ig.dirname('a/b/'), 'a/b/')
    utils.assertEqual(ig.dirname('a/b'), 'a/')
    utils.assertEqual(ig.dirname('a'), nil)
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


local function test_super()
    local A = {}
    local B = ig.clone(A)
    local C = ig.clone(B)

    utils.assertEqual(ig.super(C), B)
    utils.assertEqual(ig.super(B), A)
    utils.assertEqual(ig.super(A), nil)
end


local function test_instanceOf()
    local child, grandchild, parent

    -- Direct inheritance --
    parent = {}
    child = ig.clone(parent)
    assert(ig.instanceOf(child, parent),
           'expected child to be instanceOf parent')
    assert(not ig.instanceOf(parent, child),
           'expected parent not to be instanceOf child')
    assert(not ig.instanceOf(child, nil),
           'expected child not to be instanceOf nil')
    assert(not ig.instanceOf(nil, parent),
           'expected nil not to be instanceOf parent')

    -- Further chaining --
    parent = {}
    child = ig.clone(parent)
    grandchild = ig.clone(child)
    assert(ig.instanceOf(child, parent),
           'expected child to be instanceOf parent')
    assert(ig.instanceOf(grandchild, parent),
           'expected grandchild to be instanceOf parent')
    assert(ig.instanceOf(grandchild, child),
           'expected grandchild to be instanceOf child')
    assert(not ig.instanceOf(parent, child),
           'expected parent not to be instanceOf child')
    assert(not ig.instanceOf(parent, grandchild),
           'expected parent not to be instanceOf grandchild')
    assert(not ig.instanceOf(child, grandchild),
           'expected child not to be instanceOf grandchild')
end


local function test_getmro()
    local A = {}
    local B = ig.clone(A)
    local C = ig.clone(B)

    utils.assertArraysEqual({A}, ig.getmro(A))
    utils.assertArraysEqual({B, A}, ig.getmro(B))
    utils.assertArraysEqual({C, B, A}, ig.getmro(C))
end


local function test_mergeLinearizations()
    utils.assertArraysEqual(ig.mergeLinearizations({1, 2, 3}), {1, 2, 3})
    utils.assertArraysEqual(
        ig.mergeLinearizations(
            {1, 2, 3},
            {1, 3, 4}
        ),
        {1, 2, 3, 4}
    )
    utils.assertArraysEqual(
        ig.mergeLinearizations(
            {1, 2, 3},
            {1, 3, 4},
            {1, 3, 5},
            {2, 4, 5}
        ),
        {1, 2, 3, 4, 5}
    )
    utils.assertArraysEqual(
        ig.mergeLinearizations(
            {1, 2, 3},
            {1, 3, 4},
            {1, 3, 5},
            {1, 3, 5},
            {2, 4, 5}
        ),
        {1, 2, 3, 4, 5}
    )

    assert(not pcall(ig.mergeLinearizations,
        {1, 2}, {2, 1}
    ))
end


local function test_inherit()
    local A, B, C, D, E, F

    -- Basic inheritance --
    A, B, C = {}, {}, {}
    D = ig.inherit(C, B, A)
    utils.assertEqual(D[1], nil)
    A[1] = 1
    B[2] = 2
    C[3] = 3
    utils.assertEqual(D[1], 1)
    utils.assertEqual(D[2], 2)
    utils.assertEqual(D[3], 3)

    -- Basic precedence --
    A, B, C = {1}, {2}, {3}
    D = ig.inherit(C, B, A)
    utils.assertEqual(D[1], 3)
    C[1] = nil
    utils.assertEqual(D[1], 2)
    B[1] = nil
    utils.assertEqual(D[1], 1)
    A[1] = nil
    utils.assertEqual(D[1], nil)

    -- Deeper inheritance linearization --
    A = {}
    B = ig.clone(A)
    C = ig.clone(B)
    D = ig.inherit(C, B)
    utils.assertArraysEqual(ig.getmro(D), {D, C, B, A})
    assert(not pcall(ig.inherit, B, C))

    A = {}
    B = ig.clone(A)
    C = ig.clone(A)
    D = ig.clone(B)
    E = ig.clone(C)
    F = ig.inherit(E, D)
    utils.assertArraysEqual(ig.getmro(F), {F, E, C, D, B, A})

    A = {}
    B = ig.clone(A)
    C = ig.clone(A)
    D = ig.inherit(C, B)
    E = ig.clone(C)
    F = ig.inherit(E, D)
    utils.assertArraysEqual(ig.getmro(F), {F, E, D, C, B, A})
end


local function test_ContextManager()
    local TestCtx

    -- Successful call --
    TestCtx = ig.clone(ig.ContextManager)
    TestCtx.enter = Mock():whenCalled{with={ValueMatcher.anyTable}}
    TestCtx.exit = Mock():whenCalled{with={ValueMatcher.anyTable}}

    TestCtx:clone():with(function() end)

    TestCtx.enter:assertCallCount(1)
    TestCtx.exit:assertCallCount(1)

    -- Call with enter args --
    TestCtx = ig.clone(ig.ContextManager)
    TestCtx.enter = Mock():whenCalled{with={ValueMatcher.anyTable, 'a'},
                                      thenReturn={'b'}}
    TestCtx.exit = Mock():whenCalled{with={ValueMatcher.anyTable}}

    TestCtx:clone():with('a', function(val) utils.assertEqual(val, 'b') end)

    TestCtx.enter:assertCallCount(1)
    TestCtx.exit:assertCallCount(1)

    -- Throw error --
    TestCtx = ig.clone(ig.ContextManager)
    TestCtx.enter = Mock():whenCalled{with={ValueMatcher.anyTable}}
    TestCtx.exit = Mock():whenCalled{with={ValueMatcher.anyTable,
                                           ValueMatcher.anyString}}

    TestCtx:clone():with(function() error('error') end)

    TestCtx.enter:assertCallCount(1)
    TestCtx.exit:assertCallCount(1)
end


local function test_isCC()
    utils.assertEqual(ig.isCC(), false)

    os.loadAPI = true
    utils.assertEqual(ig.isCC(), true)
    os.loadAPI = nil
end


local function test_Version()
    local smaller, larger

    -- Comparison operators --
    smaller = ig.Version:clone{major=1, minor=2, patch=3}
    larger = ig.Version:clone{major=1, minor=2, patch=3}

    assert(smaller <= larger, 'expected smaller < larger')
    assert(larger >= smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=0, minor=0, patch=0}
    larger = ig.Version:clone{major=0, minor=0, patch=1}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=0, minor=0, patch=0}
    larger = ig.Version:clone{major=0, minor=1, patch=0}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=0, minor=0, patch=0}
    larger = ig.Version:clone{major=1, minor=0, patch=0}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=0, minor=1, patch=2}
    larger = ig.Version:clone{major=0, minor=2, patch=1}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=1, minor=0, patch=2}
    larger = ig.Version:clone{major=2, minor=0, patch=1}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    smaller = ig.Version:clone{major=1, minor=2, patch=0}
    larger = ig.Version:clone{major=2, minor=1, patch=0}

    assert(smaller < larger, 'expected smaller < larger')
    assert(larger > smaller, 'expected larger > smaller')

    -- String conversion --
    utils.assertEqual(tostring(ig.Version:clone{major=1, minor=2, patch=3}),
                      '1.2.3')
end


local function test_require()
    local exppath, expurl, expmod, modname, module, oldFs, oldHttp, oldRequire
    oldFs = fs
    fs = {}
    oldHttp = http
    http = {}
    oldRequire = require

    local function setupMocks()
        fs.delete = Mock()
        fs.exists = Mock()
        fs.makeDir = Mock()
        fs.mockFile = Mock()
        fs.mockFile.close = Mock()
        fs.mockFile.write = Mock()
        fs.open = Mock()
        http.get = Mock()
        http.mockReq = Mock()
        http.mockReq.readAll = Mock()
        require = Mock()

        fs.makeDir:whenCalled{with={'/modules/ig/'}, thenReturn={true}}
        fs.mockFile.close:whenCalled{with={}, thenReturn={}}
    end

    -- No-op for modules that exist. --
    setupMocks()
    require:whenCalled{with={'ig.ig'}, thenReturn={ig}}
    module = ig.require('ig.ig')
    assert(module == ig)
    fs.makeDir:assertCallCount(0)
    fs.exists:assertCallCount(0)

    -- Download modules that don't exist. --
    setupMocks()
    modname = 'ig.igfake'
    expmod = {}
    exppath = '/modules/ig/igfake.lua'
    expurl = 'https://raw.githubusercontent.com/ignirtoq/cc-api/master/ig/igfake.lua'
    fs.delete:whenCalled{with={exppath}, thenReturn={}}
    fs.exists:whenCalled{with={exppath}, thenReturn={true}}
    fs.mockFile.write:whenCalled{with={123}, thenReturn={}}
    fs.open:whenCalled{with={exppath, 'w'},
                       thenReturn={fs.mockFile}}
    http.get:whenCalled{with={expurl}, thenReturn={http.mockReq}}
    http.mockReq.readAll:whenCalled{with={}, thenReturn={123}}
    require:whenCalled{with={modname},
                       sideEffect=function() error('mock require') end}
    require:whenCalled{with={modname}, thenReturn={expmod}}

    module = ig.require(modname)

    assert(module == expmod, 'did not get expected module')
    fs.delete:assertCallCount(1)
    fs.exists:assertCallCount(1)
    fs.makeDir:assertCallCount(1)
    fs.mockFile.close:assertCallCount(1)
    fs.mockFile.write:assertCallCount(1)
    fs.open:assertCallCount(1)
    http.get:assertCallCount(1)
    http.mockReq.readAll:assertCallCount(1)
    require:assertCallCount(2)


    fs = oldFs
    http = oldHttp
    require = oldRequire
end


local function test_loadAPI()
    ig.loadAPI()
end


utils.runtest('test_empty', test_empty)
utils.runtest('test_waitFor', test_waitFor)
utils.runtest('test_reverseArray', test_reverseArray)
utils.runtest('test_arrayToSet', test_arrayToSet)
utils.runtest('test_numericalSetToArray', test_numericalSetToArray)
utils.runtest('test_valuesToArray', test_valuesToArray)
utils.runtest('test_extendTable', test_extendTable)
utils.runtest('test_partial', test_partial)
utils.runtest('test_iter', test_iter)
utils.runtest('test_zip', test_zip)
utils.runtest('test_enumerate', test_enumerate)
utils.runtest('test_basename', test_basename)
utils.runtest('test_dirname', test_dirname)
utils.runtest('test_clone', test_clone)
utils.runtest('test_super', test_super)
utils.runtest('test_instanceOf', test_instanceOf)
utils.runtest('test_getmro', test_getmro)
utils.runtest('test_mergeLinearizations', test_mergeLinearizations)
utils.runtest('test_inherit', test_inherit)
utils.runtest('test_ContextManager', test_ContextManager)
utils.runtest('test_isCC', test_isCC)
utils.runtest('test_Version', test_Version)
utils.runtest('test_require', test_require)
utils.runtest('test_loadAPI', test_loadAPI)
