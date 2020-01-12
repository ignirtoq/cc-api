local function _assertEqual(a, b)
    assert(a == b, string.format(
        "expected '%s', got '%s'", tostring(b), tostring(a)
    ))
end


local function _assertArraysEqual(a, b)
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


local function _assertPosEqual(p1, p2)
    assert(p1.x == p2.x, string.format("%d != %d", p1.x, p2.x))
    assert(p1.y == p2.y, string.format("%d != %d", p1.y, p2.y))
    assert(p1.z == p2.z, string.format("%d != %d", p1.z, p2.z))
end


local function _assertPosArrayEqual(a1, a2)
    local i
    assert(#a1 == #a2, string.format("%d != %d", #a1, #a2))
    for i, _ in ipairs(a1) do
        _assertPosEqual(a1[i], a2[i])
    end
end


local function _assertOrientEqual(o1, o2)
    assert(o1.orient == o2.orient, string.format(
        "%d != %d", o1.orient, o2.orient
    ))
end


local function _assertTablesEqual(a, b)
    local i, k
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


local function printf(s, ...)
    io.write(s:format(...))
end


local function runtest(name, func)
    printf(name .. ' ... ')

    local err, stacktrace
    local function catch(msg)
        err = msg
        stacktrace = debug.traceback()
    end
    local passed = xpcall(func, catch)

    printf(passed and 'PASSED\n' or 'FAILED\n')
    if not passed then
        print(err)
        print(stacktrace)
    end
end


return {
    assertEqual=_assertEqual,
    assertArraysEqual=_assertArraysEqual,
    assertPosEqual=_assertPosEqual,
    assertPosArrayEqual=_assertPosArrayEqual,
    assertOrientEqual=_assertOrientEqual,
    assertTablesEqual=_assertTablesEqual,
    printf=printf,
    runtest=runtest
}
